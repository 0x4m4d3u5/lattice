///|
test "body_no_h1 removes the rendered title but preserves later headings" {
  let config = publication_fixture("body_no_h1_anchor")
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\n---\n# Alpha\n\nBody.\n\n# Later\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/../templates/page.html",
    "<html><h1>{{page.title}}</h1><main>{{body_no_h1}}</main></html>",
  )
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
    if pass == 1 {
      assert_true(result.unchanged_pages >= 2)
    }
    let html = @fs.read_file_to_string(
      config.output_dir + "/posts/alpha/index.html",
    )
    assert_true(
      html.contains(
        "<h1>Alpha</h1><main><p>Body.</p>\n<h1 id=\"later\">Later</h1>\n</main>",
      ),
    )
    assert_false(html.contains("<h1 id=\"alpha\">"))
  }
}

///|
test "body_no_h1 skips literal closing tags in published Markdown" {
  for
    body in [
      "# Title <!-- > </h1> -->\n\nBody.\n", "<h1 id=\"title\"><span data-label=\"</h1>\">Title</span></h1>\n\nBody.\n",
    ] {
    let config = publication_fixture("body_no_h1_literals")
    @fs.write_string_to_file(
      config.content_dir + "/posts/alpha.md",
      "---\ntitle: Alpha\ndate: 2026-01-02\n---\n" + body,
    )
    @fs.write_string_to_file(
      config.content_dir + "/../templates/page.html",
      "<main>{{body_no_h1}}</main>",
    )
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
      if pass == 1 {
        assert_true(result.unchanged_pages >= 2)
      }
      assert_eq(
        @fs.read_file_to_string(config.output_dir + "/posts/alpha/index.html"),
        "<main><p>Body.</p>\n</main>",
      )
    }
  }
}

///|
test "SVG headings strip through Markdown and cached publishing" {
  for
    body in [
      "# <svg><title>Icon</title></svg> Title\n\nBody.\n", "# <svg><style>.icon{fill:green}</style></svg> Title\n\nBody.\n",
      "<h1><svg><title>Icon</title></svg> Title</h1>\n\nBody.\n", "<h1><svg><style>.icon{fill:green}</style></svg> Title</h1>\n\nBody.\n",
    ] {
    let config = publication_fixture("body_no_h1_svg")
    @fs.write_string_to_file(
      config.content_dir + "/posts/alpha.md",
      "---\ntitle: Alpha\ndate: 2026-01-02\n---\n" + body,
    )
    @fs.write_string_to_file(
      config.content_dir + "/../templates/page.html",
      "<main>{{body_no_h1}}</main>",
    )
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
      assert_eq(
        @fs.read_file_to_string(config.output_dir + "/posts/alpha/index.html"),
        "<main><p>Body.</p>\n</main>",
      )
    }
  }
}

///|
test "optional end tags and SVG CDATA publish without the leading h1" {
  for
    body in [
      "# <ruby>漢<rt>kan</ruby>\n\nBody.\n", "<h1><ruby>漢<rp>(<rt>kan<rp>)</ruby></h1>\n\nBody.\n",
      "<h1><select><option>A<option>B</select></h1>\n\nBody.\n", "<h1><svg><![CDATA[literal </h1>]]></svg></h1>\n\nBody.\n",
    ] {
    let config = publication_fixture("body_no_h1_optional")
    @fs.write_string_to_file(
      config.content_dir + "/posts/alpha.md",
      "---\ntitle: Alpha\ndate: 2026-01-02\n---\n" + body,
    )
    @fs.write_string_to_file(
      config.content_dir + "/../templates/page.html",
      "<main>{{body_no_h1}}</main>",
    )
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
      if pass == 1 {
        assert_true(result.unchanged_pages >= 2)
      }
      assert_eq(
        @fs.read_file_to_string(config.output_dir + "/posts/alpha/index.html"),
        "<main><p>Body.</p>\n</main>",
      )
    }
  }
}
