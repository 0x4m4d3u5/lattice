///|
test "image validation follows final static ownership" {
  let config : BuildConfig = {
    content_dir: "./_tmp_image_source",
    output_dir: "./_tmp_image_output",
    config_path: "",
    site: @config.parse("title = Test\nbase_url = https://example.test\n").unwrap(),
    collections_path: None,
    force_rebuild: false,
    include_drafts: false,
  }
  let collections = alias_test_sources([("note", "[]")])
  let source = collections[0].sources[0]
  collections[0].sources[0] = {
    ..source,
    content: "---\ntitle: Note\n---\n![[figure.png]]\n",
  }
  let index : Map[String, String] = Map([
    ("![[figure.png]]", "/static/figure.png"),
  ])
  let output = OutputPlan::new(config.output_dir)
  let path = config.output_dir + "/static/figure.png"
  output.write_bytes(
    path,
    b"image",
    origin=StaticAsset("content/static/figure.png"),
  )
  let violations : Array[@lint.LintViolation] = []
  check_image_embeds(collections, config, index, output, violations)
  assert_eq(violations.length(), 0)
  output.write_text(path, "generated replacement")
  check_image_embeds(collections, config, index, output, violations)
  assert_eq(violations.length(), 1)
  assert_true(violations[0].message.contains("not a retained static asset"))
}

///|
test "image diagnostic locations ignore code and escaped markers" {
  let source = "---\ntitle: Note\n---\n`![[missing.png]]`\n\n~~~\n![[missing.png]]\n~~~\n\nText ![[missing.png]]\n"
  assert_eq(image_embed_location(source, "missing.png"), (Some(10), Some(6)))
}
