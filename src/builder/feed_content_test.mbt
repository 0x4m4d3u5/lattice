///|
test "JSON feeds carry rendered item bodies on cold and cached builds" {
  let config = publication_fixture("json_feed_content")
  @fs.write_string_to_file(
    config.content_dir + "/../collections.cfg",
    "[posts]\nschema = title:String,date:Date,description:Optional[String]\ndir = " +
    config.content_dir +
    "/posts\n",
  )
  let body = "# Authored heading\n\nA **bold** body with \"quotes\", a \\ path and café.\n\n[[beta]]\n\nFinal paragraph beyond the summary.\n"
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\ndescription: Brief summary\n---\n" +
    body,
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/draft.md",
    "---\ntitle: Draft\ndate: 2026-03-04\ndraft: true\n---\nDRAFT BODY SENTINEL\n",
  )
  let expected = @markdown.render(body, Map([("beta", "/posts/beta/")]))
  for pass in 0..<2 {
    let build_config = if pass == 0 {
      config
    } else {
      publication_incremental(config)
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
    for relative in ["posts/feed.json", "feed.json"] {
      let text = @fs.read_file_to_string(config.output_dir + "/" + relative)
      assert_true(!text.contains("DRAFT BODY SENTINEL"))
      let feed = @json.parse(text)
      guard feed is Object(fields) else { abort("feed must be an object") }
      assert_eq(
        fields.get("version"),
        Some(Json::string("https://jsonfeed.org/version/1.1")),
      )
      guard fields.get("items") is Some(Array(items)) else {
        abort("items must be an array")
      }
      assert_eq(items.length(), 2)
      for item in items {
        guard item is Object(entry) else { abort("item must be an object") }
        guard entry.get("content_html") is Some(String(html)) else {
          abort("JSON Feed item lacks required content_html")
        }
        match entry.get("title") {
          Some(String("Alpha")) => {
            assert_eq(html, expected)
            assert_eq(entry.get("summary"), Some(Json::string("Brief summary")))
            assert_eq(
              entry.get("url"),
              Some(Json::string("https://example.test/posts/alpha/")),
            )
          }
          Some(String("Beta")) => assert_eq(html, "<p>Original beta.</p>\n")
          _ => abort("unexpected feed item")
        }
      }
    }
  }
}
