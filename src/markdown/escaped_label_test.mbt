///|
test "escaped closing brackets stay inside regular link labels" {
  // Literal HTML independently produced by cmark-gfm 0.29.0.gfm.13 --unsafe.
  for
    (source, expected) in [
      (
        "[Read \\] notes](/guide).", "<p><a href=\"/guide\">Read ] notes</a>.</p>\n",
      ),
      ("[Read \\\\](/guide).", "<p><a href=\"/guide\">Read \\</a>.</p>\n"),
      (
        "[Read \\\\\\] notes](/guide).", "<p><a href=\"/guide\">Read \\] notes</a>.</p>\n",
      ),
      (
        "[**Read** \\] notes](/guide).", "<p><a href=\"/guide\"><strong>Read</strong> ] notes</a>.</p>\n",
      ),
      (
        "[Read \\] notes](/a(b)).", "<p><a href=\"/a(b)\">Read ] notes</a>.</p>\n",
      ),
    ] {
    assert_eq(@markdown.render(source, Map([])), expected)
  }
}

///|
test "escaped label closers respect slices and leave later links active" {
  let source = "xx[Read \\] notes](/guide)yy"
  assert_eq(
    @markdown.parse_inlines(source, 2, source.length() - 2)
    .map(fn(inline) { @markdown.render_inline(inline, Map([])) })
    .join(""),
    "<a href=\"/guide\">Read ] notes</a>",
  )
  assert_false(
    @markdown.parse_inlines(source, 2, 15).any(fn(inline) {
      inline is @markdown.Link(_, _)
    }),
  )
  let malformed = "[open \\] ".repeat(4000)
  assert_true(
    @markdown.render(malformed + "] break [Guide](/guide).", Map([])).has_suffix(
      "<a href=\"/guide\">Guide</a>.</p>\n",
    ),
  )
}

///|
test "escaped closing brackets stay inside image labels" {
  // Literal HTML independently produced by cmark-gfm --unsafe.
  for
    (source, expected) in [
      (
        "![Read \\] notes](/guide.png).", "<p><img src=\"/guide.png\" alt=\"Read ] notes\" />.</p>\n",
      ),
      (
        "![Read \\\\](/guide.png).", "<p><img src=\"/guide.png\" alt=\"Read \\\" />.</p>\n",
      ),
      (
        "![Read \\\\\\] notes](/guide.png).", "<p><img src=\"/guide.png\" alt=\"Read \\] notes\" />.</p>\n",
      ),
      (
        "![\\!notes](/guide.png).", "<p><img src=\"/guide.png\" alt=\"!notes\" />.</p>\n",
      ),
    ] {
    assert_eq(@markdown.render(source, Map([])), expected)
    assert_eq(@markdown.missing_image_alt_urls(source), [])
  }
}
