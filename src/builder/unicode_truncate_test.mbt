///|
test "Unicode title truncation publishes complete characters through cache" {
  let config = publication_fixture("unicode_template_truncate")
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: 🌱 Garden\ndate: 2026-01-02\n---\nOriginal alpha.\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/../templates/page.html",
    "<span>{{page.title | truncate 1}}</span>{{content}}",
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
    assert_true(html.contains("<span>🌱...</span>"))
    assert_true(html.contains("<p>Original alpha.</p>"))
  }
}
