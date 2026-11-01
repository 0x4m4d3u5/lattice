///|
/// An absolute base URL may mount the publication under a path. No origin lookup
/// or network request is involved; explicit schemes and network URLs are skipped.
fn local_link_base_path(base : String) -> String {
  match base.split_once("://") {
    Some((_, rest)) =>
      match rest.split_once("/") {
        Some((_, path)) => "/" + path.trim_end(chars="/").to_owned()
        None => ""
      }
    None => ""
  }
}

///|
/// Normalize URL segments before mapping them into the output directory. Reject
/// encoded separators and backslashes rather than inventing server semantics.
fn local_link_path(path : String) -> Result[String, String] {
  let parts : Array[String] = []
  for raw in path.split("/") {
    let segment = @percent.decode(raw) catch {
      _ => return Err("malformed percent encoding")
    }
    if segment.contains("/") ||
      segment.contains("\\") ||
      segment.iter().any(c => c.is_ascii_control()) {
      return Err("encoded separators, backslashes and control characters are not supported")
    }
    match segment {
      "" | "." => ()
      ".." => {
        let _ = parts.pop()
      }
      _ => parts.push(segment)
    }
  }
  let normalized = "/" + parts.join("/")
  Ok(
    if path.has_suffix("/") && normalized != "/" {
      normalized + "/"
    } else {
      normalized
    },
  )
}

///|
fn local_link_destination(
  target : String,
  source_url : String,
  base : String,
) -> Result[(String, String?)?, String] {
  let target = target.trim().to_owned()
  if target.has_prefix("//") {
    return Ok(None)
  }
  let first = target
    .split("#")
    .next()
    .unwrap_or("")
    .to_owned()
    .split("?")
    .next()
    .unwrap_or("")
    .to_owned()
    .split("/")
    .next()
    .unwrap_or("")
    .to_owned()
  if first.split_once(":") is Some((scheme, _)) {
    if scheme.iter().next() is Some(initial) &&
      initial.is_ascii_alphabetic() &&
      scheme
      .iter()
      .all(c => {
        c.is_ascii_alphabetic() ||
        c.is_ascii_digit() ||
        c == '+' ||
        c == '-' ||
        c == '.'
      }) {
      return Ok(None)
    }
    return Err(
      "an ambiguous colon in the first URL segment must be percent-encoded",
    )
  }
  if target.iter().any(c => c.is_ascii_control()) {
    return Err("control characters in URLs are not supported")
  }
  if target.contains("\\") {
    return Err("backslash URL resolution is not supported")
  }
  let (before_fragment, fragment) = match target.split_once("#") {
    Some((page, fragment)) => {
      let decoded = @percent.decode(fragment) catch {
        _ => return Err("malformed fragment percent encoding")
      }
      (page.to_owned(), if decoded == "" { None } else { Some(decoded) })
    }
    None => (target, None)
  }
  let path = match before_fragment.split_once("?") {
    Some((path, _)) => path.to_owned()
    None => before_fragment
  }
  let mounted = base + source_url
  let absolute = if path == "" {
    mounted
  } else if path.has_prefix("/") {
    path
  } else {
    let parts = mounted.split("/").map(part => part.to_owned()).collect()
    let _ = parts.pop()
    parts.join("/") + "/" + path
  }
  let normalized = match local_link_path(absolute) {
    Ok(path) => path
    Err(error) => return Err(error)
  }
  let base = match local_link_path(base) {
    Ok(path) => path.trim_end(chars="/").to_owned()
    Err(error) => return Err(error)
  }
  if base != "" && normalized != base && !normalized.has_prefix(base + "/") {
    return Err("destination is outside the configured publication base path")
  }
  let relative = normalized[base.length():].to_owned()
  Ok(Some((if relative == "" { "/" } else { relative }, fragment)))
}

///|
fn check_output_local_links(
  collections : Array[CollectionSources],
  source_urls : Map[String, String],
  config : BuildConfig,
  output : OutputPlan,
  violations : Array[@lint.LintViolation],
) -> Unit {
  let files : Map[String, OutputContents] = Map([])
  let owners : Map[String, OutputOrigin] = Map([])
  for i = 0; i < output.files.length(); i = i + 1 {
    let (path, contents) = output.files[i]
    files.set(output_path_key(path), contents)
    owners.set(output_path_key(path), output.origins[i])
  }
  let base = local_link_base_path(config.site.base_url)
  for collection in collections {
    for source in collection.sources {
      if !source_is_visible(source, config.include_drafts) {
        continue
      }
      let source_url = match source_urls.get(source.path) {
        Some(url) => url
        None => continue
      }
      let source_path = output_path_key(
        config.output_dir + source_url + "index.html",
      )
      // Audit only authored pages that retain final ownership of their canonical route.
      let owned = match owners.get(source_path) {
        Some(Page(path)) => path == source.path
        _ => false
      }
      if !owned {
        continue
      }
      let body = match @frontmatter.parse(source.content) {
        Ok(fm) => fm.body
        Err(_) => continue
      }
      let mut has_base = false
      if files.get(source_path) is Some(Text(html)) {
        let _ = published_html_fragments(html, on_tag=fn(_, tag, _, _) {
          if tag == "base" {
            has_base = true
          }
        })
      }
      let seen : Map[String, Bool] = Map([])
      for target in @markdown.extract_link_destinations(body) {
        if seen.contains(target) {
          continue
        }
        seen.set(target, true)
        let error = match local_link_destination(target, source_url, base) {
          Err(error) => Some(error)
          Ok(None) => None
          Ok(Some((url, fragment))) =>
            if has_base {
              Some("HTML base elements are outside this local URL audit")
            } else {
              let exact = output_path_key(config.output_dir + url)
              let index = output_path_key(
                config.output_dir +
                url.trim_end(chars="/").to_owned() +
                "/index.html",
              )
              let path = if files.contains(exact) && !url.has_suffix("/") {
                exact
              } else {
                index
              }
              match files.get(path) {
                None =>
                  Some(
                    "destination '" + url + "' is not in the publication plan",
                  )
                Some(contents) =>
                  if fragment is Some(fragment) &&
                    (
                      path.to_lower().has_suffix(".html") ||
                      path.to_lower().has_suffix(".htm")
                    ) {
                    let html = match contents {
                      Text(html) | OptionalText(html) => html
                      Binary(bytes) => @utf8.decode_lossy(bytes)
                    }
                    if published_html_fragments(html).contains(fragment) {
                      None
                    } else {
                      Some(
                        "fragment '" +
                        fragment +
                        "' not found in published page '" +
                        url +
                        "'",
                      )
                    }
                  } else {
                    None
                  }
              }
            }
        }
        if error is Some(error) {
          // Do not invent a source location when the same spelling occurs in code,
          // metadata or several links. The file and exact destination remain actionable.
          let (line, column) = if target != "" &&
            source.content.split(target).count() == 2 {
            line_col_of_first(source.content, target)
          } else {
            (None, None)
          }
          violations.push({
            path: source.path,
            line,
            column,
            kind: @lint.BrokenLocalLink,
            message: "local link '" + target + "': " + error,
          })
        }
      }
    }
  }
}
