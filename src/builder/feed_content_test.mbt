///|
test "JSON feeds carry rendered item bodies on cold and cached builds" {
  let config = publication_fixture("json_feed_content")
  @fs.write_string_to_file(
    config.content_dir + "/../collections.cfg",
    "[posts]\nschema = title:String,date:Date,description:Optional[String]\ndir = " +
    config.content_dir +
    "/posts\n",
  )
  let body = "# Authored heading\n\nA **bold** body with \"quotes\", a `C:\\path` and café.\n\n[[beta]]\n\nFinal paragraph beyond the summary.\n"
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\ndescription: Brief summary\n---\n" +
    body,
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/draft.md",
    "---\ntitle: Draft\ndate: 2026-03-04\ndraft: true\n---\nDRAFT BODY SENTINEL\n",
  )
  // Authored fixture expectations are literal, independent of the renderer.
  let expected = "<h1 id=\"authored-heading\">Authored heading</h1>\n" +
    "<p>A <strong>bold</strong> body with \"quotes\", a <code>C:\\path</code> and café.</p>\n" +
    "<p><a href=\"/posts/beta/\">beta</a></p>\n" +
    "<p>Final paragraph beyond the summary.</p>\n"
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
      let ids : Map[String, Bool] = Map([])
      for item in items {
        guard item is Object(entry) else { abort("item must be an object") }
        guard entry.get("content_html") is Some(String(html)) else {
          abort("JSON Feed item lacks required content_html")
        }
        guard entry.get("id") is Some(String(id)) else {
          abort("item id must be a string")
        }
        assert_false(ids.contains(id))
        ids.set(id, true)
        match entry.get("title") {
          Some(String("Alpha")) => {
            assert_eq(id, "https://example.test/posts/alpha/")
            assert_eq(html, expected)
            assert_eq(entry.get("summary"), Some(Json::string("Brief summary")))
            assert_eq(
              entry.get("url"),
              Some(Json::string("https://example.test/posts/alpha/")),
            )
          }
          Some(String("Beta")) => {
            assert_eq(id, "https://example.test/posts/beta/")
            assert_eq(
              entry.get("url"),
              Some(Json::string("https://example.test/posts/beta/")),
            )
            assert_eq(html, "<p>Original beta.</p>\n")
          }
          _ => abort("unexpected feed item")
        }
      }
      assert_eq(ids.length(), 2)
      assert_true(ids.contains("https://example.test/posts/alpha/"))
      assert_true(ids.contains("https://example.test/posts/beta/"))
    }
  }
}
