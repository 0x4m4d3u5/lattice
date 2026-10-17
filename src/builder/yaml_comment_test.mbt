///|
test "commented YAML metadata publishes across fresh cached and forced builds" {
  let config = publication_fixture("yaml_comments")
  @fs.write_string_to_file(
    config.collections_path.unwrap(),
    "[posts]\nschema = title:String,date:Date,featured:Optional[Bool],tags:Optional[Array[String]]\ndir = " +
    config.content_dir +
    "/posts\n",
  )
  @fs.write_string_to_file(
    config.site.templates_dir.unwrap() + "/page.html",
    "<html><body><h1>{{page.title}}</h1><ul>{{#each page.tags}}<li>{{item}}</li>{{/each}}</ul>{{content}}</body></html>\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: 'Garden''s # notes' # title\ndate: 2026-01-02 # date\nfeatured: false # explanation\ntags: [ai, 'wiki # notes'] # tags\n---\nBody.\n",
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
        "<h1>Garden's # notes</h1><ul><li>ai</li><li>wiki # notes</li></ul>",
      ),
    )
  }
}
