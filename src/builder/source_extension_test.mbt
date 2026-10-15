///|
test "Markdown extension case does not hide source notes" {
  let config = publication_fixture("source_extension")
  @fs.write_string_to_file(
    config.content_dir + "/posts/Guide.MD",
    "---\ntitle: Guide\ndate: 2026-01-03\n---\nCollection note.\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/standalone/Profile.mD",
    "---\ntitle: Profile\n---\nStandalone note.\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/Start.Md",
    "---\ntitle: Start\n---\nRoot note.\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/README.MD",
    "Reserved root file without frontmatter.\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/ignored.MDX",
    "Not a Markdown source.\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\n---\nRead [[Guide.MD|Guide]], [[Profile.MD|Profile]], and [[Start.md|Start]].\n",
  )
  let sources = @builder.collect_sources(config.content_dir + "/posts")
  assert_eq(sources.length(), 3)
  assert_true(sources.any(s => s.filename == "Guide.MD" && s.slug == "guide"))
  assert_eq(@builder.check(config).violations.length(), 0)
  let built = @builder.build(config, @cache.empty(config.output_dir))
  assert_eq(built.errors, 0)
  assert_eq(built.diagnostics.length(), 0)
  for
    (url, text) in [
      ("/posts/guide/", "Collection note."),
      ("/profile/", "Standalone note."),
      ("/start/", "Root note."),
    ] {
    assert_true(
      @fs.read_file_to_string(config.output_dir + url + "index.html").contains(
        text,
      ),
    )
  }
  let alpha = @fs.read_file_to_string(
    config.output_dir + "/posts/alpha/index.html",
  )
  assert_true(alpha.contains("<a href=\"/posts/guide/\">Guide</a>"))
  assert_true(alpha.contains("<a href=\"/profile/\">Profile</a>"))
  assert_true(alpha.contains("<a href=\"/start/\">Start</a>"))
  assert_false(@fs.path_exists(config.output_dir + "/readme/index.html"))
  let before = publication_snapshot(config.output_dir)
  let cached = @builder.build(
    publication_incremental(config),
    publication_load_cache(config),
  )
  assert_eq(cached.errors, 0)
  assert_true(cached.unchanged_pages >= 3)
  assert_eq(publication_snapshot(config.output_dir), before)
  let forced = @builder.build(config, publication_load_cache(config))
  assert_eq(forced.errors, 0)
  assert_eq(publication_snapshot(config.output_dir), before)
}

///|
test "mixed-case extensions still enforce canonical slug collisions" {
  let config = publication_fixture("source_extension_collision")
  @fs.write_string_to_file(
    config.content_dir + "/posts/case-test.md",
    "---\ntitle: Original\ndate: 2026-01-03\n---\nOriginal note.\n",
  )
  publication_seed_success(config)
  let before = publication_snapshot(config.output_dir)
  @fs.write_string_to_file(
    config.content_dir + "/posts/case_test.MD",
    "---\ntitle: Duplicate\ndate: 2026-01-03\n---\nDuplicate note.\n",
  )
  let checked = @builder.check(config)
  assert_true(checked.violations.any(v => v.kind == @lint.DuplicateSlug))
  let failed = @builder.build(
    publication_incremental(config),
    publication_load_cache(config),
  )
  assert_true(failed.errors > 0)
  assert_eq(publication_snapshot(config.output_dir), before)
}
