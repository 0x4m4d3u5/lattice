///|
test "quoted HTML attributes do not create false broken wiki links" {
  let config = publication_fixture("html_attribute")
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\n---\nBefore <span title=\"1 > [[missing]]\">after</span> [[beta|Guide]].\n",
  )
  assert_eq(@builder.check(config).violations.length(), 0)
  let built = @builder.build(config, @cache.empty(config.output_dir))
  assert_eq(built.errors, 0)
  assert_eq(built.diagnostics.length(), 0)
  let html = @fs.read_file_to_string(
    config.output_dir + "/posts/alpha/index.html",
  )
  assert_true(
    html.contains(
      "Before <span title=\"1 > [[missing]]\">after</span> <a href=\"/posts/beta/\">Guide</a>.",
    ),
  )
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
