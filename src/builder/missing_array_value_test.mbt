///|
test "missing tag values cannot pass the publication schema" {
  let config = publication_fixture("missing_array_values")
  @fs.write_string_to_file(
    config.collections_path.unwrap(),
    "[posts]\nschema = title:String,date:Date,tags:Array[String]\ndir = " +
    config.content_dir +
    "/posts\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\ntags: [\"research\",,\"wiki\"]\n---\nAlpha body.\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/beta.md",
    "+++\ntitle = \"Beta\"\ndate = 2026-02-03\ntags = [,\"wiki\"]\n+++\nBeta body.\n",
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
    assert_true(result.errors >= 2)
    assert_false(@fs.path_exists(config.output_dir + "/posts/alpha/index.html"))
    assert_false(@fs.path_exists(config.output_dir + "/posts/beta/index.html"))
  }
}
