///|
test "fresh output prepares all pages ignores cache and omits metadata" {
  let config = publication_incremental(publication_fixture("fresh_success"))
  let old = { ..config, output_dir: config.output_dir + "-old", }
  assert_eq(@builder.build(old, @cache.empty(old.output_dir)).errors, 0)
  let old_snapshot = publication_snapshot(old.output_dir)
  let cache = publication_load_cache(old)
  let before = publication_snapshot(config.content_dir)
  let preview = @builder.inventory(config, fresh_output=true)
  assert_true(preview.ready)
  assert_false(@fs.path_exists(config.output_dir))
  assert_false(preview.entries.any(entry => entry.kind == "build_metadata"))
  let result = @builder.build(config, cache, fresh_output=true)
  assert_eq(result.errors, 0)
  assert_true(result.rebuilt_pages > 0)
  assert_eq(result.unchanged_pages, 0)
  assert_false(@fs.path_exists(config.output_dir + "/.lattice-cache"))
  assert_false(@fs.path_exists(config.output_dir + "/.lattice-manifest.json"))
  assert_true(@fs.path_exists(config.output_dir + "/index.html"))
  assert_true(@fs.path_exists(config.output_dir + "/style.css"))
  assert_eq(publication_snapshot(config.content_dir), before)
  assert_eq(publication_snapshot(old.output_dir), old_snapshot)
  let files = publication_snapshot(config.output_dir).filter(entry => {
    entry.bytes != None
  })
  let planned = preview.entries.filter(entry => entry.status == "planned")
  assert_eq(files.length(), planned.length())
  for file in files {
    assert_true(planned.any(entry => entry.path == file.path))
  }
}

///|
test "fresh output refuses populated empty and file destinations unchanged" {
  for kind in ["populated", "empty", "file"] {
    let config = publication_fixture("fresh_existing_" + kind)
    if kind == "populated" {
      assert_eq(
        @builder.build(config, @cache.empty(config.output_dir)).errors,
        0,
      )
    } else if kind == "empty" {
      @fs.create_dir(config.output_dir)
    } else {
      @fs.write_string_to_file(config.output_dir, "untouched")
    }
    let before = publication_snapshot(config.output_dir)
    let result = @builder.build(
      config,
      @cache.empty(config.output_dir),
      fresh_output=true,
    )
    assert_true(result.errors > 0)
    assert_true(
      result.diagnostics.any(diag => diag.message.contains("already exists")),
    )
    assert_false(@builder.inventory(config, fresh_output=true).ready)
    assert_eq(publication_snapshot(config.output_dir), before)
  }
}

///|
test "fresh output rejects lexical overlap including external collection roots" {
  let base = publication_fixture("fresh_overlap")
  let root = @path.Path(base.output_dir).dirname().to_string()
  for
    destination in [
      base.content_dir + "/new-output",
      base.content_dir + "/posts/../new-output",
      root + "/templates/new-output",
      base.config_path + "/new-output",
      root,
    ] {
    let config = { ..base, output_dir: destination, }
    assert_true(
      @builder.build(config, @cache.empty(destination), fresh_output=true).errors >
      0,
    )
    assert_false(@builder.inventory(config, fresh_output=true).ready)
  }
  let external = root + "/external"
  @fs.create_dir(external)
  @fs.write_string_to_file(
    root + "/collections.cfg",
    "[posts]\nschema = title:String,date:Date\ndir = " + external + "\n",
  )
  let config = { ..base, output_dir: external + "/new-output", }
  assert_false(@builder.inventory(config, fresh_output=true).ready)
  assert_false(@fs.path_exists(config.output_dir))
  // A sibling with the same string prefix is not containment.
  assert_true(
    @builder.inventory(
      { ..base, output_dir: external + "-published", },
      fresh_output=true,
    ).ready,
  )
}

///|
test "fresh preparation failure does not create target or affect old publication" {
  let config = publication_fixture("fresh_failure")
  assert_eq(@builder.build(config, @cache.empty(config.output_dir)).errors, 0)
  let before = publication_snapshot(config.output_dir)
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: invalid\n---\nInvalid.\n",
  )
  let fresh = { ..config, output_dir: config.output_dir + "-new", }
  assert_true(
    @builder.build(fresh, @cache.empty(fresh.output_dir), fresh_output=true).errors >
    0,
  )
  assert_false(@fs.path_exists(fresh.output_dir))
  assert_eq(publication_snapshot(config.output_dir), before)
}
