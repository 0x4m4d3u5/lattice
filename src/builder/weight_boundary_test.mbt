///|
test "every explicit weight precedes absence and equal weights remain stable" {
  let pages : Array[@graph.GraphPage] = []
  for
    (slug, weight) in [
      ("notes-a", None),
      ("reference-a", Some(2147483647)),
      ("intro", Some(-2147483648)),
      ("reference-b", Some(2147483647)),
      ("notes-b", None),
      ("chapter", Some(0)),
    ] {
    pages.push({
      slug,
      title: slug,
      url: "/" + slug + "/",
      description: None,
      date: None,
      weight,
      content_html: "",
      outgoing: [],
    })
  }
  @builder.sort_collection_pages(pages, @collections.Weight)
  assert_eq(pages.map(fn(p) { p.slug }), [
    "intro", "chapter", "reference-a", "reference-b", "notes-a", "notes-b",
  ])
}

///|
test "manual index and navigation keep terminal explicit weight before unweighted notes" {
  let config = publication_fixture("weight_boundary")
  @fs.write_string_to_file(
    config.collections_path.unwrap(),
    "[posts]\nschema = title:String,date:Date,weight:Optional[Int]\ndir = " +
    config.content_dir +
    "/posts\nsort = weight\npage_size = 2\n",
  )
  @fs.write_string_to_file(
    config.site.templates_dir.unwrap() + "/page.html",
    "<html><body><nav>{{prev_post_url}}|{{prev_post_title}}|{{next_post_url}}|{{next_post_title}}</nav>{{content}}</body></html>\n",
  )
  @fs.write_string_to_file(
    config.site.templates_dir.unwrap() + "/index.html",
    "<html><body>{{content}}</body></html>\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Notes\ndate: 2026-01-02\n---\nUnweighted notes.\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/start.md",
    "---\ntitle: Introduction\ndate: 2026-01-02\nweight: -1\n---\nFirst chapter.\n",
  )
  let path = config.content_dir + "/posts/beta.md"
  @fs.write_string_to_file(
    path, "---\ntitle: Reference\ndate: 2026-01-02\nweight: 10\n---\nReference appendix.\n",
  )
  publication_seed_success(config)
  for terminal_weight in [false, true] {
    if terminal_weight {
      @fs.write_string_to_file(
        path, "---\ntitle: Reference\ndate: 2026-01-02\nweight: 2147483647\n---\nReference appendix.\n",
      )
    }
    let result = @builder.build(
      publication_incremental(config),
      publication_load_cache(config),
    )
    assert_eq(result.errors, 0)
    let first = @fs.read_file_to_string(config.output_dir + "/posts/index.html")
    assert_true(
      first.contains(
        "<li><a href=\"/posts/start/\">Introduction</a> <code>start</code></li>\n<li><a href=\"/posts/beta/\">Reference</a> <code>beta</code></li>",
      ),
    )
    let second = @fs.read_file_to_string(
      config.output_dir + "/posts/page/2/index.html",
    )
    assert_true(
      second.contains(
        "<li><a href=\"/posts/alpha/\">Notes</a> <code>alpha</code></li>",
      ),
    )
    for
      (slug, expected) in [
        ("start", "<nav>||/posts/beta/|Reference</nav>"),
        ("beta", "<nav>/posts/start/|Introduction|/posts/alpha/|Notes</nav>"),
        ("alpha", "<nav>/posts/beta/|Reference||</nav>"),
      ] {
      assert_true(
        @fs.read_file_to_string(
          config.output_dir + "/posts/" + slug + "/index.html",
        ).contains(expected),
      )
    }
    assert_eq(result.unchanged_pages, if terminal_weight { 2 } else { 3 })
    let before = publication_snapshot(config.output_dir)
    assert_eq(@builder.check(config).violations.length(), 0)
    assert_eq(publication_snapshot(config.output_dir), before)
    let full = @builder.build(config, publication_load_cache(config))
    assert_eq(full.errors, 0)
    assert_eq(
      @fs.read_file_to_string(config.output_dir + "/posts/index.html"),
      first,
    )
    assert_eq(
      @fs.read_file_to_string(config.output_dir + "/posts/page/2/index.html"),
      second,
    )
  }
  let next = @builder.build(
    publication_incremental(config),
    publication_load_cache(config),
  )
  assert_eq(next.errors, 0)
  assert_eq(next.unchanged_pages, 3)
}
