///|
test "publishing retains parentheses in reference and image destinations" {
  let config = publication_fixture("link_destination")
  let body = "See [AI](https://en.wikipedia.org/wiki/Artificial_intelligence_(disambiguation)).\n\n![Chart](/figures/loss_(train).png)\n"
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\n---\n" + body,
  )
  let built = @builder.build(config, @cache.empty(config.output_dir))
  assert_eq(built.errors, 0)
  assert_eq(@builder.check(config).violations.length(), 0)
  let html = @fs.read_file_to_string(
    config.output_dir + "/posts/alpha/index.html",
  )
  assert_true(
    html.contains(
      "<a href=\"https://en.wikipedia.org/wiki/Artificial_intelligence_(disambiguation)\">AI</a>.",
    ),
  )
  assert_true(
    html.contains("<img src=\"/figures/loss_(train).png\" alt=\"Chart\" />"),
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
