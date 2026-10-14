///|
test "escaped quoted fallbacks publish through chained filters and cache" {
  let config = publication_fixture("quoted_filter_fallback")
  @fs.write_string_to_file(
    config.content_dir + "/../collections.cfg",
    "[posts]\nschema = title:String,date:Date,optional:Optional[String]\ndir = " +
    config.content_dir +
    "/posts\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/../templates/page.html",
    "<span>{{page.optional | default \"Read \\\"A|B\\\"\" | upper}}</span>{{content}}",
  )
  assert_eq(@builder.check(config).violations.length(), 0)
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
    assert_true(html.contains("<span>READ \"A|B\"</span>"))
    assert_true(html.contains("<p>Original alpha.</p>"))
  }
}
