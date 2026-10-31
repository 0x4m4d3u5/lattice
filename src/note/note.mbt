///|
fn diagnostic(kind : String, source : String, message : String) -> Json {
  Json::object(
    Map([
      ("kind", Json::string(kind)),
      ("source", Json::string(source)),
      ("message", Json::string(message)),
    ]),
  )
}

///|
fn response(html : String, diagnostics : Array[Json]) -> String {
  Json::object(
    Map([
      ("html", Json::string(html)),
      ("diagnostics", Json::array(diagnostics)),
    ]),
  ).stringify()
}

///|
/// Experimental text boundary. No filesystem, templates, schema or global state.
/// Link-map keys are canonical slugs, matching the existing wikilink resolver.
/// Any diagnostic suppresses HTML; all Markdown/link issues are collected.
/// Trust note text and link-map URLs: raw HTML passes through and dangerous URL
/// schemes are not rejected. Hosts must sanitize untrusted output before DOM use;
/// WASM or worker isolation does not make returned HTML safe.
pub fn render_note(
  source : String,
  source_file : String,
  links_json : String,
) -> String {
  let diagnostics : Array[Json] = []
  let links = @json.parse(links_json[:]) catch {
    _ =>
      return response("", [
        diagnostic(
          "link_map", source_file, "expected a JSON object of slug-to-URL strings",
        ),
      ])
  }
  guard links is Object(fields) else {
    return response("", [
      diagnostic(
        "link_map", source_file, "expected a JSON object of slug-to-URL strings",
      ),
    ])
  }
  let index : Map[String, String] = Map([])
  for key, value in fields {
    match value {
      String(url) => index.set(key, url)
      _ =>
        return response("", [
          diagnostic(
            "link_map", source_file, "expected a JSON object of slug-to-URL strings",
          ),
        ])
    }
  }
  let fm = match @frontmatter.parse(source) {
    Ok(fm) => fm
    Err(message) =>
      return response("", [diagnostic("frontmatter", source_file, message)])
  }
  let (resolved, errors) = @wikilink.resolve(
    @wikilink.extract(fm.body, source_file),
    index,
  )
  for error in errors {
    diagnostics.push(diagnostic("wikilink", source_file, error.message))
  }
  let render_links : Map[String, String] = Map([])
  for link in resolved {
    render_links.set(link.raw.target, link.url)
  }
  for target in @markdown.extract_image_embeds(fm.body) {
    let key = @markdown.image_embed_key(target)
    match index.get(key) {
      Some(url) if url.has_prefix("/") && !url.has_prefix("//") && !url.contains("\\") && !url.iter().any(fn(c) { c.is_control() }) => render_links.set(key, url)
      _ => diagnostics.push(diagnostic("image_embed", source_file, "image embed " + key + " requires a local published asset destination"))
    }
  }
  let rendered = @markdown.render_with_diagnostics(fm.body, render_links)
  for issue in rendered.shortcode_errors {
    diagnostics.push(
      diagnostic("shortcode", source_file, @shortcode.error_text(issue.error)),
    )
  }
  response(if diagnostics.is_empty() { rendered.html } else { "" }, diagnostics)
}
