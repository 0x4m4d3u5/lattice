///|
// A reading guide groups related posts into sections. The collection schema and
// nested frontmatter are authored text, so this exercises both parsers as well
// as strict checking, publication, and reuse of an existing cache.
test "grouped reading references reject missing and wrong-collection targets before publication" {
  let config = publication_fixture("grouped_reading_refs")
  @fs.write_string_to_file(
    config.collections_path.unwrap(),
    "[posts]\nschema = title:String,date:Date,reading:Optional[Array[Array[Ref[posts]]]]\ndir = " +
    config.content_dir +
    "/posts\n",
  )
  let alpha = config.content_dir + "/posts/alpha.md"
  let valid = "---\ntitle: Alpha\ndate: 2026-01-02\nreading: [[beta], [], [alpha, beta]]\n---\nRead [[beta|the next chapter]].\n"
  @fs.write_string_to_file(alpha, valid)
  assert_eq(@builder.check(config).violations.length(), 0)
  publication_seed_success(config)
  assert_true(
    @fs.read_file_to_string(config.output_dir + "/posts/alpha/index.html").contains(
      "<a href=\"/posts/beta/\">the next chapter</a>",
    ),
  )
  let before = publication_snapshot(config.output_dir)
  let incremental = publication_incremental(config)
  assert_eq(
    @builder.build(incremental, publication_load_cache(config)).unchanged_pages,
    2,
  )
  @fs.write_string_to_file(
    alpha, "---\ntitle: Alpha\ndate: 2026-01-02\nreading: [[beta], [], [missing, about]]\n---\nChanged guide.\n",
  )
  let checked = @builder.check(config)
  assert_eq(checked.violations.length(), 2)
  let failed = @builder.build(incremental, publication_load_cache(config))
  assert_true(failed.errors > 0)
  let messages = failed.diagnostics
    .filter(fn(d) { d.severity == @diagnostic.Error })
    .map(fn(d) { d.message })
  assert_true(
    messages.contains(
      "schema: reading: TRef: reading[2][0]: unknown slug 'missing'",
    ),
  )
  assert_true(
    messages.contains(
      "schema: reading: TRef: reading[2][1]: references slug 'about' from collection '_standalone' but expected 'posts'",
    ),
  )
  assert_eq(publication_snapshot(config.output_dir), before)
  // An unchanged guide must be revalidated after its referenced page is deleted.
  @fs.write_string_to_file(alpha, valid)
  @fs.remove_file(config.content_dir + "/posts/beta.md")
  let deleted = @builder.build(incremental, publication_load_cache(config))
  assert_true(deleted.errors > 0)
  let deleted_messages = deleted.diagnostics
    .filter(fn(d) { d.severity == @diagnostic.Error })
    .map(fn(d) { d.message })
  assert_eq(deleted_messages.length(), 2)
  assert_true(deleted_messages.contains("schema: reading: TRef: reading[0][0]: unknown slug 'beta'"))
  assert_true(deleted_messages.contains("schema: reading: TRef: reading[2][1]: unknown slug 'beta'"))
  assert_eq(publication_snapshot(config.output_dir), before)
}
