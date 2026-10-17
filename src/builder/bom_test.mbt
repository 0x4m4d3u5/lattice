///|
test "BOM-prefixed YAML and TOML notes publish across rebuilds" {
  let config = publication_fixture("bom_notes")
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "\ufeff---\ntitle: Alpha\ndate: 2026-01-02\n---\nAlpha body.\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/beta.md",
    "\ufeff+++\ntitle = \"Beta\"\ndate = 2026-02-03\n+++\nBeta body.\n",
  )
  for pass in 0..<3 {
    let build_config = if pass == 1 {
      publication_incremental(config)
    } else {
      config
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
    for (slug, body) in [("alpha", "Alpha body."), ("beta", "Beta body.")] {
      let html = @fs.read_file_to_string(
        config.output_dir + "/posts/" + slug + "/index.html",
      )
      assert_true(html.contains("<p>" + body + "</p>"))
    }
  }
}

///|
test "BOM-prefixed metadata retains schema error locations" {
  for
    (name, source) in [
      ("yaml", "\ufeff---\ntitle: Alpha\ndate: not-a-date\n---\nBody.\n"),
      (
        "toml", "\ufeff+++\ntitle = \"Alpha\"\ndate = \"not-a-date\"\n+++\nBody.\n",
      ),
    ] {
    let config = publication_fixture("bom_diagnostic_" + name)
    @fs.write_string_to_file(config.content_dir + "/posts/alpha.md", source)
    let checked = @builder.check(config)
    assert_eq(checked.violations.length(), 1)
    assert_eq(checked.violations[0].line, Some(3))
    let result = @builder.build(config, @cache.empty(config.output_dir))
    assert_eq(result.errors, 1)
    let errors = result.diagnostics.filter(fn(d) {
      d.severity == @diagnostic.Error
    })
    assert_eq(errors.length(), 1)
    assert_eq(errors[0].line, Some(3))
    assert_false(@fs.path_exists(config.output_dir))
  }
}
