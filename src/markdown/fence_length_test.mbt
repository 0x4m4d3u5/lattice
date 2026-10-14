///|
test "short fences remain literal inside longer code fences" {
  // CommonMark and cmark-gfm require at least the opener width.
  for
    (opener, shorter, closer) in [
      ("````", "```", "````"),
      ("~~~~", "~~~", "~~~~~"),
    ] {
    let source = opener +
      "\n" +
      shorter +
      "\n[[missing]]\n" +
      closer +
      "\n\nVisible paragraph."
    let result = @markdown.render_with_diagnostics(source, Map([]))
    assert_eq(
      result.html,
      "<pre><code>" +
      shorter +
      "\n[[missing]]</code></pre>\n<p>Visible paragraph.</p>\n",
    )
    assert_eq(@markdown.extract_wikilink_targets(source).length(), 0)
  }
}

///|
test "long fence language starts after the full opening run" {
  let html = @markdown.render("````text\nexample\n````", Map([]))
  assert_eq(html, "<pre><code class=\"language-text\">example</code></pre>\n")
}

///|
test "cached fence widths preserve delimiter and trailing space rules" {
  assert_true(@markdown.is_fence_end("```", '`'))
  assert_false(@markdown.is_fence_end_with_width("```", '`', 4))
  assert_false(@markdown.is_fence_end_with_width("```` text", '`', 4))
  assert_false(@markdown.is_fence_end_with_width("~~~~", '`', 4))
  assert_false(@markdown.is_fence_end_with_width("```` \t`", '`', 4))
  assert_true(@markdown.is_fence_end_with_width("````` \t\r", '`', 4))
  assert_true(@markdown.is_fence_end_with_width("~~~~", '~', 4))
}
