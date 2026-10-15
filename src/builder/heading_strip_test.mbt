///|
test "renderer boundaries publish inline HTML titles across source page kinds" {
  for
    heading in [
      "# 🌱 Garden", "# <img src=\"/title-only.png\">", "# Title <!-- > </h1> -->",
      "# <svg><title>Icon</title><style>.x{}</style></svg> Title", "# <math><mtext><title>literal </h1></title></mtext></math>",
      "# <math><mi><svg><title>Icon</title></svg></mi></math>", "# <math><annotation-xml encoding='text&#47;html'><svg><title>Icon</title></svg></annotation-xml></math>",
    ] {
    let config = publication_fixture("body_no_h1_boundary")
    for
      location in [
        "/posts/alpha.md", "/standalone/about.md", "/index.md", "/404.md",
      ] {
      @fs.write_string_to_file(
        config.content_dir + location,
        "---\ntitle: Garden\ndate: 2026-01-02\n---\n" + heading + "\n\nBody.\n",
      )
    }
    @fs.write_string_to_file(
      config.content_dir + "/../templates/page.html",
      "<main>{{body_no_h1}}</main>",
    )
    let initial = @builder.build(config, @cache.empty(config.output_dir))
    assert_eq(initial.errors, 0)
    assert_eq(@builder.check(config).violations.length(), 0)
    for
      output in [
        "/posts/alpha/index.html", "/about/index.html", "/index.html", "/404.html",
      ] {
      assert_eq(
        @fs.read_file_to_string(config.output_dir + output),
        "<main><p>Body.</p>\n</main>",
      )
    }
    let before = publication_snapshot(config.output_dir)
    let cached = @builder.build(
      publication_incremental(config),
      publication_load_cache(config),
    )
    assert_eq(cached.errors, 0)
    assert_true(cached.unchanged_pages >= 2)
    assert_eq(publication_snapshot(config.output_dir), before)
    let forced = @builder.build(config, publication_load_cache(config))
    assert_eq(forced.errors, 0)
    assert_eq(publication_snapshot(config.output_dir), before)
  }
}

///|
test "body_no_h1 keeps later IDs footnotes and tag badges" {
  let config = publication_fixture("body_no_h1_metadata")
  @fs.write_string_to_file(
    config.content_dir + "/../collections.cfg",
    "[posts]\nschema = title:String,date:Date,tags:Optional[Array[String]]\ndir = " +
    config.content_dir +
    "/posts\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Garden\ndate: 2026-01-02\ntags: [soil]\n---\n# 🌱 Garden\n\n# 🌱 Garden\n\n## Garden\n\nBody[^note].\n\n[^note]: Evidence\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/../templates/page.html",
    "<main>{{body_no_h1}}</main>",
  )
  let result = @builder.build(config, @cache.empty(config.output_dir))
  assert_eq(result.errors, 0)
  assert_eq(@builder.check(config).violations.length(), 0)
  let html = @fs.read_file_to_string(
    config.output_dir + "/posts/alpha/index.html",
  )
  assert_true(
    html.has_prefix(
      "<main><h1 id=\"garden-2\">🌱 Garden</h1>\n<h2 id=\"garden-3\">Garden</h2>\n",
    ),
  )
  assert_true(html.contains("<li id=\"fn-note\">Evidence"))
  assert_true(html.contains("href=\"/tags/soil/\""))
}

///|
test "body_no_h1 retains main's raw HTML fallback" {
  for
    (body, expected) in [
      ("<h1>Raw</h1>\n\nBody.\n", "<p>Body.</p>\n"),
      (
        "<h1 id=\"raw\">Raw</h1>\n\nBody.\n", "<h1 id=\"raw\">Raw</h1>\n<p>Body.</p>\n",
      ),
      ("Intro.\n\n# Later\n", "<p>Intro.</p>\n<h1 id=\"later\">Later</h1>\n"),
    ] {
    let config = publication_fixture("body_no_h1_raw")
    @fs.write_string_to_file(
      config.content_dir + "/posts/alpha.md",
      "---\ntitle: Alpha\ndate: 2026-01-02\n---\n" + body,
    )
    @fs.write_string_to_file(
      config.content_dir + "/../templates/page.html",
      "<main>{{body_no_h1}}</main>",
    )
    let result = @builder.build(config, @cache.empty(config.output_dir))
    assert_eq(result.errors, 0)
    assert_eq(
      @fs.read_file_to_string(config.output_dir + "/posts/alpha/index.html"),
      "<main>" + expected + "</main>",
    )
  }
}

///|
test "stripped heading diagnostics still prevent publication" {
  let config = publication_fixture("body_no_h1_diagnostic")
  let path = config.content_dir + "/posts/alpha.md"
  @fs.write_string_to_file(
    path, "---\ntitle: Alpha\ndate: 2026-01-02\n---\n# {{< image src=\"/chart.png\" >}}\n\nBody.\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/../templates/page.html",
    "<main>{{body_no_h1}}</main>",
  )
  let checked = @builder.check(config)
  assert_eq(checked.violations.length(), 1)
  assert_eq(checked.violations[0].kind, @lint.ShortcodeError)
  assert_eq(
    checked.violations[0].message,
    "shortcode 'image' missing param 'alt'",
  )
  let built = @builder.build(config, @cache.empty(config.output_dir))
  assert_eq(built.errors, 1)
  assert_false(@fs.path_exists(config.output_dir + "/posts/alpha/index.html"))
}
