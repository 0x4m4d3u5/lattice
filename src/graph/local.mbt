///|
/// A bounded, deterministic one-hop view. Canonical URLs are browser identities;
/// graph edges retain their existing authored-wikilink slug identity.
pub fn local_layout(source : String, current : String) -> String {
  let json = @json.parse(source[:]) catch { _ => return "{}" }
  guard json is Object(fields) && fields.get("nodes") is Some(Array(nodes)) && fields.get("edges") is Some(Array(edges)) else { return "{}" }
  let by_slug : Map[String, (String, String)] = Map([])
  let mut center : String? = None
  for node in nodes {
    if node is Object(n) && n.get("slug") is Some(String(slug)) && n.get("url") is Some(String(url)) && n.get("title") is Some(String(title)) {
      if by_slug.contains(slug) { return "{}" }
      by_slug.set(slug, (title, url))
      if url == current { center = Some(slug) }
    }
  }
  guard center is Some(center) else { return "{}" }
  let pairs : Array[(String, String)] = []
  let neighbors : Map[String, Bool] = Map([])
  for edge in edges {
    if edge is Object(e) && e.get("source") is Some(String(a)) && e.get("target") is Some(String(b)) && by_slug.contains(a) && by_slug.contains(b) {
      pairs.push((a, b))
      if a == center && b != center { neighbors.set(b, true) }
      if b == center && a != center { neighbors.set(a, true) }
    }
  }
  let ordered = neighbors.keys().collect()
  ordered.sort_by((a, b) => a.lexical_compare(b))
  let selected = [center]
  for i = 0; i < ordered.length() && i < 30; i = i + 1 { selected.push(ordered[i]) }
  let indices : Map[String, Int] = Map([])
  let xs : Array[Double] = []
  let ys : Array[Double] = []
  for i = 0; i < selected.length(); i = i + 1 {
    indices.set(selected[i], i)
    // Deterministic grid seed avoids random layout jumps on navigation/rebuild.
    xs.push(if i == 0 { 0.0 } else { ((i - 1) % 6).to_double() * 70.0 - 175.0 })
    ys.push(if i == 0 { 0.0 } else { ((i - 1) / 6).to_double() * 70.0 - 140.0 })
  }
  let links : Array[(Int, Int)] = []
  let seen : Map[(Int, Int), Bool] = Map([])
  for (a, b) in pairs {
    if indices.get(a) is Some(a) && indices.get(b) is Some(b) && a != b && !seen.contains((a, b)) {
      links.push((a, b)); seen.set((a, b), true)
    }
  }
  // Fixed budget: at most 31 nodes, 80 relaxation steps. No perpetual animation.
  for _step = 0; _step < 80; _step = _step + 1 {
    let dx = Array::make(selected.length(), 0.0)
    let dy = Array::make(selected.length(), 0.0)
    for i = 0; i < selected.length(); i = i + 1 {
      for j = i + 1; j < selected.length(); j = j + 1 {
        let x = xs[i] - xs[j]
        let y = ys[i] - ys[j]
        let distance = x * x + y * y + 25.0
        let force = 600.0 / distance
        dx[i] = dx[i] + x * force; dy[i] = dy[i] + y * force
        dx[j] = dx[j] - x * force; dy[j] = dy[j] - y * force
      }
    }
    for (a, b) in links {
      let x = (xs[b] - xs[a]) * 0.018
      let y = (ys[b] - ys[a]) * 0.018
      dx[a] = dx[a] + x; dy[a] = dy[a] + y
      dx[b] = dx[b] - x; dy[b] = dy[b] - y
    }
    for i = 1; i < selected.length(); i = i + 1 {
      xs[i] = xs[i] + dx[i] - xs[i] * 0.006
      ys[i] = ys[i] + dy[i] - ys[i] * 0.006
    }
  }
  let result_nodes : Array[Json] = []
  for i = 0; i < selected.length(); i = i + 1 {
    let slug = selected[i]
    let (title, url) = by_slug.get(slug).unwrap()
    result_nodes.push(Json::object(Map([
      ("slug", Json::string(slug)), ("title", Json::string(title)), ("url", Json::string(url)),
      ("x", Json::number(xs[i])), ("y", Json::number(ys[i])),
    ])))
  }
  Json::object(Map([
    ("nodes", Json::array(result_nodes)),
    ("edges", Json::array(links.map(pair => Json::object(Map([
      ("source", Json::string(selected[pair.0])), ("target", Json::string(selected[pair.1])),
    ]))))),
    ("total", Json::number(ordered.length().to_double())),
  ])).stringify()
}

///|
/// Build adjacency once; each reader receives only its bounded local subgraph.
pub fn local_views(pages : Array[GraphPage]) -> Map[String, String] {
  let by_slug : Map[String, GraphPage] = Map([])
  let by_url : Map[String, String] = Map([])
  let neighbors : Map[String, Map[String, Bool]] = Map([])
  for page in pages { by_slug.set(page.slug, page); by_url.set(page.url, page.slug); neighbors.set(page.slug, Map([])) }
  for page in pages {
    for link in page.outgoing {
      let url = match link.url.split_once("#") { Some((url, _)) => url.to_owned(); None => link.url }
      if by_url.get(url) is Some(target) && target != page.slug {
        neighbors.get(page.slug).unwrap().set(target, true)
        neighbors.get(target).unwrap().set(page.slug, true)
      }
    }
  }
  let result : Map[String, String] = Map([])
  for page in pages {
    let adjacent = neighbors.get(page.slug).unwrap().keys().collect()
    adjacent.sort_by((a, b) => a.lexical_compare(b))
    let selected = [page]
    for i = 0; i < adjacent.length() && i < 30; i = i + 1 { selected.push(by_slug.get(adjacent[i]).unwrap()) }
    let view = @json.parse(local_layout(render_graph_json(selected), page.url)[:]) catch { _ => continue }
    if view is Object(fields) {
      fields.set("total", Json::number(adjacent.length().to_double()))
      result.set(page.url, Json::object(fields).stringify())
    }
  }
  result
}
