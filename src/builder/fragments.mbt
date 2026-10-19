///|
/// Read actual start-tag attributes. The existing HTML scanner excludes comments,
/// quoted attributes and raw/RCDATA text, including script's fake markup.
fn published_html_ids(html : String) -> Map[String, Bool] {
  let starts : Array[Int] = []
  for i = 0; i < html.length(); i = i + 1 {
    if @strutil.char_at(html, i) == '<' {
      starts.push(i)
    }
  }
  let (_, boundaries) = @strutil.strip_html_tags_with_boundaries(html, starts)
  let ids : Map[String, Bool] = Map([])
  for index = 0; index < starts.length(); index = index + 1 {
    if !boundaries[index] {
      continue
    }
    let mut pos = starts[index] + 1
    if pos >= html.length() {
      continue
    }
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
    let mut found_id : String? = None
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
      if name == "id" && found_id is None {
        // Surround with sentinels so text decoding cannot trim an ID into a
        // valid fragment. Resolved heading fragments contain no whitespace.
        let decoded = @strutil.strip_html_tags(
          "x" +
          value.replace(old="<", new="&lt;").replace(old=">", new="&gt;") +
          "x",
        )
        found_id = Some(decoded[1:decoded.length() - 1].to_owned())
      }
      if pos == start {
        pos = pos + 1
      }
    }
    if pos < html.length() &&
      @strutil.char_at(html, pos) == '>' &&
      found_id is Some(id) {
      ids.set(id, true)
    }
  }
  ids
}

///|
fn check_output_fragments(
  collections : Array[CollectionSources],
  page_index : Map[String, String],
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
          page_index.get(source.slug).unwrap_or("")
        } else {
          page.to_owned()
        }
        let path = output_path_key(config.output_dir + url + "index.html")
        let ids = match ids_by_path.get(path) {
          Some(ids) => ids
          None => {
            let html = match final_files.get(path) {
              Some(Text(html)) | Some(OptionalText(html)) => html
              Some(Binary(bytes)) => @utf8.decode_lossy(bytes)
              None => ""
            }
            let ids = published_html_ids(html)
            ids_by_path.set(path, ids)
            ids
          }
        }
        if !ids.contains(fragment.to_owned()) {
          let display = match link.raw.display {
            Some(display) => "|" + display
            None => ""
          }
          let marker = "[[" + link.raw.target + display + "]]"
          let (line, column) = line_col_of_first(source.content, marker)
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
