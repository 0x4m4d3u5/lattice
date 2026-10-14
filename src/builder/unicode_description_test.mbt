///|
test "description truncation counts Unicode characters without splitting them" {
  assert_eq(@builder.truncate_to_builder("🌱🌳ABC", 3), "🌱🌳A")
  assert_eq(@builder.truncate_to_builder("a🌱b", 2), "a🌱")
  assert_eq(@builder.truncate_to_builder("🌱", 0), "")
}

///|
test "automatic descriptions preserve the Unicode character at the limit" {
  let config = publication_fixture("unicode_description")
  @fs.write_string_to_file(
    config.content_dir + "/../templates/page.html",
    "<meta name=\"description\" content=\"{{description}}\">{{head_meta}}{{content}}",
  )
  // Independent expected prefix: 159 ASCII characters followed by one emoji.
  let prefix = "123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789"
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\n---\n" + prefix + "🌱Tail.\n",
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
    if pass == 1 {
      assert_true(result.unchanged_pages >= 2)
    }
    let html = @fs.read_file_to_string(
      config.output_dir + "/posts/alpha/index.html",
    )
    assert_true(
      html.contains("<meta name=\"description\" content=\"" + prefix + "🌱\""),
    )
    assert_true(
      html.contains(
        "<meta property=\"og:description\" content=\"" + prefix + "🌱\"",
      ),
    )
    assert_true(html.contains("<p>" + prefix + "🌱Tail.</p>"))
  }
}
