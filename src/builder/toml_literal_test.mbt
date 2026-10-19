///|
test "TOML literal title and tags reach publication and search across rebuilds" {
  let config = publication_fixture("toml_literal_metadata")
  @fs.write_string_to_file(
    config.collections_path.unwrap(),
    "[posts]\nschema = title:String,date:Date,tags:Optional[Array[String]]\ndir = " +
    config.content_dir +
    "/posts\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "+++\ntitle = 'Research notes'\ndate = 2026-01-02\ntags = ['Research, notes [draft]',]\n+++\nAlpha body.\n",
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
    assert_true(html.contains("<title>Research notes | Publication Test</title>"))
    let index = @json.parse(
      @fs.read_file_to_string(config.output_dir + "/search-index.json"),
    )
    guard index is Array(entries) else { abort("expected a search array") }
    let mut found = false
    for entry in entries {
      guard entry is Object(fields) else { abort("expected a search object") }
      if fields.get("url") == Some(Json::string("/posts/alpha/")) {
        found = true
        assert_eq(fields.get("title"), Some(Json::string("Research notes")))
        guard fields.get("tags") is Some(Array(tags)) else {
          abort("expected search tags")
        }
        assert_eq(tags.length(), 1)
        assert_eq(tags[0], Json::string("Research, notes [draft]"))
      }
    }
    assert_true(found)
  }
}
