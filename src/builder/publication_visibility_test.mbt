///|
test "visibility guard rejects private sources before cached publication" {
  for relative in ["posts/alpha.md", "standalone/about.md", "index.md", "404.md"] {
    let config = publication_fixture("visibility_guard")
    publication_seed_success(config)
    let before = publication_snapshot(config.output_dir)
    let path = config.content_dir + "/" + relative
    @fs.write_string_to_file(path,
      "---\ntitle: Private\ndate: 2026-01-02\nvisibility: private\ndraft: true\n---\nPRIVATE_BODY_SENTINEL\n")
    for include_drafts in [false, true] {
      let config = { ..publication_incremental(config), include_drafts, }
      let result = @builder.build(config, publication_load_cache(config))
      assert_eq(result.errors, 1)
      assert_eq(result.rebuilt_pages, 0)
      assert_eq(result.unchanged_pages, 0)
      assert_eq(result.diagnostics[0].code, Some("E015"))
      assert_eq(result.diagnostics[0].path, Some(path))
      assert_eq(result.diagnostics[0].line, Some(4))
      assert_false(result.diagnostics[0].message.contains("PRIVATE_BODY_SENTINEL"))
      let checked = @builder.check(config)
      assert_eq(checked.violations.length(), 1)
      assert_eq(checked.violations[0].kind, @lint.PublicationVisibilityError)
      let inventory = @builder.inventory(config)
      assert_false(inventory.ready)
      assert_eq(inventory.entries.length(), 0)
      assert_eq(publication_snapshot(config.output_dir), before)
    }
  }
}

///|
test "visibility declaration is typed independently of collection schema" {
  let config = publication_fixture("visibility_types")
  let path = config.content_dir + "/posts/alpha.md"
  for value in ["true", "false", "0", "[public]", "PRIVATE", "\"\"", "private"] {
    @fs.write_string_to_file(path,
      "---\ntitle: Alpha\ndate: 2026-01-02\nvisibility: " + value + "\n---\nBody.\n")
    let result = @builder.build(config, @cache.empty(config.output_dir))
    assert_eq(result.errors, 1)
    assert_eq(result.diagnostics[0].code, Some("E015"))
    assert_false(@fs.path_exists(config.output_dir))
  }
  @fs.write_string_to_file(path,
    "---\ntitle: Alpha\ndate: 2026-01-02\nvisibility: public\n---\nBody.\n")
  let result = @builder.build(config, @cache.empty(config.output_dir))
  assert_eq(result.errors, 0)
}
