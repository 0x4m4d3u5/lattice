///|
test "boolean-prefixed YAML flow tags publish on fresh cached and forced builds" {
  let config = publication_fixture("boolean_prefix_tags")
  @fs.write_string_to_file(
    config.collections_path.unwrap(),
    "[posts]\nschema = title:String,date:Date,tags:Optional[Array[String]]\ndir = " +
    config.content_dir +
    "/posts\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\ntags: [true-crime, falsehood]\n---\nAlpha body.\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/beta.md",
    "---\ntitle: Beta\ndate: 2026-02-03\ntags:\n  - true-crime\n  - falsehood\n---\nBeta body.\n",
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
    for slug in ["true-crime", "falsehood"] {
      let html = @fs.read_file_to_string(
        config.output_dir + "/tags/" + slug + "/index.html",
      )
      assert_true(html.contains("<a href=\"/posts/alpha/\">Alpha</a>"))
      assert_true(html.contains("<a href=\"/posts/beta/\">Beta</a>"))
    }
  }
}
