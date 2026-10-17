///|
test "single-quoted YAML flow aliases publish intact across rebuilds" {
  let config = publication_fixture("quoted_flow")
  @fs.write_string_to_file(
    config.collections_path.unwrap(),
    "[posts]\nschema = title:String,date:Date,aliases:Optional[Array[String]]\ndir = " +
    config.content_dir +
    "/posts\n",
  )
  @fs.write_string_to_file(
    config.site.templates_dir.unwrap() + "/page.html",
    "<html><body><ul>{{#each page.aliases}}<li>{{item}}</li>{{/each}}</ul>{{content}}</body></html>\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\naliases: ['Research, notes', 'Garden''s 🌱', 'true', '42']\n---\nAlpha body.\n",
  )
  for pass in 0..<3 {
    let build_config = if pass == 1 {
      publication_incremental(config)
    } else {
      config
    }
    let cache = if pass == 0 {
      @cache.empty(config.output_dir)
    } else {
      publication_load_cache(config)
    }
    let result = @builder.build(build_config, cache)
    assert_eq(result.errors, 0)
    if pass == 1 {
      assert_true(result.unchanged_pages >= 2)
    }
    let html = @fs.read_file_to_string(
      config.output_dir + "/posts/alpha/index.html",
    )
    assert_true(
      html.contains(
        "<ul><li>Research, notes</li><li>Garden's 🌱</li><li>true</li><li>42</li></ul>",
      ),
    )
  }
}
