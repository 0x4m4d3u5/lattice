///|
fn raw_link(target : String) -> @wikilink.ResolvedWikilink {
  {
    raw: { target, display: None, source_file: "test.md" },
    url: "/" + target,
    title: target,
  }
}

///|
test "render_graph_json preserves normalized resolved targets and deduplicates spellings" {
  let links = @wikilink.extract(
    "[[Typed Content Tour]] [[TYPED-CONTENT-TOUR.MD|Tour]] [[typed-content-tour.md]] [[Draft Page]]",
    "hub.md",
  )
  let (resolved, errors) = @wikilink.resolve(
    links,
    Map([
      ("typed-content-tour", "/posts/typed-content-tour/"),
      ("draft-page", "/posts/draft-page/"),
    ]),
  )
  assert_eq(errors.length(), 0)
  assert_eq(resolved.length(), 4)
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "hub",
      title: "Hub",
      url: "/hub/",
      description: None,
      date: None,
      weight: None,
      content_html: "",
      outgoing: resolved,
    },
    {
      slug: "typed-content-tour",
      title: "Typed Content Tour",
      url: "/posts/typed-content-tour/",
      description: None,
      date: None,
      weight: None,
      content_html: "",
      outgoing: [],
    },
  ]
  let json = @graph.render_graph_json(pages)
  let edge = "{\"source\": \"hub\", \"target\": \"typed-content-tour\"}"
  assert_true(json.contains("  \"edges\": [\n    " + edge + "\n  ]"))
  assert_true(!json.contains("draft-page"))
}

///|
test "render_graph_json retains a resolved filename target without a literal slug link" {
  let (resolved, errors) = @wikilink.resolve(
    @wikilink.extract("[[Guide.MD|Read the guide]]", "home.md"),
    Map([("guide", "/guide/")]),
  )
  assert_eq(errors.length(), 0)
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "home",
      title: "Home",
      url: "/",
      description: None,
      date: None,
      weight: None,
      content_html: "",
      outgoing: resolved,
    },
    {
      slug: "guide",
      title: "Guide",
      url: "/guide/",
      description: None,
      date: None,
      weight: None,
      content_html: "",
      outgoing: [],
    },
  ]
  assert_true(
    @graph.render_graph_json(pages).contains(
      "\"source\": \"home\", \"target\": \"guide\"",
    ),
  )
}

///|
test "render_graph_json empty pages produces valid JSON shell" {
  let json = @graph.render_graph_json([])
  assert_eq(json.contains("\"nodes\""), true)
  assert_eq(json.contains("\"edges\""), true)
  assert_eq(json.contains("  \"nodes\": [\n  ]"), true)
  assert_eq(json.contains("  \"edges\": [\n  ]"), true)
}

///|
test "render_graph_json single page with no outgoing links" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "hello",
      title: "Hello World",
      url: "/hello",
      description: None,
      date: None,
      weight: None,
      content_html: "",
      outgoing: [],
    },
  ]
  let json = @graph.render_graph_json(pages)
  assert_eq(json.contains("\"slug\": \"hello\""), true)
  assert_eq(json.contains("\"title\": \"Hello World\""), true)
  assert_eq(json.contains("\"url\": \"/hello\""), true)
}

///|
test "render_graph_json emits edges for outgoing wikilinks" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "post-a",
      title: "Post A",
      url: "/posts/post-a",
      description: None,
      date: None,
      weight: None,
      content_html: "",
      outgoing: [raw_link("post-b")],
    },
    {
      slug: "post-b",
      title: "Post B",
      url: "/posts/post-b",
      description: None,
      date: None,
      weight: None,
      content_html: "",
      outgoing: [],
    },
  ]
  let json = @graph.render_graph_json(pages)
  assert_eq(json.contains("\"source\": \"post-a\""), true)
  assert_eq(json.contains("\"target\": \"post-b\""), true)
}

///|
test "render_graph_json escapes double quotes in title" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "notes",
      title: "Notes & \"Tips\"",
      url: "/notes",
      description: None,
      date: None,
      weight: None,
      content_html: "",
      outgoing: [],
    },
  ]
  let json = @graph.render_graph_json(pages)
  // Standard JSON: quotes are escaped, ampersand is literal
  assert_eq(json.contains("\\\"Tips\\\""), true)
  assert_eq(json.contains("Notes & "), true)
}

///|
test "render_graph_json multiple pages produce comma-separated node entries" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "a",
      title: "A",
      url: "/a",
      description: None,
      date: None,
      weight: None,
      content_html: "",
      outgoing: [],
    },
    {
      slug: "b",
      title: "B",
      url: "/b",
      description: None,
      date: None,
      weight: None,
      content_html: "",
      outgoing: [],
    },
  ]
  let json = @graph.render_graph_json(pages)
  assert_eq(json.contains("\"slug\": \"a\""), true)
  assert_eq(json.contains("\"slug\": \"b\""), true)
}

