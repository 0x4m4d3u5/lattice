///|
fn image_alt_policy(
  config : @builder.BuildConfig,
) -> @builder.BuildConfig raise {
  let text = @fs.read_file_to_string(config.config_path) +
    "require_image_alt = true\n"
  @fs.write_string_to_file(config.config_path, text)
  let site = match @config.parse(text) {
    Ok(site) => site
    Err(_) => abort("image alt fixture config invalid")
  }
  {
    content_dir: config.content_dir,
    output_dir: config.output_dir,
    config_path: config.config_path,
    site,
    collections_path: config.collections_path,
    force_rebuild: false,
    include_drafts: config.include_drafts,
  }
}

///|
test "opt-in image alt policy checks all document locations without output writes" {
  let config = publication_fixture("image_alt_locations")
  for
    (path, source) in [
      (
        "/posts/alpha.md", "---\ntitle: Alpha\ndate: 2026-01-02\n---\n![](/post.png)\n",
      ),
      ("/standalone/about.md", "---\ntitle: About\n---\n![ \t ](/about.png)\n"),
      ("/index.md", "---\ntitle: Home\n---\n> ![](/home.png)\n"),
    ] {
    @fs.write_string_to_file(config.content_dir + path, source)
  }
  // Omission preserves previous behavior, including publishing empty alt="".
  assert_eq(@builder.check(config).violations.length(), 0)
  publication_seed_success(config)
  assert_true(
    @fs.read_file_to_string(config.output_dir + "/posts/alpha/index.html").contains(
      "<img src=\"/post.png\" alt=\"\" />",
    ),
  )
  let snapshot = publication_snapshot(config.output_dir)
  let enabled = image_alt_policy(config)
  let checked = @builder.check(enabled)
  let violations = checked.violations.filter(v => {
    @lint.violation_type_name(v.kind) == "missing_image_alt"
  })
  assert_eq(violations.length(), 3)
  assert_true(
    @lint.format_violations_json(checked).contains(
      "\"kind\": \"missing_image_alt\"",
    ),
  )
  let paths = violations.map(v => v.path)
  for path in ["/posts/alpha.md", "/standalone/about.md", "/index.md"] {
    assert_true(paths.contains(config.content_dir + path))
  }
  for v in violations {
    let d = @diagnostic.of_lint_violation(v)
    assert_eq(d.code, Some("E012"))
    assert_eq(d.severity, @diagnostic.Error)
    assert_eq(v.line, None) // AST has no source spans; do not invent positions.
  }
  assert_eq(publication_snapshot(config.output_dir), snapshot)
  // Enabling the policy must reject previously cached, unchanged sources too.
  let rebuilt = @builder.build(enabled, publication_load_cache(config))
  assert_true(rebuilt.errors > 0)
  assert_eq(rebuilt.diagnostics.filter(d => d.code == Some("E012")).length(), 3)
  assert_eq(publication_snapshot(config.output_dir), snapshot)
}

///|
test "image alt policy rejects a failed first build before creating output" {
  let config = publication_fixture("image_alt_first_build")
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\n---\n![](/missing-alt.png)\n",
  )
  let enabled = image_alt_policy(config)
  let result = @builder.build(enabled, @cache.empty(enabled.output_dir))
  assert_true(result.errors > 0)
  assert_eq(result.diagnostics.filter(d => d.code == Some("E012")).length(), 1)
  assert_false(@fs.path_exists(enabled.output_dir))
}

///|
test "image alt policy permits descriptions explicit decorative shortcodes and code examples" {
  let config = publication_fixture("image_alt_valid")
  let body = "![A red fox](/fox.png)\n\n" +
    "{{< image src=\"/decoration.png\" alt=\"\" >}}\n\n" +
    "`![](/inline-example.png)`\n\n" +
    "```markdown\n![](/fenced-example.png)\n```\n\n" +
    "> ~~~\n> ![](/quote-code.png)\n> ~~~\n\n" +
    "<img src=\"/raw-decorative.png\" alt=\"\">\n"
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\n---\n" + body,
  )
  let enabled = image_alt_policy(config)
  assert_eq(@builder.check(enabled).violations.length(), 0)
  let result = @builder.build(enabled, @cache.empty(enabled.output_dir))
  assert_eq(result.errors, 0)
  let html = @fs.read_file_to_string(
    enabled.output_dir + "/posts/alpha/index.html",
  )
  assert_true(html.contains("alt=\"A red fox\""))
  assert_true(html.contains("src=\"/decoration.png\" alt=\"\""))
  assert_true(html.contains("![](/inline-example.png)"))
}

