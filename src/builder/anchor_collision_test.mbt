///|
test "release guide publishes distinct heading targets on fresh and edited cached builds" {
  let config = publication_fixture("anchor_collision")
  @fs.write_string_to_file(
    config.site.templates_dir.unwrap() + "/page.html",
    "<html><body>{{table_of_contents}}{{content}}</body></html>\n",
  )
  let source = "---\ntitle: Release Guide\ndate: 2026-01-02\n---\n## Release 2\n\n## Release\n\n## Release\n\n## Release 3\n"
  let path = config.content_dir + "/posts/alpha.md"
  @fs.write_string_to_file(path, source)
  let built = @builder.build(config, @cache.empty(config.output_dir))
  assert_eq(built.errors, 0)
  let expected = [
    ("release-2", "Release 2"),
    ("release", "Release"),
    ("release-3", "Release"),
    ("release-3-2", "Release 3"),
  ]
  for edited in [false, true] {
    if edited {
      @fs.write_string_to_file(path, source + "\n## Release\n")
      expected.push(("release-4", "Release"))
    }
    let incremental = @builder.build(
      publication_incremental(config),
      publication_load_cache(config),
    )
    assert_eq(incremental.errors, 0)
    assert_eq(incremental.unchanged_pages, if edited { 1 } else { 2 })
    let html = @fs.read_file_to_string(
      config.output_dir + "/posts/alpha/index.html",
    )
    let expected_toc = StringBuilder()
    expected_toc.write_string("<nav class=\"table-of-contents\">\n<ul>\n")
    for (anchor, title) in expected {
      let heading = "<h2 id=\"" + anchor + "\">" + title + "</h2>\n"
      assert_true(html.contains(heading))
      assert_eq(html.split("id=\"" + anchor + "\"").count(), 2)
      expected_toc.write_string(
        "<li class=\"toc-level-2\"><a href=\"#" +
        anchor +
        "\">" +
        title +
        "</a></li>\n",
      )
    }
    expected_toc.write_string("</ul>\n</nav>\n")
    assert_true(html.contains(expected_toc.to_string()))
    let before = publication_snapshot(config.output_dir)
    assert_eq(@builder.check(config).violations.length(), 0)
    assert_eq(publication_snapshot(config.output_dir), before)
    let full = @builder.build(config, publication_load_cache(config))
    assert_eq(full.errors, 0)
    assert_eq(
      @fs.read_file_to_string(config.output_dir + "/posts/alpha/index.html"),
      html,
    )
    let cached = @builder.build(
      publication_incremental(config),
      publication_load_cache(config),
    )
    assert_eq(cached.errors, 0)
    assert_eq(cached.unchanged_pages, 2)
  }
}
