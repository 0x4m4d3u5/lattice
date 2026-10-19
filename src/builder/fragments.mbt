///|
/// Read actual start-tag attributes. The existing HTML scanner excludes comments,
/// quoted attributes and raw/RCDATA text, including script's fake markup.
fn published_html_fragments(html : String) -> Map[String, Bool] {
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
          // Directory aliases can shadow a slug in page_index. A local href
          // still targets this source document, not that named lookup alias.
          match collection.definition.name {
            "_standalone" => standalone_page_url(source.slug)
            "_root" => root_page_url(source.slug)
            name => collection_page_url(name, source.slug)
          }
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
