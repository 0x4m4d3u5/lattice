///|
test "layout cycle diagnostics preserve published workshop output and recover" {
  let config = publication_fixture("layout_cycle")
  let templates = config.site.templates_dir.unwrap()
  @fs.write_string_to_file(
    templates + "/page.html",
    "{{layout: base.html}}<article>{{content}}</article>",
  )
  let base = templates + "/base.html"
  let valid = "<html><body>{{body}}</body></html>"
  @fs.write_string_to_file(base, valid)
  @fs.write_string_to_file(
    templates + "/shell.html",
    "{{layout: base.html}}<html>{{body}}</html>",
  )
  assert_eq(@builder.check(config).violations.length(), 0)
  assert_true(!@fs.path_exists(config.output_dir))
  assert_eq(@builder.build(config, @cache.empty(config.output_dir)).errors, 0)
  let output = config.output_dir + "/posts/alpha/index.html"
  let expected = "<html><body><article><p>Original alpha.</p>\n</article></body></html>"
  assert_eq(@fs.read_file_to_string(output), expected)
  let snapshot = publication_snapshot(config.output_dir)
  for mutual in [false, true] {
    @fs.write_string_to_file(
      base,
      if mutual {
        "{{layout: shell.html}}<main>{{body}}</main>"
      } else {
        "{{layout: base.html}}<main>{{body}}</main>"
      },
    )
    let checked = @builder.check(config)
    assert_true(
      checked.violations.any(fn(v) {
        v.kind == @lint.TemplateSlotError &&
        v.message.contains("layout cycle detected: base.html")
      }),
    )
    assert_eq(publication_snapshot(config.output_dir), snapshot)
    assert_true(
      @builder.build(
        publication_incremental(config),
        publication_load_cache(config),
      ).errors >
      0,
    )
    assert_eq(publication_snapshot(config.output_dir), snapshot)
  }
  @fs.write_string_to_file(base, valid)
  assert_eq(@builder.check(config).violations.length(), 0)
  assert_eq(publication_snapshot(config.output_dir), snapshot)
  let recovered = @builder.build(
    publication_incremental(config),
    publication_load_cache(config),
  )
  assert_eq(recovered.errors, 0)
  assert_eq(recovered.unchanged_pages, 2)
  assert_eq(@fs.read_file_to_string(output), expected)
  assert_eq(publication_snapshot(config.output_dir), snapshot)
}
