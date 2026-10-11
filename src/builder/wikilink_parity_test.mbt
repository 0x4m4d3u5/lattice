///|
test "strict check sees broken wikilinks after unmatched inline backticks" {
  let config = publication_fixture("unmatched_inline_wikilink")
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\n---\nAn unmatched ` before [[missing-page]].\n",
  )
  publication_seed_success(config)
  let before = publication_snapshot(config.output_dir)
  let checked = @builder.check(config)
  let broken = checked.violations.filter(fn(v) {
    v.kind == @lint.BrokenWikilink
  })
  assert_eq(broken.length(), 1)
  assert_true(broken[0].message.contains("missing-page"))
  assert_eq(publication_snapshot(config.output_dir), before)
  let html = @fs.read_file_to_string(
    config.output_dir + "/posts/alpha/index.html",
  )
  assert_true(
    html.contains(
      "An unmatched ` before <a class=\"wl-broken\" href=\"#\">missing-page</a>",
    ),
  )
  let result = @builder.build(
    publication_incremental(config),
    publication_load_cache(config),
  )
  assert_eq(result.errors, 0)
  assert_eq(
    result.diagnostics
    .filter(fn(d) {
      d.severity == @diagnostic.Warning &&
      d.message.contains("unresolved wikilink [[missing-page]]")
    })
    .length(),
    1,
  )
}

///|
test "strict check excludes fenced blockquote examples and resolves following wikilinks" {
  for delimiter in ["~~~", "```"] {
    let config = publication_fixture("blockquote_fenced_wikilink")
    @fs.write_string_to_file(
      config.content_dir + "/posts/alpha.md",
      "---\ntitle: Alpha\ndate: 2026-01-02\n---\n> " +
      delimiter +
      "\n> [[missing-page]]\n> " +
      delimiter +
      "\n\nSee [[beta|Beta page]].\n",
    )
    publication_seed_success(config)
    let before = publication_snapshot(config.output_dir)
    assert_eq(@builder.check(config).violations.length(), 0)
    assert_eq(publication_snapshot(config.output_dir), before)
    let result = @builder.build(
      publication_incremental(config),
      publication_load_cache(config),
    )
    assert_eq(result.errors, 0)
    assert_eq(
      result.diagnostics
      .filter(fn(d) { d.message.contains("missing-page") })
      .length(),
      0,
    )
    let html = @fs.read_file_to_string(
      config.output_dir + "/posts/alpha/index.html",
    )
    assert_true(
      html.contains(
        "<blockquote>\n<pre><code>[[missing-page]]</code></pre>\n</blockquote>",
      ),
    )
    assert_true(html.contains("<a href=\"/posts/beta/\">Beta page</a>"))
    assert_false(html.contains("wl-broken"))
  }
}

///|
test "strict check treats indented paired backticks as inline code rather than links" {
  for prefix in ["  ", "\t"] {
    let config = publication_fixture("indented_inline_wikilink")
    @fs.write_string_to_file(
      config.content_dir + "/posts/alpha.md",
      "---\ntitle: Alpha\ndate: 2026-01-02\n---\n" +
      prefix +
      "```\n[[missing-page]]\n" +
      prefix +
      "```",
    )
    publication_seed_success(config)
    let before = publication_snapshot(config.output_dir)
    assert_eq(@builder.check(config).violations.length(), 0)
    assert_eq(publication_snapshot(config.output_dir), before)
    let html = @fs.read_file_to_string(
      config.output_dir + "/posts/alpha/index.html",
    )
    assert_true(html.contains("<code>"))
    assert_true(html.contains("[[missing-page]]"))
    assert_false(html.contains("wl-broken"))
  }
}
