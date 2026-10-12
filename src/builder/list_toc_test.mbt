///|
test "published guide links list and later headings to their literal IDs" {
  let config = publication_fixture("list_toc")
  @fs.write_string_to_file(
    config.site.templates_dir.unwrap() + "/page.html",
    "<html><body>{{table_of_contents}}{{content}}</body></html>\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Installation Guide\ndate: 2026-01-02\ntoc_depth: 2\n---\n1. Install\n  ## Setup\n  ### Setup\n\n## Setup\n",
  )
  let result = @builder.build(config, @cache.empty(config.output_dir))
  assert_eq(result.errors, 0)
  let html = @fs.read_file_to_string(
    config.output_dir + "/posts/alpha/index.html",
  )
  assert_true(html.contains("<h2 id=\"setup\">Setup</h2>"))
  assert_true(html.contains("<h3 id=\"setup-2\">Setup</h3>"))
  assert_true(html.contains("<h2 id=\"setup-3\">Setup</h2>"))
  assert_true(
    html.contains("<li class=\"toc-level-2\"><a href=\"#setup\">Setup</a></li>"),
  )
  assert_true(
    html.contains(
      "<li class=\"toc-level-2\"><a href=\"#setup-3\">Setup</a></li>",
    ),
  )
  assert_false(html.contains("href=\"#setup-2\""))
  let checked = @builder.check(config)
  assert_eq(checked.violations.length(), 0)
  let cached = @builder.build(
    publication_incremental(config),
    publication_load_cache(config),
  )
  assert_eq(cached.errors, 0)
  assert_eq(cached.unchanged_pages, 2)
  assert_eq(
    @fs.read_file_to_string(config.output_dir + "/posts/alpha/index.html"),
    html,
  )
}
