///|
test "article footnote shortcode errors reject cached edits without publication" {
  let config = publication_fixture("footnote_shortcode_edit")
  let header = "---\ntitle: Research Notes\ndate: 2026-01-02\n---\n"
  let valid = header +
    "Evidence[^source].\n\n[^source]: {{< image src=\"/chart.png\" alt=\"Data chart\" >}}\n"
  let path = config.content_dir + "/posts/alpha.md"
  @fs.write_string_to_file(path, valid)
  publication_seed_success(config)
  let initial_html = @fs.read_file_to_string(
    config.output_dir + "/posts/alpha/index.html",
  )
  assert_true(
    initial_html.contains(
      "<li id=\"fn-source\"><img src=\"/chart.png\" alt=\"Data chart\" />",
    ),
  )
  let cached = @builder.build(
    publication_incremental(config),
    publication_load_cache(config),
  )
  assert_eq(cached.errors, 0)
  assert_eq(cached.unchanged_pages, 2)
  let before = publication_snapshot(config.output_dir)
  @fs.write_string_to_file(
    path,
    header +
    "Evidence[^source].\n\n[^source]: {{< image src=\"/chart.png\" >}}\n",
  )
  let checked = @builder.check(config)
  assert_eq(checked.violations.length(), 1)
  assert_eq(checked.violations[0].path, path)
  assert_eq(checked.violations[0].kind, @lint.ShortcodeError)
  assert_eq(
    checked.violations[0].message,
    "shortcode 'image' missing param 'alt'",
  )
  assert_eq(
    @diagnostic.of_lint_violation(checked.violations[0]).code,
    Some("E008"),
  )
  assert_eq(publication_snapshot(config.output_dir), before)
  let failed = @builder.build(
    publication_incremental(config),
    publication_load_cache(config),
  )
  assert_eq(failed.errors, 1)
  assert_true(
    failed.diagnostics.any(fn(d) {
      d.severity == @diagnostic.Error &&
      d.message == "shortcode: shortcode 'image' missing param 'alt'"
    }),
  )
  assert_eq(publication_snapshot(config.output_dir), before)
  @fs.write_string_to_file(path, valid)
  let recovered = @builder.build(
    publication_incremental(config),
    publication_load_cache(config),
  )
  assert_eq(recovered.errors, 0)
  assert_eq(
    @fs.read_file_to_string(config.output_dir + "/posts/alpha/index.html"),
    initial_html,
  )
}

///|
test "invalid rendered footnotes prevent first publication across page kinds" {
  for
    location in [
      "/posts/alpha.md", "/standalone/about.md", "/index.md", "/404.md",
    ] {
    let config = publication_fixture("footnote_shortcode_first")
    let path = config.content_dir + location
    @fs.write_string_to_file(
      path, "---\ntitle: Reference\ndate: 2026-01-02\n---\nText.\n\n[^unused]: {{< unknown_note >}}\n",
    )
    // Definitions are rendered even without a reference, so their errors
    // participate in the same preparation gate as the main body.
    let result = @builder.build(config, @cache.empty(config.output_dir))
    assert_eq(result.errors, 1)
    assert_true(
      result.diagnostics.any(fn(d) {
        d.severity == @diagnostic.Error &&
        d.message.contains("unknown shortcode 'unknown_note'")
      }),
    )
    assert_false(@fs.path_exists(config.output_dir))
  }
}
