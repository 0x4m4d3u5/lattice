///|
test "unclosed math fallback preserves following text headings and links" {
  for ending in ["\n", "\r\n"] {
    let source = [
      "$$", "Keep this text.", "", "## Recovery", "Read [[soil|Soil]].",
    ].join(ending)
    let rendered = @markdown.render_with_diagnostics(
      source,
      Map([("soil", "/soil/")]),
    )
    assert_eq(
      rendered.html,
      "<p>$$</p>\n<p>Keep this text.</p>\n<h2 id=\"recovery\">Recovery</h2>\n<p>Read <a href=\"/soil/\">Soil</a>.</p>\n",
    )
    assert_eq(rendered.toc.length(), 1)
    assert_eq(rendered.toc[0].anchor, "recovery")
  }
}

///|
test "unclosed math fallback preserves quoted content and outer prose" {
  assert_eq(
    @markdown.render("> $$\n> Kept.\n\nAfter.", Map([])),
    "<blockquote>\n<p>$$</p>\n<p>Kept.</p>\n</blockquote>\n<p>After.</p>\n",
  )
}

///|
test "closed math remains opaque to headings and wikilinks" {
  let rendered = @markdown.render_with_diagnostics(
    "$$\n## Not a heading\n[[missing]]\n$$\n\nAfter.",
    Map([]),
  )
  assert_eq(
    rendered.html,
    "<div class=\"math-block\">\\[## Not a heading\n[[missing]]\\]</div>\n<p>After.</p>\n",
  )
  assert_eq(rendered.toc.length(), 0)
  assert_eq(
    @markdown.render("$$\n\n> $$\n> x^2\n> $$\n\nAfter.", Map([])),
    "<p>$$</p>\n<blockquote>\n<div class=\"math-block\">\\[x^2\\]</div>\n</blockquote>\n<p>After.</p>\n",
  )
}

///|
test "repeated unclosed math openers all survive fallback" {
  let (blocks, _) = @markdown.parse_blocks_with_footnotes(
    Array::make(10000, "$$x"),
  )
  assert_eq(blocks.length(), 10000)
}
