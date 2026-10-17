///|
test "capitalized YAML boolean metadata publishes across rebuilds" {
  let config = publication_fixture("yaml_boolean_case")
  @fs.write_string_to_file(
    config.collections_path.unwrap(),
    "[posts]\nschema = title:String,date:Date,featured:Optional[Bool]\ndir = " +
    config.content_dir +
    "/posts\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\nfeatured: True\n---\nAlpha body.\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/beta.md",
    "---\ntitle: Beta\ndate: 2026-02-03\nfeatured: FALSE\n---\nBeta body.\n",
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
    for (slug, body) in [("alpha", "Alpha body."), ("beta", "Beta body.")] {
      let html = @fs.read_file_to_string(
        config.output_dir + "/posts/" + slug + "/index.html",
      )
      assert_true(html.contains("<p>" + body + "</p>"))
    }
  }
}
