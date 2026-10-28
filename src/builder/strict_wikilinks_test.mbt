///|
test "strict wikilinks reject cached broken sources without output mutation" {
  let config = publication_fixture("strict_cached")
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\n---\nSee [[ missing | label ]].\n",
  )
  publication_seed_success(config)
  let before = publication_snapshot(config.output_dir)
  let result = @builder.build(
    publication_incremental(config), publication_load_cache(config),
    strict_wikilinks=true,
  )
  assert_eq(result.errors, 1)
  assert_eq(result.rebuilt_pages, 0)
  assert_eq(result.unchanged_pages, 0)
  assert_eq(result.redirect_count, 0)
  assert_eq(publication_snapshot(config.output_dir), before)
  let errors = result.diagnostics.filter(d => d.severity == @diagnostic.Error)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].code, Some("E004"))
  assert_eq(errors[0].line, Some(5))
  assert_eq(errors[0].column, Some(5))
  assert_false(result.messages.any(m => m.has_prefix("[build]")))
  assert_false(result.diagnostics.any(d => d.message.has_prefix("unresolved wikilink [[")))
}

///|
test "strict wikilinks check final template IDs and same-page fragments" {
  let config = publication_fixture("strict_final_ids")
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\n---\nSee [[beta#Template ID]] and [[#Local]].\n\n## Local\n",
  )
  @fs.write_string_to_file(
    config.site.templates_dir.unwrap() + "/page.html",
    "<main id=\"template-id\">{{content}}</main>",
  )
  let first = @builder.build(config, @cache.empty(config.output_dir), strict_wikilinks=true)
  assert_eq(first.errors, 0)
  let before = publication_snapshot(config.output_dir)
  @fs.write_string_to_file(
    config.site.templates_dir.unwrap() + "/page.html",
    "<main id=\"template-id\">Content omitted</main>",
  )
  let next = @builder.build(config, publication_load_cache(config), strict_wikilinks=true)
  assert_eq(next.errors, 1)
  assert_true(next.diagnostics.any(d => d.message.contains("fragment 'local'")))
  assert_eq(publication_snapshot(config.output_dir), before)
}

///|
test "strict wikilinks reject excluded destination and include drafts on request" {
  let config = publication_fixture("strict_drafts")
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\n---\nSee [[beta]].\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/beta.md",
    "---\ntitle: Beta\ndate: 2026-02-03\ndraft: true\n---\nDraft body.\n",
  )
  let first = @builder.build(config, @cache.empty(config.output_dir), strict_wikilinks=true)
  assert_eq(first.errors, 1)
  assert_false(@fs.path_exists(config.output_dir))
  let included = @builder.build(
    { ..config, include_drafts: true }, @cache.empty(config.output_dir),
    strict_wikilinks=true,
  )
  assert_eq(included.errors, 0)
}
