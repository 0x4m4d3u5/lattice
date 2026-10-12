///|
test "event pages reject impossible calendar dates and malformed offsets before publication" {
  let config = publication_fixture("event_datetime")
  @fs.write_string_to_file(
    config.collections_path.unwrap(),
    "[posts]\nschema = title:String,date:Date,starts_at:Optional[DateTime]\ndir = " +
    config.content_dir +
    "/posts\n",
  )
  @fs.write_string_to_file(
    config.site.templates_dir.unwrap() + "/page.html",
    "<html><body>{{title}}{{?page.starts_at}}<time>{{page.starts_at}}</time>{{/?page.starts_at}}{{content}}</body></html>\n",
  )
  let alpha = config.content_dir + "/posts/alpha.md"
  @fs.write_string_to_file(
    alpha, "---\ntitle: Leap Day Workshop\ndate: 2026-01-02\nstarts_at: 2028-02-29T10:30:00+05:30\n---\nBook the workshop.\n",
  )
  assert_eq(@builder.check(config).violations.length(), 0)
  publication_seed_success(config)
  let html = @fs.read_file_to_string(
    config.output_dir + "/posts/alpha/index.html",
  )
  assert_true(html.contains("<time>2028-02-29T10:30:00+05:30</time>"))
  let before = publication_snapshot(config.output_dir)
  let incremental = publication_incremental(config)
  assert_eq(
    @builder.build(incremental, publication_load_cache(config)).unchanged_pages,
    2,
  )
  for invalid in ["2026-02-30T10:30:00Z", "2028-02-29T10:30:00+/0:00"] {
    @fs.write_string_to_file(
      alpha,
      "---\ntitle: Broken Workshop\ndate: 2026-01-02\nstarts_at: " +
      invalid +
      "\n---\nChanged workshop.\n",
    )
    let failed = @builder.build(incremental, publication_load_cache(config))
    assert_eq(failed.errors, 1)
    let errors = failed.diagnostics.filter(fn(d) {
      d.severity == @diagnostic.Error
    })
    assert_eq(errors.length(), 1)
    assert_eq(errors[0].path, Some(alpha))
    assert_eq(
      errors[0].message,
      "schema: starts_at: expected ISO 8601 datetime (YYYY-MM-DDTHH:MM:SS[Z|+HH:MM]), got: \"" +
      invalid +
      "\"",
    )
    assert_eq(@builder.check(config).violations.length(), 1)
    assert_eq(publication_snapshot(config.output_dir), before)
  }
}
