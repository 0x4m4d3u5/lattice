///|
test "workshop organizer guards render nested contacts and preserve publication on malformed edit" {
  let config = publication_fixture("nested_conditional")
  @fs.write_string_to_file(
    config.collections_path.unwrap(),
    "[posts]\nschema = title:String,date:Date,organizer:Optional[String],sessions:Optional[Array[String]]\ndir = " +
    config.content_dir +
    "/posts\n",
  )
  let template_path = config.site.templates_dir.unwrap() + "/page.html"
  let template = "<html><body>{{?page.organizer}}<section><h2>Schedule</h2>{{#each page.sessions}}<article><h3>{{item}}</h3>{{?page.organizer}}<p>Contact {{page.organizer}}</p>{{/?page.organizer}}</article>{{/each}}</section>{{/?page.organizer}}{{content}}</body></html>\n"
  @fs.write_string_to_file(template_path, template)
  let source_path = config.content_dir + "/posts/alpha.md"
  @fs.write_string_to_file(
    source_path, "---\ntitle: Workshop\ndate: 2026-01-02\norganizer: Ada\nsessions: [Morning, Evening]\n---\nBook a session.\n",
  )
  assert_eq(@builder.check(config).violations.length(), 0)
  assert_true(!@fs.path_exists(config.output_dir))
  assert_eq(@builder.build(config, @cache.empty(config.output_dir)).errors, 0)
  let output_path = config.output_dir + "/posts/alpha/index.html"
  let expected = "<html><body><section><h2>Schedule</h2><article><h3>Morning</h3><p>Contact Ada</p></article><article><h3>Evening</h3><p>Contact Ada</p></article></section><p>Book a session.</p>\n</body></html>\n"
  assert_eq(@fs.read_file_to_string(output_path), expected)
  assert_eq(
    @fs.read_file_to_string(config.output_dir + "/posts/beta/index.html"),
    "<html><body><p>Original beta.</p>\n</body></html>\n",
  )
  let before = publication_snapshot(config.output_dir)
  assert_eq(@builder.check(config).violations.length(), 0)
  assert_eq(publication_snapshot(config.output_dir), before)
  let cached = @builder.build(
    publication_incremental(config),
    publication_load_cache(config),
  )
  assert_eq(cached.errors, 0)
  assert_eq(cached.unchanged_pages, 2)
  @fs.write_string_to_file(
    source_path, "---\ntitle: Workshop\ndate: 2026-01-02\nsessions: [Morning, Evening]\n---\nBook a session.\n",
  )
  assert_eq(
    @builder.build(
      publication_incremental(config),
      publication_load_cache(config),
    ).errors,
    0,
  )
  let hidden = "<html><body><p>Book a session.</p>\n</body></html>\n"
  assert_eq(@fs.read_file_to_string(output_path), hidden)
  assert_eq(@builder.build(config, publication_load_cache(config)).errors, 0)
  assert_eq(@fs.read_file_to_string(output_path), hidden)
  let snapshot = publication_snapshot(config.output_dir)
  @fs.write_string_to_file(
    template_path, "{{?page.organizer}}{{?page.organizer}}Contact{{/?page.organizer}}",
  )
  assert_true(
    @builder.check(config).violations.any(fn(v) {
      v.message.contains("missing closing tag for conditional block")
    }),
  )
  assert_eq(publication_snapshot(config.output_dir), snapshot)
  assert_true(
    @builder.build(
      publication_incremental(config),
      publication_load_cache(config),
    ).errors >
    0,
  )
  assert_eq(publication_snapshot(config.output_dir), snapshot)
  @fs.write_string_to_file(template_path, template)
  assert_eq(
    @builder.build(
      publication_incremental(config),
      publication_load_cache(config),
    ).errors,
    0,
  )
  assert_eq(@fs.read_file_to_string(output_path), hidden)
}
