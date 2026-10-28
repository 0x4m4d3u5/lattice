///|
/// Read actual start-tag attributes. The existing HTML scanner excludes comments,
/// quoted attributes and raw/RCDATA text, including script's fake markup.
fn published_html_fragments(
  html : String,
  on_tag? : (Int, String, String?, String?) -> Unit = fn(_, _, _, _) { () },
) -> Map[String, Bool] {
  let starts : Array[Int] = []
  for i = 0; i < html.length(); i = i + 1 {
    if @strutil.char_at(html, i) == '<' {
      starts.push(i)
    }
  }
  let (_, boundaries) = @strutil.strip_html_tags_with_boundaries(html, starts)
  let ids : Map[String, Bool] = Map([("top", true)])
  let mut template_depth = 0
  for index = 0; index < starts.length(); index = index + 1 {
    if !boundaries[index] {
      continue
    }
    let mut pos = starts[index] + 1
    if pos >= html.length() {
      continue
    }
    let closing = @strutil.char_at(html, pos) == '/'
    if closing {
      pos = pos + 1
    }
    if pos >= html.length() {
      continue
    }
    let tag_start = pos
    let first = @strutil.char_at(html, pos)
    if !((first >= 'a' && first <= 'z') || (first >= 'A' && first <= 'Z')) {
      continue
    }
    while pos < html.length() &&
          !@strutil.char_at(html, pos).is_whitespace() &&
          @strutil.char_at(html, pos) != '>' &&
          @strutil.char_at(html, pos) != '/' {
      pos = pos + 1
    }
    let tag_name = html[tag_start:pos].to_owned().to_lower()
    if closing {
      if template_depth == 0 {
        on_tag(starts[index], "/" + tag_name, None, None)
      }
      if tag_name == "template" && template_depth > 0 {
        template_depth = template_depth - 1
      }
      continue
    }
    if template_depth > 0 {
      if tag_name == "template" {
        template_depth = template_depth + 1
      }
      continue
    }
    let mut found_id : String? = None
    let mut found_name : String? = None
    while pos < html.length() {
      while pos < html.length() &&
            (
              @strutil.char_at(html, pos).is_whitespace() ||
              @strutil.char_at(html, pos) == '/'
            ) {
        pos = pos + 1
      }
      if pos >= html.length() || @strutil.char_at(html, pos) == '>' {
        break
      }
      let start = pos
      while pos < html.length() &&
            !@strutil.char_at(html, pos).is_whitespace() &&
            @strutil.char_at(html, pos) != '=' &&
            @strutil.char_at(html, pos) != '>' &&
            @strutil.char_at(html, pos) != '/' {
        pos = pos + 1
      }
      let name = html[start:pos].to_owned().to_lower()
      while pos < html.length() && @strutil.char_at(html, pos).is_whitespace() {
        pos = pos + 1
      }
      let mut value = ""
      if pos < html.length() && @strutil.char_at(html, pos) == '=' {
        pos = pos + 1
        while pos < html.length() && @strutil.char_at(html, pos).is_whitespace() {
          pos = pos + 1
        }
        if pos >= html.length() {
          break
        }
        let quote = @strutil.char_at(html, pos)
        if quote == '\'' || quote == '"' {
          pos = pos + 1
          let start = pos
          while pos < html.length() && @strutil.char_at(html, pos) != quote {
            pos = pos + 1
          }
          if pos >= html.length() {
            break
          }
          value = html[start:pos].to_owned()
          pos = pos + 1
        } else {
          let start = pos
          while pos < html.length() &&
                !@strutil.char_at(html, pos).is_whitespace() &&
                @strutil.char_at(html, pos) != '>' {
            pos = pos + 1
          }
          value = html[start:pos].to_owned()
        }
      }
      if (name == "id" && found_id is None) ||
        (tag_name == "a" && name == "name" && found_name is None) {
        // Surround with sentinels so text decoding cannot trim an ID into a
        // valid fragment. Resolved heading fragments contain no whitespace.
        let decoded = @strutil.strip_html_tags(
          "x" +
          value.replace(old="<", new="&lt;").replace(old=">", new="&gt;") +
          "x",
        )
        let value = decoded[1:decoded.length() - 1].to_owned()
        if name == "id" {
          found_id = Some(value)
        } else {
          found_name = Some(value)
        }
      }
      if pos == start {
        pos = pos + 1
      }
    }
    if pos < html.length() && @strutil.char_at(html, pos) == '>' {
      on_tag(starts[index], tag_name, found_id, found_name)
      if found_id is Some(id) {
        ids.set(id, true)
      }
      if found_name is Some(name) {
        ids.set(name, true)
      }
      // The template element itself is in the document, but its descendants
      // belong to a separate inert DocumentFragment, including nested templates.
      if tag_name == "template" {
        template_depth = template_depth + 1
      }
    }
  }
  ids
}

