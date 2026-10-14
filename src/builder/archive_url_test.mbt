///|
test "archive metadata URLs match published year and month destinations" {
  for base in ["https://example.test/wiki/", "/"] {
    for fallback in [false, true] {
      let fixture = publication_fixture("archive_canonical_url")
      let template = "<html><head>{{head_meta}}</head><body><span>{{url}}</span><nav>{{page_url}}</nav>{{content}}</body></html>"
      let templates = fixture.content_dir + "/../templates"
      if fallback {
        @fs.remove_file(templates + "/archive.html")
        @fs.write_string_to_file(templates + "/index.html", template)
      } else {
        @fs.write_string_to_file(templates + "/archive.html", template)
      }
      let site_cfg = @fs.read_file_to_string(fixture.config_path).replace_all(
        old="base_url = https://example.test\n",
        new="base_url = " + base + "\n",
      )
      let site = match @config.parse(site_cfg) {
        Ok(site) => site
        Err(_) => abort("invalid archive fixture configuration")
      }
      let config = { ..fixture, site, }
      let origin = if base == "/" { "" } else { "https://example.test/wiki" }
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
        // These paths are the actual published files, not renderer-derived URLs.
        for
          path in [
            "posts/2026/", "posts/2026/01/", "posts/2026/02/", "posts/archive/",
          ] {
          let html = @fs.read_file_to_string(
            config.output_dir + "/" + path + "index.html",
          )
          let expected = origin + "/" + path
          assert_true(
            html.contains("<link rel=\"canonical\" href=\"" + expected + "\""),
          )
          assert_true(
            html.contains(
              "<meta property=\"og:url\" content=\"" + expected + "\"",
            ),
          )
          assert_true(html.contains("<span>" + expected + "</span>"))
          assert_true(html.contains("<nav>/" + path + "</nav>"))
        }
      }
    }
  }
}
