///|
test "mixed-case scheme autolinks publish across rebuilds" {
  let config = publication_fixture("autolink_case")
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\n---\n<HTTPS://example.test/Guide>\n",
  )
  for pass in 0..<3 {
    let build_config = if pass == 1 {
      publication_incremental(config)
    } else {
      config
    }
    let cache = if pass == 0 {
      @cache.empty(config.output_dir)
    } else {
      publication_load_cache(config)
    }
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
        "<a href=\"HTTPS://example.test/Guide\">HTTPS://example.test/Guide</a>",
      ),
    )
  }
}
