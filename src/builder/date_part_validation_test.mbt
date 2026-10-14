///|
test "invalid string dates use template fallbacks in fresh and cached publishing" {
  let config = publication_fixture("date_part_fallback")
  @fs.write_string_to_file(
    config.content_dir + "/../collections.cfg",
    "[posts]\nschema = title:String,date:Date,stamp:Optional[String]\ndir = " +
    config.content_dir +
    "/posts\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\nstamp: \"2026-02-30\"\n---\nOriginal alpha.\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/../templates/page.html",
    "<span>{{page.stamp | date_part year | default \"Undated\"}}</span>{{content}}",
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
    assert_true(html.contains("<span>Undated</span>"))
    assert_true(html.contains("<p>Original alpha.</p>"))
  }
}
