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

///|
/// A page with multiple outgoing edges — verify both edges appear comma-separated
test "render_graph_json multiple outgoing edges from single page" {
  let pages : Array[GraphPage] = [
    {
      slug: "hub",
      title: "Hub Page",
      url: "/hub",
      description: None,
      date: None,
      weight: None,
      outgoing: [raw_link("alpha"), raw_link("beta"), raw_link("gamma")],
    },
  ]
  let json = render_graph_json(pages)
  // All three edges should appear
  assert_eq(json.contains("\"source\": \"hub\", \"target\": \"alpha\""), true)
  assert_eq(json.contains("\"source\": \"hub\", \"target\": \"beta\""), true)
  assert_eq(json.contains("\"source\": \"hub\", \"target\": \"gamma\""), true)
  // No trailing comma after the last edge — gamma is the last edge, next line should be ]
  assert_true(!json.contains("gamma\"},\n"))
}

///|
/// Title with < > & chars — these should NOT be JSON-escaped (only " and \ need escaping)
test "render_graph_json does not html-escape angle brackets and ampersand in title" {
  let pages : Array[GraphPage] = [
    {
      slug: "math",
      title: "x < y > z & w",
      url: "/math",
      description: None,
      date: None,
      weight: None,
      outgoing: [],
    },
  ]
  let json = render_graph_json(pages)
  // < > & should appear literally, not as &lt; &gt; &amp;
  assert_eq(json.contains("x < y > z & w"), true)
  // Double-quote escaping still works correctly
  assert_true(!json.contains("&lt;"))
  assert_true(!json.contains("&gt;"))
  assert_true(!json.contains("&amp;"))
}

///|
/// A page with a self-loop wikilink (same slug as source)
test "render_graph_json self-loop edge source equals target" {
  let pages : Array[GraphPage] = [
    {
      slug: "recursive",
      title: "Self-Reference",
      url: "/recursive",
      description: None,
      date: None,
      weight: None,
      outgoing: [raw_link("recursive")],
    },
  ]
  let json = render_graph_json(pages)
  // The edge should have source == target
  assert_eq(
    json.contains("\"source\": \"recursive\", \"target\": \"recursive\""),
    true,
  )
}

///|
/// Multiple pages with cross-edges produce correctly comma-separated edge list
test "render_graph_json cross-edges between multiple pages" {
  let pages : Array[GraphPage] = [
    {
      slug: "a",
      title: "A",
      url: "/a",
      description: None,
      date: None,
      weight: None,
      outgoing: [raw_link("b"), raw_link("c")],
    },
    {
      slug: "b",
      title: "B",
      url: "/b",
      description: None,
      date: None,
      weight: None,
      outgoing: [raw_link("a")],
    },
    {
      slug: "c",
      title: "C",
      url: "/c",
      description: None,
      date: None,
      weight: None,
      outgoing: [],
    },
  ]
  let json = render_graph_json(pages)
  // Three edges total: a→b, a→c, b→a
  assert_eq(json.contains("\"source\": \"a\", \"target\": \"b\""), true)
  assert_eq(json.contains("\"source\": \"a\", \"target\": \"c\""), true)
  assert_eq(json.contains("\"source\": \"b\", \"target\": \"a\""), true)
  // No edge from c
  assert_true(!json.contains("\"source\": \"c\""))
}
