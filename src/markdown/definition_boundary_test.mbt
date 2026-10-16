///|
test "orphan definition markers remain literal paragraphs" {
  for
    (source, expected) in [
      (": orphan definition", "<p>: orphan definition</p>\n"),
      (": ", "<p>: </p>\n"),
      (": orphan\n\nAfter.", "<p>: orphan</p>\n<p>After.</p>\n"),
      ("## Guide\n: orphan", "<h2 id=\"guide\">Guide</h2>\n<p>: orphan</p>\n"),
    ] {
    assert_eq(@markdown.render(source, Map([])), expected)
  }
}

///|
test "paragraph stops before a definition term and preserves following prose" {
  let source = "Introduction.\nTerm\n: A **definition**.\n\nAfter."
  assert_eq(
    @markdown.render(source, Map([])),
    "<p>Introduction.</p>\n<dl>\n<dt>Term</dt>\n<dd>A <strong>definition</strong>.</dd>\n</dl>\n<p>After.</p>\n",
  )
}

///|
test "orphan definition markers terminate inside nested blocks" {
  assert_eq(
    @markdown.render("> : orphan", Map([])),
    "<blockquote>\n<p>: orphan</p>\n</blockquote>\n",
  )
  assert_eq(
    @markdown.render("- Item\n  : orphan", Map([])),
    "<ul>\n<li>Item<p>: orphan</p>\n</li>\n</ul>\n",
  )
}
