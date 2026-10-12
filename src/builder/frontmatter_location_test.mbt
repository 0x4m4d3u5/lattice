///|
test "schema diagnostics locate active YAML and TOML fields rather than examples" {
  for (name, source, expected_line) in [
    ("yaml", "---\n# priority = 4\ntitle: Alpha\ndate: 2026-01-02\nnote: priority = 4\npriority: 0\n---\nExample: priority = 3\n", 6),
    ("toml", "+++\n# priority = 4\ntitle = Alpha\ndate = 2026-01-02\nnote = \"priority = 4\"\npriority\t=0\n+++\nExample: priority = 3\n", 6),
    ("duplicate", "+++\ntitle = Alpha\ndate = 2026-01-02\npriority = 3\n# priority = 4\npriority = 0\n+++\n", 6),
    ("crlf", "---\r\n# priority = 4\r\ntitle: Alpha\r\ndate: 2026-01-02\r\nnote: example\r\n  priority:0\r\n---\r\n", 6),
  ] {
    let config = publication_fixture("field_location_" + name)
    @fs.write_string_to_file(config.collections_path.unwrap(),
      "[posts]\nschema = title:String,date:Date,priority:Optional[Int(min=1,max=5)],note:Optional[String]\ndir = " + config.content_dir + "/posts\n")
    publication_seed_success(config)
    let before = publication_snapshot(config.output_dir)
    let path = config.content_dir + "/posts/alpha.md"
    @fs.write_string_to_file(path, source)
    let checked = @builder.check(config)
    assert_eq(checked.violations.length(), 1)
    assert_eq(checked.violations[0].path, path)
    assert_eq(checked.violations[0].line, Some(expected_line))
    assert_eq(checked.violations[0].message, "priority: expected Int in range [1, 5], got: 0")
    let result = @builder.build(publication_incremental(config), publication_load_cache(config))
    assert_eq(result.errors, 1)
    let errors = result.diagnostics.filter(fn(d) { d.severity == @diagnostic.Error })
    assert_eq(errors.length(), 1)
    assert_eq(errors[0].line, Some(expected_line))
    assert_eq(publication_snapshot(config.output_dir), before)
  }
}

///|
test "missing required fields do not borrow locations from Markdown examples" {
  let config = publication_fixture("missing_field_location")
  let path = config.content_dir + "/posts/alpha.md"
  @fs.write_string_to_file(path, "---\ntitle: Alpha\n---\n\n```toml\ndate = 2026-01-02\n```\n")
  let checked = @builder.check(config)
  assert_eq(checked.violations.length(), 1)
  assert_eq(checked.violations[0].line, None)
  let result = @builder.build(config, @cache.empty(config.output_dir))
  let errors = result.diagnostics.filter(fn(d) { d.severity == @diagnostic.Error })
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].line, None)
  assert_false(@fs.path_exists(config.output_dir))
}

///|
test "frontmatter parse diagnostics use document lines including the opening fence" {
  for (name, source, expected_message) in [
    ("yaml", "---\ntitle: Alpha\nmissing separator\n---\nBody.\n", "line 3: missing ':' separator in frontmatter line"),
    ("toml", "+++\ntitle = Alpha\nmissing separator\n+++\nBody.\n", "line 3: no '=' found in line"),
  ] {
    let config = publication_fixture("parse_location_" + name)
    let path = config.content_dir + "/posts/alpha.md"
    @fs.write_string_to_file(path, source)
    let checked = @builder.check(config)
    assert_eq(checked.violations.length(), 1)
    assert_eq(checked.violations[0].path, path)
    assert_eq(checked.violations[0].line, Some(3))
    assert_eq(checked.violations[0].message, expected_message)
    let result = @builder.build(config, @cache.empty(config.output_dir))
    let errors = result.diagnostics.filter(fn(d) { d.severity == @diagnostic.Error })
    assert_eq(errors.length(), 1)
    assert_eq(errors[0].line, Some(3))
    assert_eq(errors[0].message, "frontmatter: " + expected_message)
    assert_false(@fs.path_exists(config.output_dir))
  }
}
