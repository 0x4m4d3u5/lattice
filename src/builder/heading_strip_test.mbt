///|
test "body_no_h1 removes the rendered title but preserves later headings" {
  let config = publication_fixture("body_no_h1_anchor")
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\n---\n# Alpha\n\nBody.\n\n# Later\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/../templates/page.html",
    "<html><h1>{{page.title}}</h1><main>{{body_no_h1}}</main></html>",
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
    let result = @builder.build(build_config, cache)
    assert_eq(result.errors, 0)
    assert_eq(@builder.check(build_config).violations.length(), 0)
    if pass == 1 {
      assert_true(result.unchanged_pages >= 2)
    }
    let html = @fs.read_file_to_string(
      config.output_dir + "/posts/alpha/index.html",
    )
    assert_true(
      html.contains(
        "<h1>Alpha</h1><main><p>Body.</p>\n<h1 id=\"later\">Later</h1>\n</main>",
      ),
    )
    assert_false(html.contains("<h1 id=\"alpha\">"))
  }
}
