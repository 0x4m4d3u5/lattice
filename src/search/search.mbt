///|
/// JSON search index rendering for lattice.
///
/// The renderer is pure: it accepts typed search entries and returns JSON.
pub struct SearchEntry {
  title : String
  slug : String
  url : String
  tags : Array[String]
  collection : String
  excerpt : String
}

///|
pub fn new_entry(
  title : String,
  slug : String,
  url : String,
  tags : Array[String],
  collection : String,
  excerpt : String,
) -> SearchEntry {
  { title, slug, url, tags, collection, excerpt }
}

///|
/// A full-text content index entry — includes the stripped plaintext body so
/// agents and LLMs can RAG over the complete page content, not just an excerpt.
pub struct ContentEntry {
  title : String
  slug : String
  url : String
  tags : Array[String]
  collection : String
  date : String
  description : String
  body : String
}

///|
pub fn new_content_entry(
  title : String,
  slug : String,
  url : String,
  tags : Array[String],
  collection : String,
  date : String,
  description : String,
  body : String,
) -> ContentEntry {
  { title, slug, url, tags, collection, date, description, body }
}

///|
/// Render `content-index.json` from typed content entries.
///
/// Unlike the search index (excerpt only), the content index stores the full
/// stripped plaintext body — suitable for semantic search or LLM consumption.
pub fn render_content_index(entries : Array[ContentEntry]) -> String {
  let buf = StringBuilder::new()
  buf.write_string("[\n")
  let mut i = 0
  while i < entries.length() {
    let entry = entries[i]
    if i > 0 {
      buf.write_string(",\n")
    }
    buf.write_string("  {\n")
    buf.write_string("    \"title\": ")
    @strutil.write_json_string(buf, entry.title)
    buf.write_string(",\n")
    buf.write_string("    \"slug\": ")
    @strutil.write_json_string(buf, entry.slug)
    buf.write_string(",\n")
    buf.write_string("    \"url\": ")
    @strutil.write_json_string(buf, entry.url)
    buf.write_string(",\n")
    buf.write_string("    \"tags\": [")
    let mut j = 0
    while j < entry.tags.length() {
      if j > 0 {
        buf.write_string(", ")
      }
      @strutil.write_json_string(buf, entry.tags[j])
      j = j + 1
    }
    buf.write_string("],\n")
    buf.write_string("    \"collection\": ")
    @strutil.write_json_string(buf, entry.collection)
    buf.write_string(",\n")
    buf.write_string("    \"date\": ")
    @strutil.write_json_string(buf, entry.date)
    buf.write_string(",\n")
    buf.write_string("    \"description\": ")
    @strutil.write_json_string(buf, entry.description)
    buf.write_string(",\n")
    buf.write_string("    \"body\": ")
    @strutil.write_json_string(buf, entry.body)
    buf.write_string("\n")
    buf.write_string("  }")
    i = i + 1
  }
  if entries.length() > 0 {
    buf.write_char('\n')
  }
  buf.write_string("]\n")
  buf.to_string()
}

///|
/// Render `search-index.json` from typed search entries.
pub fn render_search_index(entries : Array[SearchEntry]) -> String {
  let buf = StringBuilder::new()
  buf.write_string("[\n")
  let mut i = 0
  while i < entries.length() {
    let entry = entries[i]
    if i > 0 {
      buf.write_string(",\n")
    }
    buf.write_string("  {\n")
    buf.write_string("    \"title\": ")
    @strutil.write_json_string(buf, entry.title)
    buf.write_string(",\n")
    buf.write_string("    \"slug\": ")
    @strutil.write_json_string(buf, entry.slug)
    buf.write_string(",\n")
    buf.write_string("    \"url\": ")
    @strutil.write_json_string(buf, entry.url)
    buf.write_string(",\n")
    buf.write_string("    \"tags\": [")
    let mut j = 0
    while j < entry.tags.length() {
      if j > 0 {
        buf.write_string(", ")
      }
      @strutil.write_json_string(buf, entry.tags[j])
      j = j + 1
    }
    buf.write_string("],\n")
    buf.write_string("    \"collection\": ")
    @strutil.write_json_string(buf, entry.collection)
    buf.write_string(",\n")
    buf.write_string("    \"excerpt\": ")
    @strutil.write_json_string(buf, entry.excerpt)
    buf.write_string("\n")
    buf.write_string("  }")
    i = i + 1
  }
  if entries.length() > 0 {
    buf.write_char('\n')
  }
  buf.write_string("]\n")
  buf.to_string()
}
