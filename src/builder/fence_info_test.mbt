///|
test "invalid fence info keeps published links and search excerpts visible" {
  let config = publication_fixture("fence_info")
  let body = "```bad`info\n[[beta|Guide]]\n\nVisible paragraph.\n"
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\n---\n" + body,
  )
  assert_eq(@builder.count_words_markdown(body), 4)
  assert_eq(@builder.check(config).violations.length(), 0)
  let built = @builder.build(config, @cache.empty(config.output_dir))
  assert_eq(built.errors, 0)
  let html = @fs.read_file_to_string(
    config.output_dir + "/posts/alpha/index.html",
  )
  assert_true(
    html.contains(
      "<p>```bad`info <a href=\"/posts/beta/\">Guide</a></p>\n<p>Visible paragraph.</p>",
    ),
  )
  let search = @json.parse(
    @fs.read_file_to_string(config.output_dir + "/search-index.json"),
  )
  guard search is Array(entries) else { abort("search index must be an array") }
  let alpha = entries.filter(fn(entry) {
    match entry {
      Object(fields) => fields.get("url") == Some(Json::string("/posts/alpha/"))
      _ => false
    }
  })
  assert_eq(alpha.length(), 1)
  guard alpha[0] is Object(fields) else { abort("entry must be an object") }
  assert_eq(fields.get("excerpt"), Some(Json::string("```bad`info Guide")))
  let before = publication_snapshot(config.output_dir)
  let cached = @builder.build(
    publication_incremental(config),
    publication_load_cache(config),
  )
  assert_eq(cached.errors, 0)
  assert_true(cached.unchanged_pages >= 2)
  assert_eq(publication_snapshot(config.output_dir), before)
  let forced = @builder.build(config, publication_load_cache(config))
  assert_eq(forced.errors, 0)
  assert_eq(publication_snapshot(config.output_dir), before)
}

///|
test "invalid fence info cannot hide broken wikilinks from check" {
  let config = publication_fixture("fence_info_missing")
  let path = config.content_dir + "/posts/alpha.md"
  @fs.write_string_to_file(
    path, "---\ntitle: Alpha\ndate: 2026-01-02\n---\n```bad`info\n[[missing]]\n",
  )
  let checked = @builder.check(config)
  assert_eq(checked.violations.length(), 1)
  assert_eq(checked.violations[0].path, path)
  assert_eq(checked.violations[0].kind, @lint.BrokenWikilink)
  assert_eq(
    checked.violations[0].message,
    "[[missing]]: target 'missing' not found in page index",
  )
}
