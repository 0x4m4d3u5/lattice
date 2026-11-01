///|
/// A context is selected only from a renderer-origin block retained verbatim in
/// the final source page. No source Markdown or template-only text is quoted.
fn backlink_context(
  doc : ProcessedDocument,
  target_url : String,
  page_index : Map[String, String],
) -> (String, String?)? {
  for (target, start, end) in doc.wikilink_blocks {
    if page_index.get(@wikilink.lookup_key(target)) != Some(target_url) { continue }
    let block = doc.content_html[start:end].to_owned()
    let occurrences = doc.html.split(block).collect()
    if block == "" || occurrences.length() != 2 { continue }
    let offset = occurrences[0].length()
    let mut active = false
    let mut suppressed = 0
    let _ = published_html_fragments(doc.html, on_tag=fn(at, tag, _, _) {
      match tag {
        "select" | "noscript" | "plaintext" => suppressed = suppressed + 1
        "/select" | "/noscript" => suppressed = (suppressed - 1).max(0)
        _ => ()
      }
      if at == offset && suppressed == 0 { active = true }
    })
    if !active { continue }
    // These raw-text contexts are not suitable reader excerpts.
    let lower = block.to_lower()
    if ["<script", "<style", "<template", "<textarea", "<noscript"].any(tag => lower.contains(tag)) { continue }
    let text = @strutil.strip_html_tags(block).trim().to_owned()
    if text == "" { continue }
    let mut section : Int? = None
    for i = 0; i < doc.section_offsets.length(); i = i + 1 {
      if doc.section_offsets[i] is Some(at) && at <= start { section = Some(i) }
    }
    let fragment = match section {
      Some(i) => doc.section_fragments.get(i)
      None => None
    }
    let excerpt = truncate_to_builder(text, 180)
    return Some((if text.iter().count() > 180 { excerpt + "…" } else { excerpt }, fragment))
  }
  None
}

///|
fn contextual_backlink_items(
  refs : Array[BacklinkRef],
  target_url : String,
  documents : Map[String, ProcessedDocument],
  page_index : Map[String, String],
  overwritten : Map[String, Bool],
) -> (String, Int) {
  let refs = refs.copy()
  refs.sort_by_key(entry => entry.url)
  let items = StringBuilder()
  let mut count = 0
  for entry in refs {
    if overwritten.contains(entry.url) || !documents.contains(entry.url) { continue }
    count = count + 1
    let context = backlink_context(documents.get(entry.url).unwrap(), target_url, page_index)
    let href = match context {
      Some((_, Some(fragment))) => entry.url + "#" + @percent.encode(fragment)
      _ => entry.url
    }
    items.write_string("<li>" + @html.anchor(href, entry.title))
    if context is Some((text, _)) {
      items.write_string("<p class=\"backlink-context\">" + @html.escape_html_body(text) + "</p>")
    }
    items.write_string("</li>\n")
  }
  (items.to_string(), count)
}

///|
/// Replace only the exact generated list in an active backlink section.
fn contextual_backlink_html(html : String, refs : Array[BacklinkRef], items : String, count : Int) -> String {
  let original = render_backlinks_html(refs)
  let old_body = match original.split_once(">") { Some((_, body)) => body.to_owned(); None => return html }
  let replacements : Array[(String, String)] = []
  let _ = published_html_fragments(html, on_tag=fn(start, tag, id, _) {
    if tag != "section" || !html[start:].has_prefix("<section class=\"backlinks\"") { return }
    let rest = html[start:].to_owned()
    if rest.split_once(">") is Some((opening, body)) && body.has_prefix(old_body) {
      let old = opening.to_owned() + ">" + old_body
      let new = if count == 0 { "" } else { opening.to_owned() + ">\n<h2>Backlinks</h2>\n<ul>\n" + items + "</ul>\n</section>\n" }
      replacements.push((old, new))
      if id is Some(id) {
        let old_link = "<a href=\"#" + id + "\">Backlinks (" + refs.length().to_string() + ")</a>"
        let new_link = if count == 0 { "" } else { "<a href=\"#" + id + "\">Backlinks (" + count.to_string() + ")</a>" }
        replacements.push((old_link, new_link))
      }
    }
  })
  let mut result = html
  for (old, new) in replacements { result = result.replace_all(old~, new~) }
  result.replace_all(old="<div class=\"reader-metadata\"></div>", new="")
}

///|
/// Final ownership is known here. Cache decisions for backlink-bearing collection
/// pages use the completed HTML, so referring edits and ownership changes cannot
/// leave stale excerpts while unchanged publications still avoid page writes.
fn finalize_contextual_backlinks(
  output : OutputPlan,
  documents : Map[String, ProcessedDocument],
  sources : Map[String, (String, String, String)],
  index : Map[String, Array[BacklinkRef]],
  page_index : Map[String, String],
  overwritten : Map[String, Bool],
  marks : Map[String, (String, Int)],
  dropped : Map[Int, Bool],
  cache : @cache.CacheStore,
  next_cache : @cache.CacheStore,
  messages : Array[String],
  force : Bool,
) -> Int {
  let mut skipped = 0
  for i = 0; i < output.files.length(); i = i + 1 {
    if dropped.contains(i) { continue }
    if output.origins[i] is Page(source) && sources.get(source) is Some((slug, url, context)) &&
      !overwritten.contains(url) && index.get(slug) is Some(refs) && output.files[i].1 is Text(html) {
      let (items, count) = contextual_backlink_items(refs, url, documents, page_index, overwritten)
      let final_html = contextual_backlink_html(html, refs, items, count)
      let path = output.files[i].0
      output.files[i] = (path, Text(final_html))
      // Only collection pages participate in this cache. Root/standalone pages
      // have no remembered entry, and root aliases must remain separate writes.
      if marks.get(url) is Some((canonical_path, _)) && path == canonical_path && @cache.lookup(next_cache, slug) is Some(_) {
        let fingerprint = @cache.fingerprint_for_source("contextual-backlinks-v1", final_html)
        if @cache.should_skip(cache, slug, fingerprint, path, force) {
          dropped.set(i, true)
          skipped = skipped + 1
          for j = 0; j < messages.length(); j = j + 1 {
            if messages[j] == "[build] " + context { messages[j] = "[skip] " + context }
          }
        }
        @cache.remember(next_cache, slug, fingerprint)
      }
    }
  }
  skipped
}
