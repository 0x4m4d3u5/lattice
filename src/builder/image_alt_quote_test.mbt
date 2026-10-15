///|
test "published image descriptions retain double quotes" {
  let config = image_alt_policy(publication_fixture("image_alt_quote"))
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\n---\n![He said \"hello\" & waved](/plot.png)\n",
  )
  assert_eq(@builder.check(config).violations.length(), 0)
  let built = @builder.build(config, @cache.empty(config.output_dir))
  assert_eq(built.errors, 0)
  let html = @fs.read_file_to_string(
    config.output_dir + "/posts/alpha/index.html",
  )
  assert_true(
    html.contains(
      "<img src=\"/plot.png\" alt=\"He said &quot;hello&quot; &amp; waved\" />",
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
  let forced = @builder.build(
    { ..config, force_rebuild: true, },
    publication_load_cache(config),
  )
  assert_eq(forced.errors, 0)
  assert_eq(publication_snapshot(config.output_dir), before)
}
