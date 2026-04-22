///|
fn raw_link(target : String) -> @wikilink.ResolvedWikilink {
  {
    raw: { target, display: None, source_file: "test.md" },
    url: "/" + target,
    title: target,
  }
}

///|
test "render_graph_json empty pages produces valid JSON shell" {
  let json = render_graph_json([])
  assert_eq(json.contains("\"nodes\""), true)
  assert_eq(json.contains("\"edges\""), true)
  assert_eq(json.contains("  \"nodes\": [\n  ]"), true)
  assert_eq(json.contains("  \"edges\": [\n  ]"), true)
}

///|
test "render_graph_json single page with no outgoing links" {
  let pages : Array[GraphPage] = [
    {
      slug: "hello",
      title: "Hello World",
      url: "/hello",
      description: None,
      date: None,
      weight: None,
      outgoing: [],
    },
  ]
  let json = render_graph_json(pages)
  assert_eq(json.contains("\"slug\": \"hello\""), true)
  assert_eq(json.contains("\"title\": \"Hello World\""), true)
  assert_eq(json.contains("\"url\": \"/hello\""), true)
}

///|
test "render_graph_json emits edges for outgoing wikilinks" {
  let pages : Array[GraphPage] = [
    {
      slug: "post-a",
      title: "Post A",
      url: "/posts/post-a",
      description: None,
      date: None,
      weight: None,
      outgoing: [raw_link("post-b")],
    },
    {
      slug: "post-b",
      title: "Post B",
      url: "/posts/post-b",
      description: None,
      date: None,
      weight: None,
      outgoing: [],
    },
  ]
  let json = render_graph_json(pages)
  assert_eq(json.contains("\"source\": \"post-a\""), true)
  assert_eq(json.contains("\"target\": \"post-b\""), true)
}

///|
test "render_graph_json escapes double quotes in title" {
  let pages : Array[GraphPage] = [
    {
      slug: "notes",
      title: "Notes & \"Tips\"",
      url: "/notes",
      description: None,
      date: None,
      weight: None,
      outgoing: [],
    },
  ]
  let json = render_graph_json(pages)
  // Standard JSON: quotes are escaped, ampersand is literal
  assert_eq(json.contains("\\\"Tips\\\""), true)
  assert_eq(json.contains("Notes & "), true)
}

///|
test "render_graph_json multiple pages produce comma-separated node entries" {
  let pages : Array[GraphPage] = [
    {
      slug: "a",
      title: "A",
      url: "/a",
      description: None,
      date: None,
      weight: None,
      outgoing: [],
    },
    {
      slug: "b",
      title: "B",
      url: "/b",
      description: None,
      date: None,
      weight: None,
      outgoing: [],
    },
  ]
  let json = render_graph_json(pages)
  assert_eq(json.contains("\"slug\": \"a\""), true)
  assert_eq(json.contains("\"slug\": \"b\""), true)
}
