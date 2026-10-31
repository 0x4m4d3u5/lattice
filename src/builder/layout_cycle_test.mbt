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
  let initial_stamp = @watch.file_stamp(base)
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
    let cycle_message = "invalid template " +
      templates +
      "/page.html: layout cycle detected: base.html"
    assert_eq(checked.violations.length(), 1)
    assert_eq(checked.violations[0].kind, @lint.TemplateSlotError)
    assert_eq(checked.violations[0].path, templates + "/page.html")
    assert_eq(checked.violations[0].message, cycle_message)
    assert_eq(
      @diagnostic.of_lint_violation(checked.violations[0]).code,
      Some("E006"),
    )
    assert_eq(publication_snapshot(config.output_dir), snapshot)
    let failed = @builder.build(
      publication_incremental(config),
      publication_load_cache(config),
    )
    assert_eq(failed.errors, 1)
    assert_eq(failed.diagnostics.length(), 1)
    assert_eq(failed.diagnostics[0].severity, @diagnostic.Error)
    assert_eq(failed.diagnostics[0].message, "templates: " + cycle_message)
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
  // JS stamps file contents; native stamps modification time. Restoring the
  // same bytes can legitimately trigger one dependency rebuild on native.
  assert_eq(recovered.unchanged_pages, if @watch.file_stamp(base) == initial_stamp { 2 } else { 0 })
  assert_eq(@fs.read_file_to_string(output), expected)
  let recovered_snapshot = publication_snapshot(config.output_dir)
  if @watch.file_stamp(base) == initial_stamp {
    assert_eq(recovered_snapshot, snapshot)
  }
  let warm = @builder.build(publication_incremental(config), publication_load_cache(config))
  assert_eq(warm.errors, 0)
  assert_eq(warm.unchanged_pages, 2)
  assert_eq(publication_snapshot(config.output_dir), recovered_snapshot)
}

///|
test "include cycle diagnostics keep their category in check and build" {
  let config = publication_fixture("include_cycle_diagnostic")
  let templates = config.site.templates_dir.unwrap()
  let page = templates + "/page.html"
  @fs.write_string_to_file(
    page, "{{include: badge.html}}<article>{{content}}</article>",
  )
  @fs.write_string_to_file(templates + "/badge.html", "{{include: badge.html}}")
  let cycle_message = "invalid template " +
    page +
    ": include cycle detected: badge.html"
  let checked = @builder.check(config)
  assert_eq(checked.violations.length(), 1)
  assert_eq(checked.violations[0].kind, @lint.TemplateSlotError)
  assert_eq(checked.violations[0].path, page)
  assert_eq(checked.violations[0].message, cycle_message)
  assert_eq(
    @diagnostic.of_lint_violation(checked.violations[0]).code,
    Some("E006"),
  )
  assert_false(@fs.path_exists(config.output_dir))
  let failed = @builder.build(config, @cache.empty(config.output_dir))
  assert_eq(failed.errors, 1)
  assert_eq(failed.diagnostics.length(), 1)
  assert_eq(failed.diagnostics[0].severity, @diagnostic.Error)
  assert_eq(failed.diagnostics[0].message, "templates: " + cycle_message)
  assert_false(@fs.path_exists(config.output_dir))
}
