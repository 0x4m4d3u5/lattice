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
///
/// The `kind` field classifies the page for agent consumption:
///   - "post" — collection member with a date
///   - "page" — collection member without a date
///   - "standalone" — standalone page outside collections
///   - "collection_index" — auto-generated index page for a collection
///
/// The `reading_time` field is an integer number of minutes (null if unknown).
pub(all) struct ContentEntry {
  title : String
  slug : String
  url : String
  tags : Array[String]
  collection : String
  date : String
  description : String
  kind : String
  reading_time : Int?
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
  kind : String,
  reading_time : Int?,
  body : String,
) -> ContentEntry {
  {
    title,
    slug,
    url,
    tags,
    collection,
    date,
    description,
    kind,
    reading_time,
    body,
  }
}

///|
/// Render a JSON array by calling `write_entry` for each element's fields.
///
/// The outer array brackets, inter-entry commas, and `{`/`}` object delimiters
/// are handled here. `write_entry` only needs to emit the field lines
/// (indented with 4 spaces, last field without a trailing comma).
fn[T] render_json_array(
  entries : Array[T],
  write_entry : (StringBuilder, T) -> Unit,
) -> String {
  let buf = StringBuilder::new()
  buf.write_string("[\n")
  let mut i = 0
  while i < entries.length() {
    if i > 0 {
      buf.write_string(",\n")
    }
    buf.write_string("  {\n")
    write_entry(buf, entries[i])
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
/// Write the JSON tag array inline: ["a", "b", "c"]
fn write_tags(buf : StringBuilder, tags : Array[String]) -> Unit {
  buf.write_string("[")
  let mut j = 0
  while j < tags.length() {
    if j > 0 {
      buf.write_string(", ")
    }
    @strutil.write_json_string(buf, tags[j])
    j = j + 1
  }
  buf.write_string("]")
}

///|
/// Write the shared leading fields present in both SearchEntry and ContentEntry.
fn write_common_fields(
  buf : StringBuilder,
  title : String,
  slug : String,
  url : String,
  tags : Array[String],
  collection : String,
) -> Unit {
  buf.write_string("    \"title\": ")
  @strutil.write_json_string(buf, title)
  buf.write_string(",\n")
  buf.write_string("    \"slug\": ")
  @strutil.write_json_string(buf, slug)
  buf.write_string(",\n")
  buf.write_string("    \"url\": ")
  @strutil.write_json_string(buf, url)
  buf.write_string(",\n")
  buf.write_string("    \"tags\": ")
  write_tags(buf, tags)
  buf.write_string(",\n")
  buf.write_string("    \"collection\": ")
  @strutil.write_json_string(buf, collection)
  buf.write_string(",\n")
}

///|
/// Render `content-index.json` from typed content entries.
///
/// Unlike the search index (excerpt only), the content index stores the full
/// stripped plaintext body — suitable for semantic search or LLM consumption.
/// Includes `kind` (page type classification) and `reading_time` (integer
/// minutes or null) for agent-first programmatic consumption.
pub fn render_content_index(entries : Array[ContentEntry]) -> String {
  render_json_array(entries, fn(buf, entry) {
    write_common_fields(
      buf,
      entry.title,
      entry.slug,
      entry.url,
      entry.tags,
      entry.collection,
    )
    buf.write_string("    \"date\": ")
    @strutil.write_json_string(buf, entry.date)
    buf.write_string(",\n")
    buf.write_string("    \"description\": ")
    @strutil.write_json_string(buf, entry.description)
    buf.write_string(",\n")
    buf.write_string("    \"kind\": ")
    @strutil.write_json_string(buf, entry.kind)
    buf.write_string(",\n")
    buf.write_string("    \"reading_time\": ")
    match entry.reading_time {
      Some(mins) => buf.write_string(mins.to_string())
      None => buf.write_string("null")
    }
    buf.write_string(",\n")
    buf.write_string("    \"body\": ")
    @strutil.write_json_string(buf, entry.body)
    buf.write_string("\n")
  })
}

///|
/// Render `search-index.json` from typed search entries.
pub fn render_search_index(entries : Array[SearchEntry]) -> String {
  render_json_array(entries, fn(buf, entry) {
    write_common_fields(
      buf,
      entry.title,
      entry.slug,
      entry.url,
      entry.tags,
      entry.collection,
    )
    buf.write_string("    \"excerpt\": ")
    @strutil.write_json_string(buf, entry.excerpt)
    buf.write_string("\n")
  })
}
