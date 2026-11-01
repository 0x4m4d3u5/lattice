///|
fn local_graph_html(data : String) -> String {
  let value = @json.parse(data[:]) catch { _ => return "" }
  guard value is Object(fields) && fields.get("nodes") is Some(Array(nodes)) && nodes.length() > 1 else { return "" }
  let items = StringBuilder()
  for i = 1; i < nodes.length(); i = i + 1 {
    if nodes[i] is Object(node) && node.get("url") is Some(String(url)) && node.get("title") is Some(String(title)) {
      items.write_string("<li>" + @html.anchor(url, title) + "</li>")
    }
  }
  "<details class=\"local-graph\" data-local-graph=\"" + @html.escape_html_attr(data) + "\"><summary>Connections around this note</summary><p>Authored links to and from this note. Showing up to 30 neighbors, ordered by slug. Arrows point from the referring note to its destination.</p><div class=\"graph-enhancement\"></div><ul class=\"graph-links\">" + items.to_string() + "</ul></details>"
}
