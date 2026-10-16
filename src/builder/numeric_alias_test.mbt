///|
test "numeric-prefixed YAML aliases publish as arrays across rebuilds" {
  let config = publication_fixture("numeric_aliases")
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
    "---\ntitle: Alpha\ndate: 2026-01-02\naliases: [3D printing, 2026 roadmap, 1.5 release, -beta notes]\n---\nAlpha body.\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/beta.md",
    "---\ntitle: Beta\ndate: 2026-02-03\naliases:\n  - 3D printing\n  - 2026 roadmap\n  - 1.5 release\n  - -beta notes\n---\nBeta body.\n",
  )
  let expected = "<ul><li>3D printing</li><li>2026 roadmap</li><li>1.5 release</li><li>-beta notes</li></ul>"
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
    for slug in ["alpha", "beta"] {
      let html = @fs.read_file_to_string(
        config.output_dir + "/posts/" + slug + "/index.html",
      )
      assert_true(html.contains(expected))
    }
  }
}
