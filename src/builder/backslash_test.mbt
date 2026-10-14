///|
test "literal path backslashes survive published and indexed bodies" {
  let fixture = publication_fixture("literal_backslashes")
  @fs.write_string_to_file(
    fixture.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\n---\n" +
    "Paths C:\\Users\\notes and C:\\2026\\draft.\n",
  )
  let site_cfg = @fs.read_file_to_string(fixture.config_path) +
    "content_index_file = content-index.json\n"
  let site = match @config.parse(site_cfg) {
    Ok(site) => site
    Err(_) => abort("invalid backslash fixture configuration")
  }
  let config = { ..fixture, site, }
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
    let html = @fs.read_file_to_string(
      config.output_dir + "/posts/alpha/index.html",
    )
    assert_true(
      html.contains("<p>Paths C:\\Users\\notes and C:\\2026\\draft.</p>"),
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
      Some(Json::string("Paths C:\\Users\\notes and C:\\2026\\draft.")),
    )
  }
}
