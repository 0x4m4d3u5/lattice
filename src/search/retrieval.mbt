///|
/// A page with rendered section text. URLs are the publisher's canonical URLs.
pub(all) struct SearchDocument {
  title : String
  url : String
  tags : Array[String]
  sections : Array[@markdown.TextSection]
}

///|
pub(all) struct SectionHit {
  title : String
  url : String
  tags : Array[String]
  section : String
  section_index : Int32
  snippet : String
  score : Int32
}

///|
// ASCII punctuation/whitespace delimit terms; non-ASCII text stays intact.
// ASCII case folding deliberately has identical behavior on JS and WASM.
fn scan_terms(text : String, record : (String, Int32) -> Unit) -> Unit {
  let mut word = StringBuilder()
  let mut position = 0
  let mut start = 0
  let mut in_word = false
  for c in text.iter() {
    if c.is_ascii_punctuation() || c.is_whitespace() || c.is_control() {
      if in_word {
        record(word.to_string(), start)
      }
      word = StringBuilder()
      in_word = false
    } else {
      if !in_word {
        start = position
        in_word = true
      }
      word.write_char(c.to_ascii_lowercase())
    }
    position = position + 1
  }
  if in_word {
    record(word.to_string(), start)
  }
}

///|
fn frequencies(text : String) -> Map[String, Int32] {
  let counts : Map[String, Int32] = Map([])
  scan_terms(text, fn(term, _) {
    // Saturating frequency prevents repeated keywords dominating headings.
    counts.set(term, (counts.get(term).unwrap_or(0) + 1).min(3))
  })
  counts
}

///|
fn section_snippet(body : String, query : Array[String]) -> String {
  let mut first : Int32? = None
  scan_terms(body, fn(term, position) {
    if first is None && query.contains(term) {
      first = Some(position)
    }
  })
  let start = match first {
    Some(position) => (position - 60).max(0)
    None => 0
  }
  let chars = body.iter().to_array()
  let buf = StringBuilder()
  if start > 0 {
    buf.write_string("…")
  }
  for c in chars.iter().drop(start).take(240) {
    buf.write_char(c)
  }
  if start + 240 < chars.length() {
    buf.write_string("…")
  }
  buf.to_string()
}

///|
/// Deterministic AND lexical retrieval; required tags are exact, ASCII case
/// insensitive AND filters. Empty queries/limits return no hits; limit caps at 50.
/// Scores favor heading (12), title (6), body (1 + frequency capped at 3).
/// Optional alternate names add 3 only for terms missing from these fields.
/// Name-only fallback returns the first section once, unless ordinary text matches.
/// Equal scores sort by canonical URL then section order. Snippets are plaintext,
/// at most 240 Unicode scalars plus ellipses, centered near a body query term.
pub fn retrieve_sections(
  documents : Array[SearchDocument],
  query : String,
  required_tags : Array[String],
  limit : Int32,
  aliases~ : Map[String, Array[String]] = Map([]),
) -> Array[SectionHit] {
  let query_terms = frequencies(query).keys().to_array()
  if query_terms.is_empty() || limit <= 0 {
    return []
  }
  let filters = required_tags.map(fn(tag) { tag.trim().to_owned().to_lower() })
  let hits : Array[SectionHit] = []
  for document in documents {
    let tags = document.tags.map(fn(tag) { tag.to_lower() })
    if !filters.iter().all(fn(tag) { tags.contains(tag) }) {
      continue
    }
    let title = frequencies(document.title)
    let names = frequencies(aliases.get(document.url).unwrap_or([]).join(" "))
    // A complete alternate-name query is one page hit, not one per passage.
    // Existing title-only retrieval retains its section behavior and scores.
    let name_query = query_terms.all(fn(term) {
        title.contains(term) || names.contains(term)
      }) &&
      query_terms.any(fn(term) { !title.contains(term) && names.contains(term) })
    let has_text_match = name_query &&
      document.sections.any(fn(section) {
        let heading = frequencies(section.heading)
        let body = frequencies(section.body)
        query_terms.all(fn(term) {
          title.contains(term) || heading.contains(term) || body.contains(term)
        })
      })
    for index = 0; index < document.sections.length(); index = index + 1 {
      let section = document.sections[index]
      let heading = frequencies(section.heading)
      let body = frequencies(section.body)
      let mut score = 0
      let mut matched = true
      let mut used_alias = false
      for term in query_terms {
        let h = heading.contains(term)
        let t = title.contains(term)
        let b = body.get(term).unwrap_or(0)
        let a = names.contains(term)
        if !h && !t && b == 0 && !a {
          matched = false
          break
        }
        if a && !h && !t && b == 0 {
          used_alias = true
        }
        score = score +
          (if h { 12 } else { 0 }) +
          (if t { 6 } else { 0 }) +
          (if b > 0 { 1 + b } else { 0 }) +
          (if a && !h && !t && b == 0 { 3 } else { 0 })
      }
      if matched && !(name_query && used_alias && (has_text_match || index > 0)) {
        hits.push({
          title: document.title,
          url: document.url,
          tags: document.tags,
          section: section.heading,
          section_index: index,
          snippet: section_snippet(section.body, query_terms),
          score,
        })
      }
    }
  }
  hits.sort_by(fn(a, b) {
    let score = b.score.compare(a.score)
    if score != 0 {
      return score
    }
    let url = a.url.compare(b.url)
    if url != 0 {
      return url
    }
    a.section_index.compare(b.section_index)
  })
  hits.iter().take(limit.min(50)).to_array()
}

