///|
test "quoted link and image destinations publish without extra attributes" {
  let config = publication_fixture("destination_quote")
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\n---\n[x](/doc\"data-probe=\"yes?x=%22&plus=a+b#frag)\n\n![Chart](/img.png\\\"data-probe=\\\"yes?x=%2F&plus=a+b#frag)\n",
  )
  assert_eq(@builder.check(config).violations.length(), 0)
  let built = @builder.build(config, @cache.empty(config.output_dir))
  assert_eq(built.errors, 0)
  let html = @fs.read_file_to_string(
    config.output_dir + "/posts/alpha/index.html",
  )
  assert_true(
    html.contains(
      "<a href=\"/doc%22data-probe=%22yes?x=%22&amp;plus=a+b#frag\">x</a>",
    ),
  )
  assert_true(
    html.contains(
      "<img src=\"/img.png%22data-probe=%22yes?x=%2F&amp;plus=a+b#frag\" alt=\"Chart\" />",
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
