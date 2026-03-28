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
