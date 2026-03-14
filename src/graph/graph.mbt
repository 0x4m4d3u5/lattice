///|
/// Shared typed page-graph artifacts produced by the builder's pass 2.
///
/// This type is intentionally shared across modules (builder, site-index, RSS)
/// so downstream emitters consume structural data rather than reparsing strings.
pub(all) struct GraphPage {
  slug : String
  title : String
  url : String
  description : String?
  date : String?
  outgoing : Array[@wikilink.ResolvedWikilink]
}

///|
fn hex_nibble_graph(n : Int) -> Char {
  if n < 10 {
    ('0'.to_int() + n).unsafe_to_char()
  } else {
    ('a'.to_int() + (n - 10)).unsafe_to_char()
  }
}

///|
fn write_json_string_graph(buf : StringBuilder, s : String) -> Unit {
  buf.write_char('"')
  let n = s.length()
  let mut i = 0
  while i < n {
    let c = s[i].to_int().unsafe_to_char()
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
      buf.write_char(hex_nibble_graph(code / 16))
      buf.write_char(hex_nibble_graph(code % 16))
    } else {
      buf.write_char(c)
    }
    i = i + 1
  }
  buf.write_char('"')
}

///|
/// Render graph.json from the site-wide page graph.
///
/// The JSON object has two top-level arrays:
///   "nodes" — one entry per page (slug, title, url)
///   "edges" — one entry per wikilink (source slug → target slug)
///
/// This is suitable for external graph visualisation tools (e.g. D3, Cytoscape).
pub fn render_graph_json(pages : Array[GraphPage]) -> String {
  let buf = StringBuilder::new()
  buf.write_string("{\n")
  buf.write_string("  \"nodes\": [\n")
  let mut i = 0
  while i < pages.length() {
    let page = pages[i]
    if i > 0 {
      buf.write_string(",\n")
    }
    buf.write_string("    {\"slug\": ")
    write_json_string_graph(buf, page.slug)
    buf.write_string(", \"title\": ")
    write_json_string_graph(buf, page.title)
    buf.write_string(", \"url\": ")
    write_json_string_graph(buf, page.url)
    buf.write_char('}')
    i = i + 1
  }
  if pages.length() > 0 {
    buf.write_char('\n')
  }
  buf.write_string("  ],\n")
  buf.write_string("  \"edges\": [\n")
  let mut first_edge = true
  i = 0
  while i < pages.length() {
    let page = pages[i]
    let mut j = 0
    while j < page.outgoing.length() {
      let edge = page.outgoing[j]
      if not(first_edge) {
        buf.write_string(",\n")
      }
      buf.write_string("    {\"source\": ")
      write_json_string_graph(buf, page.slug)
      buf.write_string(", \"target\": ")
      write_json_string_graph(buf, edge.raw.target)
      buf.write_char('}')
      first_edge = false
      j = j + 1
    }
    i = i + 1
  }
  if not(first_edge) {
    buf.write_char('\n')
  }
  buf.write_string("  ]\n")
  buf.write_string("}\n")
  buf.to_string()
}
