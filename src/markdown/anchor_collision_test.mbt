///|
test "numbered release headings do not collide with duplicate suffixes" {
  for
    (body, expected) in [
      (
        "## Release 2\n\n## Release\n\n## Release\n\n## Release 3\n\n## Release\n",
        [
          ("release-2", "Release 2"),
          ("release", "Release"),
          ("release-3", "Release"),
          ("release-3-2", "Release 3"),
          ("release-4", "Release"),
        ],
      ),
      (
        "## Release\n\n## Release\n\n## Release 2\n\n## Release 2\n\n## Release 2 2\n",
        [
          ("release", "Release"),
          ("release-2", "Release"),
          ("release-2-2", "Release 2"),
          ("release-2-3", "Release 2"),
          ("release-2-2-2", "Release 2 2"),
        ],
      ),
      (
        "## Release 2\n\n## Release 3\n\n## Release 4\n\n## Release\n\n## Release\n",
        [
          ("release-2", "Release 2"),
          ("release-3", "Release 3"),
          ("release-4", "Release 4"),
          ("release", "Release"),
          ("release-5", "Release"),
        ],
      ),
    ] {
    let rendered = @markdown.render_with_diagnostics(body, Map([]))
    assert_eq(rendered.toc.map(fn(e) { (e.anchor, e.text) }), expected)
    let extracted = @markdown.extract_table_of_contents(body, 2)
    assert_eq(extracted.map(fn(e) { (e.anchor, e.text) }), expected)
    let expected_html = StringBuilder()
    for (anchor, title) in expected {
      expected_html.write_string(
        "<h2 id=\"" + anchor + "\">" + title + "</h2>\n",
      )
    }
    assert_eq(rendered.html, expected_html.to_string())
  }
}

///|
test "filtered and nested headings reserve complete emitted anchors" {
  let body = "# Release 2\n\n- Notes\n  > ### Release\n\n## Release\n\n## Release 2\n"
  let rendered = @markdown.render_with_diagnostics(body, Map([]))
  assert_true(rendered.html.contains("<h1 id=\"release-2\">Release 2</h1>"))
  assert_true(rendered.html.contains("<h3 id=\"release\">Release</h3>"))
  assert_true(rendered.html.contains("<h2 id=\"release-3\">Release</h2>"))
  assert_true(rendered.html.contains("<h2 id=\"release-2-2\">Release 2</h2>"))
  let extracted = @markdown.extract_table_of_contents(body, 2)
  assert_eq(extracted.map(fn(e) { (e.anchor, e.text) }), [
    ("release-3", "Release"),
    ("release-2-2", "Release 2"),
  ])
}
