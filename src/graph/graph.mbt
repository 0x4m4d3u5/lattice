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
  weight : Int?
  outgoing : Array[@wikilink.ResolvedWikilink]
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
    @strutil.write_json_string(buf, page.slug)
    buf.write_string(", \"title\": ")
    @strutil.write_json_string(buf, page.title)
    buf.write_string(", \"url\": ")
    @strutil.write_json_string(buf, page.url)
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
      if !first_edge {
        buf.write_string(",\n")
      }
      buf.write_string("    {\"source\": ")
      @strutil.write_json_string(buf, page.slug)
      buf.write_string(", \"target\": ")
      @strutil.write_json_string(buf, edge.raw.target)
      buf.write_char('}')
      first_edge = false
      j = j + 1
    }
    i = i + 1
  }
  if !first_edge {
    buf.write_char('\n')
  }
  buf.write_string("  ]\n")
  buf.write_string("}\n")
  buf.to_string()
}