///|
/// Validate visible authored wikilinks against one complete publication plan.
/// Resolution retains the existing lookup aliases; actual final files decide
/// whether a resolved destination (including a hidden draft) will be published.
fn check_output_wikilinks(
  collections : Array[CollectionSources],
  page_index : Map[String, String],
  source_urls : Map[String, String],
  config : BuildConfig,
  output : OutputPlan,
  violations : Array[@lint.LintViolation],
) -> Unit {
  let final_paths : Map[String, Bool] = Map([])
  for (path, _) in output.files {
    final_paths.set(path, true)
  }
  for collection in collections {
    for source in collection.sources {
      if !source_is_visible(source, config.include_drafts) {
        continue
      }
      let body = match @frontmatter.parse(source.content) {
        Ok(fm) => fm.body
        Err(_) => continue
      }
      let (links, errors) = @wikilink.resolve(
        @wikilink.extract(body, source.path), page_index,
      )
      for error in errors {
        let (line, column) = fragment_link_location(source.content, error.link)
        violations.push({
          path: source.path,
          line,
          column,
          kind: @lint.BrokenWikilink,
          message: "[[" + error.link.target + "]]: " + error.message,
        })
      }
      for link in links {
        // Fragment validation below also rejects absent final destination files.
        if link.url.contains("#") {
          continue
        }
        let path = output_path_key(config.output_dir + link.url + "index.html")
        if !final_paths.contains(path) {
          let (line, column) = fragment_link_location(source.content, link.raw)
          violations.push({
            path: source.path,
            line,
            column,
            kind: @lint.BrokenWikilink,
            message: "[[" + link.raw.target + "]]: destination '" +
            link.url + "' is not in the publication plan",
          })
        }
      }
    }
  }
  check_output_fragments(
    collections, page_index, source_urls, config, output, violations,
  )
}

///|
fn check_output_fragments(
  collections : Array[CollectionSources],
  page_index : Map[String, String],
  source_urls : Map[String, String],
  config : BuildConfig,
  output : OutputPlan,
  violations : Array[@lint.LintViolation],
) -> Unit {
  let final_files : Map[String, OutputContents] = Map([])
  for (path, contents) in output.files {
    final_files.set(path, contents)
  }
  let ids_by_path : Map[String, Map[String, Bool]] = Map([])
  for collection in collections {
    for source in collection.sources {
      if !source_is_visible(source, config.include_drafts) {
        continue
      }
      let body = match @frontmatter.parse(source.content) {
        Ok(fm) => fm.body
        Err(_) => continue
      }
      let (links, _) = @wikilink.resolve(
        @wikilink.extract(body, source.path),
        page_index,
      )
      for link in links {
        guard link.url.split_once("#") is Some((page, fragment)) else {
          continue
        }
        let url = if page.is_empty() {
          // Directory aliases can shadow a slug in page_index. A local href
          // still targets this source document, not that named lookup alias.
          source_urls.get(source.path).unwrap_or("")
        } else {
          page.to_owned()
        }
        let path = output_path_key(config.output_dir + url + "index.html")
        let ids = match ids_by_path.get(path) {
          Some(ids) => ids
          None => {
            let ids = match final_files.get(path) {
              Some(Text(html)) | Some(OptionalText(html)) =>
                published_html_fragments(html)
              Some(Binary(bytes)) =>
                published_html_fragments(@utf8.decode_lossy(bytes))
              None => Map([])
            }
            ids_by_path.set(path, ids)
            ids
          }
        }
        if !ids.contains(fragment.to_owned()) {
          let (line, column) = fragment_link_location(source.content, link.raw)
          violations.push({
            path: source.path,
            line,
            column,
            kind: @lint.BrokenWikilink,
            message: "[[" +
            link.raw.target +
            "]]: fragment '" +
            fragment.to_owned() +
            "' not found in published page '" +
            url +
            "'",
          })
        }
      }
    }
  }
}

