///|
test "private coverage reports uninspected children without importing their content" {
  let config = private_audience_fixture("coverage")
  for relative in ["posts/nested", "standalone/nested", "unknown", "curated", "curated/deeper", "data/notes"] {
    @fs.create_dir(config.content_dir + "/" + relative)
  }
  for relative in ["posts/nested", "standalone/nested", "unknown", "curated/deeper", "data/notes"] {
    // Deliberately malformed. Coverage must not read or validate these bodies.
    @fs.write_string_to_file(config.content_dir + "/" + relative + "/omitted.md", "---\nbroken metadata\nNESTED_BODY_CANARY")
  }
  let definitions = config.collections_path.unwrap()
  @fs.write_string_to_file(definitions, @fs.read_file_to_string(definitions) +
    "[curated]\ndir = " + config.content_dir + "/curated\nschema = title:String\n" +
    "[alias]\ndir = " + config.content_dir + "/curated/.\nschema = title:String\n")
  let before = publication_snapshot(config.content_dir)
  let inventory = @builder.inventory(config, fresh_output=true, audience=Some(@builder.Private))
  assert_true(inventory.ready)
  let warnings = inventory.diagnostics.filter(d => d.code == Some("private_source_coverage"))
  assert_eq(warnings.length(), 4)
  for relative in ["posts/nested", "standalone/nested", "unknown", "curated/deeper"] {
    assert_true(warnings.any(d => d.path.unwrap_or("").has_suffix("/content/" + relative)))
  }
  assert_true(warnings.all(d => d.severity == @diagnostic.Warning && d.message.contains("nested Markdown may be omitted")))
  let checked = @builder.check(config, audience=Some(@builder.Private))
  assert_eq(checked.violations.length(), 0)
  assert_eq(checked.messages.filter(m => m.contains("private source coverage")).length(), 4)
  let result = @builder.build(config, @cache.empty(config.output_dir), fresh_output=true, audience=Some(@builder.Private))
  assert_eq(result.errors, 0)
  assert_eq(result.diagnostics.filter(d => d.code == Some("private_source_coverage")).length(), 4)
  assert_false(@fs.read_file_to_string(config.output_dir + "/content-index.json").contains("NESTED_BODY_CANARY"))
  assert_eq(publication_snapshot(config.content_dir), before)
  for audience in [None, Some(@builder.Public)] {
    let config = { ..config, output_dir: config.output_dir + "-" + (if audience is None { "default" } else { "public" }) }
    let inventory = @builder.inventory(config, fresh_output=true, audience~)
    assert_true(inventory.ready)
    assert_false(inventory.diagnostics.any(d => d.code == Some("private_source_coverage")))
    assert_false(@builder.check(config, audience~).messages.any(m => m.contains("private source coverage")))
  }
}

///|
test "an explicitly configured data root still reports its uninspected children" {
  let config = private_audience_fixture("coverage_data")
  @fs.create_dir(config.content_dir + "/data/child")
  let definitions = config.collections_path.unwrap()
  @fs.write_string_to_file(definitions, @fs.read_file_to_string(definitions) +
    "[data_notes]\ndir = " + config.content_dir + "/data\nschema = title:String\n")
  let inventory = @builder.inventory(config, fresh_output=true, audience=Some(@builder.Private))
  assert_true(inventory.ready)
  let warnings = inventory.diagnostics.filter(d => d.code == Some("private_source_coverage"))
  assert_eq(warnings.length(), 1)
  assert_true(warnings[0].path.unwrap_or("").has_suffix("/content/data/child"))
}
