///|
test "workshop site renders nested loops across fresh and cached dependency edits" {
  let config = publication_fixture("nested_each")
  @fs.write_string_to_file(
    config.collections_path.unwrap(),
    "[posts]\nschema = title:String,date:Date,sessions:Optional[Array[String]]\ndir = " +
    config.content_dir +
    "/posts\n",
  )
  let data_path = config.content_dir + "/data/workshops.toml"
  @fs.write_string_to_file(data_path, "locations = [\"North\", \"South\"]\n")
  let template_path = config.site.templates_dir.unwrap() + "/page.html"
  let template = "<html><body>{{#each data.workshops.locations}}<section><h2>{{item}}</h2><ul>{{#each page.sessions}}<li>{{item}}</li>{{/each}}</ul><footer>{{item}}</footer></section>{{/each}}{{content}}</body></html>\n"
  @fs.write_string_to_file(template_path, template)
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Workshop Schedule\ndate: 2026-01-02\nsessions: [Morning, Evening]\n---\nBook a session.\n",
  )
  let built = @builder.build(config, @cache.empty(config.output_dir))
  assert_eq(built.errors, 0)
  let output_path = config.output_dir + "/posts/alpha/index.html"
  let original = @fs.read_file_to_string(output_path)
  assert_eq(
    original, "<html><body><section><h2>North</h2><ul><li>Morning</li><li>Evening</li></ul><footer>North</footer></section><section><h2>South</h2><ul><li>Morning</li><li>Evening</li></ul><footer>South</footer></section><p>Book a session.</p>\n</body></html>\n",
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
  @fs.write_string_to_file(data_path, "locations = [\"West\"]\n")
  let edited = @builder.build(
    publication_incremental(config),
    publication_load_cache(config),
  )
  assert_eq(edited.errors, 0)
  let updated = @fs.read_file_to_string(output_path)
  assert_eq(
    updated, "<html><body><section><h2>West</h2><ul><li>Morning</li><li>Evening</li></ul><footer>West</footer></section><p>Book a session.</p>\n</body></html>\n",
  )
  let full = @builder.build(config, publication_load_cache(config))
  assert_eq(full.errors, 0)
  assert_eq(@fs.read_file_to_string(output_path), updated)
  let snapshot = publication_snapshot(config.output_dir)
  @fs.write_string_to_file(
    template_path, "<html><body>{{#each data.workshops.locations}}{{#each page.sessions}}{{item}}{{/each}}</body></html>\n",
  )
  assert_true(
    @builder.check(config).violations.any(fn(v) {
      v.message.contains("missing closing tag for each block")
    }),
  )
  assert_eq(publication_snapshot(config.output_dir), snapshot)
  let failed = @builder.build(
    publication_incremental(config),
    publication_load_cache(config),
  )
  assert_true(failed.errors > 0)
  assert_eq(publication_snapshot(config.output_dir), snapshot)
  @fs.write_string_to_file(template_path, template)
  let recovered = @builder.build(
    publication_incremental(config),
    publication_load_cache(config),
  )
  assert_eq(recovered.errors, 0)
  assert_eq(@fs.read_file_to_string(output_path), updated)
}