///|
/// Resolve the authored spelling before locating it: the Markdown parser trims
/// targets and labels, so reconstructing [[target|display]] loses whitespace.
fn fragment_link_location(
  source : String,
  link : @wikilink.RawWikilink,
) -> (Int?, Int?) {
  let mut cursor = 0
  while cursor < source.length() {
    let start = @strutil.find_str(source, cursor, "[[", source.length())
    if start < 0 {
      break
    }
    let end = @strutil.find_str(source, start + 2, "]]", source.length())
    if end < 0 {
      break
    }
    let authored = source[start:end + 2].to_owned()
    let parsed = @wikilink.extract(authored, link.source_file)
    if parsed.length() == 1 &&
      parsed[0].target == link.target &&
      parsed[0].display == link.display {
      return line_col_of_first(source, authored)
    }
    cursor = end + 2
  }
  (None, None)
}

///|
/// Provenance comes from renderer offsets carried through verbatim template
/// slots, never from matching heading labels or a second slug implementation.
fn section_slot_offsets(
  offsets : Array[Int?],
  leading_h1_end : Int?,
) -> Map[@template.TemplateSlot, Array[(Int, Int)]] {
  let full : Array[(Int, Int)] = []
  let trimmed : Array[(Int, Int)] = []
  let cut = leading_h1_end.unwrap_or(0)
  for index = 0; index < offsets.length(); index = index + 1 {
    if offsets[index] is Some(offset) {
      full.push((index, offset))
      if offset >= cut {
        trimmed.push((index, offset - cut))
      }
    }
  }
  Map([
    (@template.Content, full),
    (@template.Body, full),
    (@template.BodyNoH1, trimmed),
  ])
}

///|
fn section_fragment_candidates(
  html : String,
  origins : Array[(Int, Int)],
) -> Map[Int, String] {
  let at : Map[Int, Int] = Map([])
  for (index, offset) in origins {
    at.set(offset, index)
  }
  let candidates : Map[Int, String] = Map([])
  let mut select_depth = 0
  let mut noscript_depth = 0
  let mut plaintext = false
  let _ = published_html_fragments(html, on_tag=fn(offset, tag, id, _) {
    // These HTML parsing contexts can suppress heading elements even though the
    // plaintext indexer's simpler scanner sees tags. Prefer a page citation.
    match tag {
      "select" => select_depth = select_depth + 1
      "/select" => select_depth = (select_depth - 1).max(0)
      "noscript" => noscript_depth = noscript_depth + 1
      "/noscript" => noscript_depth = (noscript_depth - 1).max(0)
      "plaintext" => plaintext = true
      _ => ()
    }
    if select_depth == 0 &&
      noscript_depth == 0 &&
      !plaintext &&
      at.get(offset) is Some(index) &&
      id is Some(id) &&
      ["h1", "h2", "h3", "h4", "h5", "h6"].contains(tag) &&
      id != "" {
      candidates.set(index, id)
    }
  })
  unique_section_fragments(html, candidates)
}

///|
fn unique_section_fragments(
  html : String,
  candidates : Map[Int, String],
) -> Map[Int, String] {
  let counts : Map[String, Int] = Map([])
  let mut uncertain_entity = false
  let _ = published_html_fragments(html, on_tag=fn(_, _, id, name) {
    if id is Some(id) {
      if id.contains("&") {
        uncertain_entity = true
      }
      counts.set(id, counts.get(id).unwrap_or(0) + 1)
    }
    if name is Some(name) && Some(name) != id {
      if name.contains("&") {
        uncertain_entity = true
      }
      counts.set(name, counts.get(name).unwrap_or(0) + 1)
    }
  })
  let result : Map[Int, String] = Map([])
  // The shared scanner decodes basic/numeric entities, not every HTML named
  // reference or missing-semicolon recovery. Uncertain IDs cannot prove uniqueness.
  if uncertain_entity {
    return result
  }
  for (index, id) in candidates {
    if counts.get(id) == Some(1) {
      result.set(index, id)
    }
  }
  result
}