///|
/// A page with multiple outgoing edges — verify both edges appear comma-separated
test "render_graph_json multiple outgoing edges from single page" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "hub",
      title: "Hub Page",
      url: "/hub",
      description: None,
      date: None,
      weight: None,
      content_html: "",
      outgoing: [raw_link("alpha"), raw_link("beta"), raw_link("gamma")],
    },
    {
      slug: "alpha",
      title: "Alpha",
      url: "/alpha",
      description: None,
      date: None,
      weight: None,
      content_html: "",
      outgoing: [],
    },
    {
      slug: "beta",
      title: "Beta",
      url: "/beta",
      description: None,
      date: None,
      weight: None,
      content_html: "",
      outgoing: [],
    },
    {
      slug: "gamma",
      title: "Gamma",
      url: "/gamma",
      description: None,
      date: None,
      weight: None,
      content_html: "",
      outgoing: [],
    },
  ]
  let json = @graph.render_graph_json(pages)
  // All three edges should appear (targets exist as nodes)
  assert_eq(json.contains("\"source\": \"hub\", \"target\": \"alpha\""), true)
  assert_eq(json.contains("\"source\": \"hub\", \"target\": \"beta\""), true)
  assert_eq(json.contains("\"source\": \"hub\", \"target\": \"gamma\""), true)
  // No trailing comma after the last edge — gamma is the last edge, next line should be ]
  assert_true(!json.contains("gamma\"},\n"))
}

///|
/// Edges targeting slugs absent from the nodes array are filtered out
test "render_graph_json filters dangling edges to excluded pages" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "home",
      title: "Home",
      url: "/",
      description: None,
      date: None,
      weight: None,
      content_html: "",
      outgoing: [
        raw_link("guide"),
        raw_link("draft-page"),
        raw_link("another-draft"),
      ],
    },
    {
      slug: "guide",
      title: "Guide",
      url: "/guide",
      description: None,
      date: None,
      weight: None,
      content_html: "",
      outgoing: [],
    },
    // draft-page and another-draft are NOT in the nodes array
  ]
  let json = @graph.render_graph_json(pages)
  // Only the valid edge (home → guide) should appear
  assert_eq(json.contains("\"source\": \"home\", \"target\": \"guide\""), true)
  // Dangling edges should NOT appear
  assert_true(!json.contains("draft-page"))
  assert_true(!json.contains("another-draft"))
}

///|
/// Title with < > & chars — these should NOT be JSON-escaped (only " and \ need escaping)
test "render_graph_json does not html-escape angle brackets and ampersand in title" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "math",
      title: "x < y > z & w",
      url: "/math",
      description: None,
      date: None,
      weight: None,
      content_html: "",
      outgoing: [],
    },
  ]
  let json = @graph.render_graph_json(pages)
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
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "recursive",
      title: "Self-Reference",
      url: "/recursive",
      description: None,
      date: None,
      weight: None,
      content_html: "",
      outgoing: [raw_link("recursive")],
    },
  ]
  let json = @graph.render_graph_json(pages)
  // The edge should have source == target
  assert_eq(
    json.contains("\"source\": \"recursive\", \"target\": \"recursive\""),
    true,
  )
}

///|
/// Multiple pages with cross-edges produce correctly comma-separated edge list
test "render_graph_json cross-edges between multiple pages" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "a",
      title: "A",
      url: "/a",
      description: None,
      date: None,
      weight: None,
      content_html: "",
      outgoing: [raw_link("b"), raw_link("c")],
    },
    {
      slug: "b",
      title: "B",
      url: "/b",
      description: None,
      date: None,
      weight: None,
      content_html: "",
      outgoing: [raw_link("a")],
    },
    {
      slug: "c",
      title: "C",
      url: "/c",
      description: None,
      date: None,
      weight: None,
      content_html: "",
      outgoing: [],
    },
  ]
  let json = @graph.render_graph_json(pages)
  // Three edges total: a→b, a→c, b→a
  assert_eq(json.contains("\"source\": \"a\", \"target\": \"b\""), true)
  assert_eq(json.contains("\"source\": \"a\", \"target\": \"c\""), true)
  assert_eq(json.contains("\"source\": \"b\", \"target\": \"a\""), true)
  // No edge from c
  assert_true(!json.contains("\"source\": \"c\""))
}

///|
/// Duplicate wikilinks to the same target must produce exactly one edge.
/// This is a regression test for parallel-edge deduplication in render_graph_json.
test "render_graph_json deduplicates parallel edges from same source" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "typed-content-tour",
      title: "Typed Content Tour",
      url: "/typed-content-tour",
      description: None,
      date: None,
      weight: None,
      // Two wikilinks to the same target — should produce one edge
      content_html: "",
      outgoing: [
        raw_link("template-composition"),
        raw_link("template-composition"),
      ],
    },
    {
      slug: "template-composition",
      title: "Template Composition",
      url: "/template-composition",
      description: None,
      date: None,
      weight: None,
      content_html: "",
      outgoing: [],
    },
  ]
  let json = @graph.render_graph_json(pages)
  let edge_str = "\"source\": \"typed-content-tour\", \"target\": \"template-composition\""
  // Count occurrences of the edge string — must be exactly 1
  let mut count = 0
  let mut pos = 0
  while pos <= json.length() - edge_str.length() {
    if json[pos:pos + edge_str.length()] == edge_str {
      count = count + 1
    }
    pos = pos + 1
  }
  inspect(count, content="1")
}