///|
test "opt-in image alt policy rejects blank shortcode text after cached default build" {
  let config = publication_fixture("shortcode_alt_cached")
  let path = config.content_dir + "/posts/alpha.md"
  @fs.write_string_to_file(
    path,
    "---\ntitle: Alpha\ndate: 2026-01-02\n---\n" +
    "{{< image src=\"/image.png\" alt=\" \t \" >}}\n\n" +
    "{{< figure src=\"/figure.png\" alt=\" \" caption=\"A caption does not replace alt\" >}}\n",
  )
  assert_eq(@builder.check(config).violations.length(), 0)
  publication_seed_success(config)
  let html = @fs.read_file_to_string(
    config.output_dir + "/posts/alpha/index.html",
  )
  assert_true(html.contains("src=\"/image.png\" alt=\" \t \""))
  assert_true(html.contains("src=\"/figure.png\" alt=\" \""))
  let snapshot = publication_snapshot(config.output_dir)
  let enabled = image_alt_policy(config)
  let checked = @builder.check(enabled)
  let bad = checked.violations.filter(v => {
    @lint.violation_type_name(v.kind) == "missing_image_alt"
  })
  assert_eq(bad.length(), 2)
  assert_true(bad[0].message.contains("/image.png"))
  assert_true(bad[1].message.contains("/figure.png"))
  for v in bad {
    assert_eq(v.path, path)
    assert_eq(@diagnostic.of_lint_violation(v).code, Some("E012"))
  }
  assert_eq(publication_snapshot(config.output_dir), snapshot)
  let built = @builder.build(enabled, publication_load_cache(config))
  assert_true(built.errors > 0)
  assert_eq(built.diagnostics.filter(d => d.code == Some("E012")).length(), 2)
  assert_eq(publication_snapshot(config.output_dir), snapshot)
}

///|
test "shortcode image alt policy keeps explicit decoration and native shortcode errors" {
  let config = publication_fixture("shortcode_alt_decorative")
  let path = config.content_dir + "/posts/alpha.md"
  let header = "---\ntitle: Alpha\ndate: 2026-01-02\n---\n"
  @fs.write_string_to_file(
    path,
    header +
    "{{< image src=\"/ornament.png\" alt=\"\" >}}\n\n" +
    "{{< figure src=\"/separator.png\" alt=\"\" link=\"/about/\" >}}\n\n" +
    "{{< image src=\"/photo.png\" alt=\"Red fox in snow\" >}}\n\n" +
    "`{{< image src=\"/example.png\" alt=\" \" >}}`\n",
  )
  let enabled = image_alt_policy(config)
  assert_eq(@builder.check(enabled).violations.length(), 0)
  let result = @builder.build(enabled, @cache.empty(enabled.output_dir))
  assert_eq(result.errors, 0)
  let html = @fs.read_file_to_string(
    enabled.output_dir + "/posts/alpha/index.html",
  )
  assert_true(html.contains("src=\"/ornament.png\" alt=\"\""))
  assert_true(html.contains("src=\"/separator.png\" alt=\"\""))
  for
    shortcode in [
      "{{< image src=\"/bad.png\" >}}", "{{< figure src=\"/bad.png\" alt=42 >}}",
      "{{< image src=\"/bad.png\" alt=\" \" caption=42 >}}",
    ] {
    @fs.write_string_to_file(path, header + shortcode)
    let checked = @builder.check(enabled)
    assert_eq(checked.violations.length(), 1)
    assert_eq(
      @diagnostic.of_lint_violation(checked.violations[0]).code,
      Some("E008"),
    )
  }
}
