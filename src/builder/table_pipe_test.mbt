///|
test "table wikilink aliases publish links and complete indexed cells" {
  let config = publication_fixture("table_alias_pipe")
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\n---\n" +
    "| Note | Detail |\n| --- | --- |\n" +
    "| [[beta\\|Beta page]] | Kept detail |\n",
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
    assert_eq(@builder.check(build_config).violations.length(), 0)
    let html = @fs.read_file_to_string(
      config.output_dir + "/posts/alpha/index.html",
    )
    assert_true(
      html.contains("<td><a href=\"/posts/beta/\">Beta page</a></td>"),
    )
    assert_true(html.contains("<td>Kept detail</td>"))
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
      Some(Json::string("Note Detail Beta page Kept detail")),
    )
    let beta = @fs.read_file_to_string(
      config.output_dir + "/posts/beta/index.html",
    )
    assert_true(beta.contains("href=\"/posts/alpha/\""))
  }
}
