///|
test "malformed table widths preserve published links and indexed text" {
  let config = publication_fixture("table_shape_links")
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\n---\n" +
    "| Note |\n| --- | --- |\n" +
    "| Alpha | [[beta]] |\n",
  )
  @fs.remove_file(config.content_dir + "/../templates/page.html")
  let site_cfg = @fs.read_file_to_string(config.config_path) +
    "content_index_file = content-index.json\n"
  let site = match @config.parse(site_cfg) {
    Ok(site) => site
    Err(_) => abort("invalid table fixture configuration")
  }
  let config = { ..config, site, }
  for pass in 0..<2 {
    let cache = if pass == 0 {
      @cache.empty(config.output_dir)
    } else {
      publication_load_cache(config)
    }
    let build_config = if pass == 0 {
      config
    } else {
      publication_incremental(config)
    }
    let result = @builder.build(build_config, cache)
    assert_eq(result.errors, 0)
    if pass == 1 {
      assert_true(result.unchanged_pages >= 2)
    }
    assert_eq(@builder.check(build_config).violations.length(), 0)
    let html = @fs.read_file_to_string(
      config.output_dir + "/posts/alpha/index.html",
    )
    assert_false(html.contains("<table>"))
    assert_true(html.contains("<a href=\"/posts/beta/\">beta</a>"))
    let graph = @json.parse(
      @fs.read_file_to_string(config.output_dir + "/graph.json"),
    )
    guard graph is Object(graph_fields) else {
      abort("graph must be an object")
    }
    assert_eq(
      graph_fields.get("edges"),
      Some(@json.parse("[{\"source\":\"alpha\",\"target\":\"beta\"}]")),
    )
    let index = @json.parse(
      @fs.read_file_to_string(config.output_dir + "/content-index.json"),
    )
    guard index is Array(entries) else {
      abort("content index must be an array")
    }
    let alpha = entries.filter(fn(entry) {
      match entry {
        Object(fields) =>
          fields.get("url") == Some(Json::string("/posts/alpha/"))
        _ => false
      }
    })
    assert_eq(alpha.length(), 1)
    guard alpha[0] is Object(fields) else { abort("entry must be an object") }
    assert_eq(
      fields.get("body"),
      Some(Json::string("| Note | | --- | --- | | Alpha | beta |")),
    )
    let beta = @fs.read_file_to_string(
      config.output_dir + "/posts/beta/index.html",
    )
    assert_true(beta.contains("href=\"/posts/alpha/\""))
  }
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\n---\n" +
    "| Note |\n| --- | --- |\n| Alpha | [[missing-page]] |\n",
  )
  let broken = @builder.check(config).violations.filter(fn(v) {
    v.kind == @lint.BrokenWikilink
  })
  assert_eq(broken.length(), 1)
  assert_true(broken[0].message.contains("missing-page"))
}
