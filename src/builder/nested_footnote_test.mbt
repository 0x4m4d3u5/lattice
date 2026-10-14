///|
test "nested footnote wikilinks validate and publish on fresh and cached builds" {
  let config = publication_fixture("nested_footnote_links")
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\n---\nText[^source].\n\n> [^source]: Read [[beta|Beta guide]].\n",
  )
  for pass in 0..<2 {
    let cache = if pass == 0 {
      @cache.empty(config.output_dir)
    } else {
      publication_load_cache(config)
    }
    let build_config = if pass == 0 {
      config
    } else {
      publication_incremental(config)
    }
    assert_eq(@builder.check(build_config).violations.length(), 0)
    let result = @builder.build(build_config, cache)
    assert_eq(result.errors, 0)
    if pass == 1 {
      assert_true(result.unchanged_pages >= 2)
    }
    let html = @fs.read_file_to_string(
      config.output_dir + "/posts/alpha/index.html",
    )
    assert_true(
      html.contains(
        "<li id=\"fn-source\">Read <a href=\"/posts/beta/\">Beta guide</a>.",
      ),
    )
    let graph = @fs.read_file_to_string(config.output_dir + "/graph.json")
    assert_true(graph.contains("\"source\": \"alpha\", \"target\": \"beta\""))
  }
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\n---\nText[^source].\n\n> [^source]: Read [[missing]].\n",
  )
  let checked = @builder.check(config)
  let broken = checked.violations.filter(fn(v) {
    v.kind == @lint.BrokenWikilink
  })
  assert_eq(broken.length(), 1)
  assert_true(broken[0].message.contains("missing"))
}