///|
fn string_array(value : Json) -> Result[Array[String], String] {
  guard value is Array(items) else {
    return Err("expected an array of strings")
  }
  let result : Array[String] = []
  for item in items {
    guard item is String(text) else {
      return Err("expected an array of strings")
    }
    result.push(text)
  }
  Ok(result)
}

///|
fn decode_documents(value : Json) -> Result[Array[SearchDocument], String] {
  guard value is Array(entries) else {
    return Err("expected a content-index array")
  }
  let documents : Array[SearchDocument] = []
  for entry in entries {
    guard entry is Object(fields) &&
      fields.get("title") is Some(String(title)) &&
      fields.get("url") is Some(String(url)) &&
      url != "" &&
      fields.get("tags") is Some(tags_json) else {
      return Err("each page requires title, nonempty url and tags")
    }
    let tags = match string_array(tags_json) {
      Ok(tags) => tags
      Err(message) => return Err(message)
    }
    if fields.get("aliases") is Some(value) {
      if string_array(value) is Err(_) {
        return Err("aliases must be an array of strings")
      }
    }
    let sections : Array[@markdown.TextSection] = []
    match fields.get("sections") {
      // Old indexes remain searchable as one page-sized section.
      None => {
        guard fields.get("body") is Some(String(body)) else {
          return Err("a page without sections requires body text")
        }
        sections.push({ heading: "", body, })
      }
      Some(Array(items)) =>
        for item in items {
          guard item is Object(section) &&
            section.get("heading") is Some(String(heading)) &&
            section.get("body") is Some(String(body)) else {
            return Err("each section requires heading and body strings")
          }
          sections.push({ heading, body, })
        }
      Some(_) => return Err("sections must be an array")
    }
    documents.push({ title, url, tags, sections, })
  }
  Ok(documents)
}

///|
/// Portable supplied-text boundary. Returns {results: [...], error: null|string}.
/// Invalid input fails the whole request; no partial or silently dropped pages.
/// An explicit empty sections array suppresses that entry, unlike legacy body
/// fallback. Citation URLs are copied from the index, never invented from titles.
pub fn search_content(
  index_json : String,
  query : String,
  tags_json : String,
  limit : Int32,
) -> String {
  let index = @json.parse(index_json[:]) catch {
    _ => return search_response([], Some("invalid content-index JSON"))
  }
  let tags = @json.parse(tags_json[:]) catch {
    _ => return search_response([], Some("invalid tag-filter JSON"))
  }
  let tags = match string_array(tags) {
    Ok(tags) => tags
    Err(message) => return search_response([], Some(message))
  }
  let documents = match decode_documents(index) {
    Ok(documents) => documents
    Err(message) => return search_response([], Some(message))
  }
  // Keep canonical page URLs and ranking unchanged. Ambiguous duplicate page
  // records deliberately retain page-only citations.
  let aliases : Map[String, Array[String]] = Map([])
  let fragments : Map[String, Map[Int32, String]] = Map([])
  let seen : Map[String, Bool] = Map([])
  if index is Array(entries) {
    for entry in entries {
      if entry is Object(fields) && fields.get("url") is Some(String(url)) {
        if seen.contains(url) {
          fragments.remove(url)
          aliases.remove(url)
          continue
        }
        seen.set(url, true)
        if fields.get("aliases") is Some(value) {
          match string_array(value) {
            Ok(names) => aliases.set(url, names)
            Err(_) =>
              return search_response(
                [],
                Some("aliases must be an array of strings"),
              )
          }
        }
        let items : Map[Int32, String] = Map([])
        if fields.get("sections") is Some(Array(sections)) {
          for i = 0; i < sections.length(); i = i + 1 {
            if sections[i] is Object(section) &&
              section.get("fragment") is Some(String(fragment)) &&
              fragment != "" {
              items.set(i, fragment)
            }
          }
        }
        fragments.set(url, items)
      }
    }
  }
  search_response(
    retrieve_sections(documents, query, tags, limit, aliases~),
    None,
    fragments~,
  )
}

///|
fn search_response(
  hits : Array[SectionHit],
  error : String?,
  fragments~ : Map[String, Map[Int32, String]] = Map([]),
) -> String {
  let results = hits.map(fn(hit) {
    let fields = Map([
      ("title", Json::string(hit.title)),
      ("url", Json::string(hit.url)),
      ("tags", Json::array(hit.tags.map(Json::string))),
      ("section", Json::string(hit.section)),
      ("section_index", Json::number(hit.section_index.to_double())),
      ("snippet", Json::string(hit.snippet)),
      ("score", Json::number(hit.score.to_double())),
    ])
    if fragments.get(hit.url) is Some(items) &&
      items.get(hit.section_index) is Some(fragment) {
      fields.set("fragment", Json::string(fragment))
    }
    Json::object(fields)
  })
  Json::object(
    Map([
      ("results", Json::array(results)),
      (
        "error",
        match error {
          Some(message) => Json::string(message)
          None => Json::null()
        },
      ),
    ]),
  ).stringify()
}
