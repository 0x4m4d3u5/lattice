///|
test "guide TOC visits list headings in rendered order" {
  for marker in ["-", "1."] {
    let body = marker + " Install\n  ## Setup\n  ### Details\n\n## Setup\n"
    let rendered = @markdown.render_with_diagnostics(body, Map([]))
    assert_true(rendered.html.contains("<h2 id=\"setup\">Setup</h2>"))
    assert_true(rendered.html.contains("<h3 id=\"details\">Details</h3>"))
    assert_true(rendered.html.contains("<h2 id=\"setup-2\">Setup</h2>"))
    let expected = [
      (2, "setup", "Setup"),
      (3, "details", "Details"),
      (2, "setup-2", "Setup"),
    ]
    assert_eq(rendered.toc.map(fn(e) { (e.level, e.anchor, e.text) }), expected)
    let extracted = @markdown.extract_table_of_contents(body, 3)
    assert_eq(extracted.map(fn(e) { (e.level, e.anchor, e.text) }), expected)
  }
}

///|
test "filtered headings inside nested lists still reserve anchors" {
  let body = "- Install\n  - [x] Verify\n    > ### Setup\n\n## Setup\n"
  let rendered = @markdown.render_with_diagnostics(body, Map([]))
  assert_true(rendered.html.contains("<h3 id=\"setup\">Setup</h3>"))
  assert_true(rendered.html.contains("<h2 id=\"setup-2\">Setup</h2>"))
  let extracted = @markdown.extract_table_of_contents(body, 2)
  assert_eq(extracted.map(fn(e) { (e.level, e.anchor, e.text) }), [
    (2, "setup-2", "Setup"),
  ])
}
