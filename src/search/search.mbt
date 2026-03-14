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
fn char_at_search(s : String, i : Int) -> Char {
  s[i].to_int().unsafe_to_char()
}

///|
fn hex_nibble(n : Int) -> Char {
  if n < 10 {
    ('0'.to_int() + n).unsafe_to_char()
  } else {
    ('a'.to_int() + (n - 10)).unsafe_to_char()
  }
}

///|
fn write_json_string(buf : StringBuilder, s : String) -> Unit {
  buf.write_char('"')
  let n = s.length()
  let mut i = 0
  while i < n {
    let c = char_at_search(s, i)
    if c == '\\' {
      buf.write_string("\\\\")
    } else if c == '"' {
      buf.write_string("\\\"")
    } else if c == '\n' {
      buf.write_string("\\n")
    } else if c == '\r' {
      buf.write_string("\\r")
    } else if c == '\t' {
      buf.write_string("\\t")
    } else if c.to_int() < 0x20 {
      let code = c.to_int()
      buf.write_string("\\u00")
      buf.write_char(hex_nibble(code / 16))
      buf.write_char(hex_nibble(code % 16))
    } else {
      buf.write_char(c)
    }
    i = i + 1
  }
  buf.write_char('"')
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
    write_json_string(buf, entry.title)
    buf.write_string(",\n")
    buf.write_string("    \"slug\": ")
    write_json_string(buf, entry.slug)
    buf.write_string(",\n")
    buf.write_string("    \"url\": ")
    write_json_string(buf, entry.url)
    buf.write_string(",\n")
    buf.write_string("    \"tags\": [")
    let mut j = 0
    while j < entry.tags.length() {
      if j > 0 {
        buf.write_string(", ")
      }
      write_json_string(buf, entry.tags[j])
      j = j + 1
    }
    buf.write_string("],\n")
    buf.write_string("    \"collection\": ")
    write_json_string(buf, entry.collection)
    buf.write_string(",\n")
    buf.write_string("    \"excerpt\": ")
    write_json_string(buf, entry.excerpt)
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
