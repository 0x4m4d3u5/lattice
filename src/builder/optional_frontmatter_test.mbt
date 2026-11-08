///|
test "effective ingestion policy invalidates incremental state without config file edits" {
  let base = publication_fixture("optional_frontmatter_policy_cache")
  let source_config = @fs.read_file_to_string(base.config_path)
  let optional = {
    ..publication_incremental(base),
    site: @config.parse(source_config + "allow_missing_frontmatter=true\n").unwrap(),
  }
  let strict = publication_incremental(base)
  assert_eq(@builder.build(strict, @cache.empty(strict.output_dir)).errors, 0)
  for config in [optional, strict, optional] {
    let result = @builder.build(config, publication_load_cache(config))
    assert_eq(result.errors, 0)
    assert_true(result.rebuilt_pages > 0)
    assert_eq(result.unchanged_pages, 0)
    assert_eq(@fs.read_file_to_string(config.config_path), source_config)
  }
  let unchanged = @builder.build(optional, publication_load_cache(optional))
  assert_eq(unchanged.errors, 0)
  assert_true(unchanged.unchanged_pages > 0)
}
