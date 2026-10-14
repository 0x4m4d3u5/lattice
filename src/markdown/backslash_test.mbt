///|
test "literal backslashes match cmark-gfm outside punctuation escapes" {
  // Literal HTML from cmark-gfm 0.29.0.gfm.13, independent of Lattice.
  let cases : Array[(String, String)] = [
    ("First\\\nSecond", "<p>First<br />\nSecond</p>\n"),
    (
      "Paths C:\\Users\\notes and C:\\2026\\draft.", "<p>Paths C:\\Users\\notes and C:\\2026\\draft.</p>\n",
    ),
    (
      "Keep \\é \\🌱 and \\ space.", "<p>Keep \\é \\🌱 and \\ space.</p>\n",
    ),
    ("\\*literal\\* and \\\\server", "<p>*literal* and \\server</p>\n"),
    ("`C:\\Users\\notes`", "<p><code>C:\\Users\\notes</code></p>\n"),
    (
      "Keep \\é in **bold \\text**.", "<p>Keep \\é in <strong>bold \\text</strong>.</p>\n",
    ),
  ]
  for pair in cases {
    let (source, expected) = pair
    assert_eq(@markdown.render(source, Map([])), expected)
  }
}

///|
test "backslash CRLF and lone CR produce oracle hard breaks" {
  // Literal cmark-gfm 0.29.0.gfm.13 output for both line-ending forms.
  for source in ["First\\\r\nSecond", "First\\\rSecond"] {
    assert_eq(@markdown.render(source, Map([])), "<p>First<br />\nSecond</p>\n")
  }
}

///|
test "backslash line-ending lookahead stays inside inline slices" {
  let source = "xxFirst\\\r\nSecond"
  let render_slice = fn(to) {
    @markdown.parse_inlines(source, 2, to).map(fn(inline) {
      @markdown.render_inline(inline, Map([]))
    })
  }
  // The CR and LF both fall outside this slice: keep the trailing backslash.
  assert_eq(render_slice(8), ["First\\"])
  // The slice includes the CR but excludes LF: consume only CR.
  assert_eq(render_slice(9), ["First", "<br />\n"])
  assert_eq(render_slice(10), ["First", "<br />\n"])
  let code = "`First\\\r\nSecond`"
  let inlines = @markdown.parse_inlines(code, 0, code.length())
  assert_eq(inlines.length(), 1)
  guard inlines[0] is @markdown.InlineCode(text) else {
    abort("expected a literal code span")
  }
  assert_eq(text, "First\\\r\nSecond")
}
