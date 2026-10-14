///|
test "short fences stay code in validation and cached publishing" {
  let config = publication_fixture("fence_length")
  let body = "````\nfirst\n```\n[[missing]]\nlast\n````\n\nVisible paragraph.\n"
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\n---\n" + body,
  )
  assert_eq(@builder.count_words_markdown(body), 2)
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
    assert_eq(result.diagnostics.length(), 0)
    if pass == 1 {
      assert_true(result.unchanged_pages >= 2)
    }
    let html = @fs.read_file_to_string(
      config.output_dir + "/posts/alpha/index.html",
    )
    assert_true(
      html.contains("<pre><code>first\n```\n[[missing]]\nlast</code></pre>"),
    )
    assert_true(html.contains("<p>Visible paragraph.</p>"))
    let search = @json.parse(
      @fs.read_file_to_string(config.output_dir + "/search-index.json"),
    )
    guard search is Array(entries) else {
      abort("search index must be an array")
    }
    let alpha = entries.filter(fn(entry) {
      match entry {
        Object(fields) =>
          fields.get("url") == Some(Json::string("/posts/alpha/"))
        _ => false
      }
    })
    assert_eq(alpha.length(), 1)
    guard alpha[0] is Object(fields) else { abort("entry must be an object") }
    assert_eq(fields.get("excerpt"), Some(Json::string("Visible paragraph.")))
  }
}
