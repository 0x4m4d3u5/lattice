///|
fn local_graph_html(data : String) -> String {
  let value = @json.parse(data[:]) catch { _ => return "" }
  guard value is Object(fields) && fields.get("nodes") is Some(Array(nodes)) && nodes.length() > 1 else { return "" }
  let center = match nodes[0] { Object(n) => match n.get("slug") { Some(String(slug)) => slug; _ => "" }; _ => "" }
  let edges = match fields.get("edges") { Some(Array(edges)) => edges; _ => [] }
  let items = StringBuilder()
  for i = 1; i < nodes.length(); i = i + 1 {
    if nodes[i] is Object(node) && node.get("url") is Some(String(url)) && node.get("title") is Some(String(title)) {
      let slug = match node.get("slug") { Some(String(slug)) => slug; _ => "" }
      let mut incoming = false
      let mut outgoing = false
      for edge in edges {
        if edge is Object(e) && e.get("source") is Some(String(a)) && e.get("target") is Some(String(b)) {
          if a == slug && b == center { incoming = true }
          if a == center && b == slug { outgoing = true }
        }
      }
      let direction = if incoming && outgoing { "both directions" } else if incoming { "links here" } else { "linked from here" }
      items.write_string("<li>" + @html.anchor(url, title) + " <small>— " + direction + "</small></li>")
    }
  }
  "<details class=\"local-graph\" data-local-graph=\"" + @html.escape_html_attr(data) + "\"><summary>Connections around this note</summary><p>Authored links to and from this note. Showing up to 30 neighbors, ordered by slug. Arrows point from the referring note to its destination.</p><div class=\"graph-enhancement\"></div><ul class=\"graph-links\">" + items.to_string() + "</ul></details>"
}
