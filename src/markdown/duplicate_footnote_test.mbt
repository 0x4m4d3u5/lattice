///|
test "duplicate footnote labels keep the first definition and ordinal" {
  // cmark-gfm -e footnotes independently keeps First text and Other text.
  let source = "Ref[^a] then[^b].\n\n[^a]: First text\n[^b]: Other text\n[^a]: Shadowed text"
  let rendered = @markdown.render(source, Map([]))
  assert_eq(
    rendered,
    "<p>Ref<sup><a href=\"#fn-a\" id=\"fnref-a\">[1]</a></sup> then<sup><a href=\"#fn-b\" id=\"fnref-b\">[2]</a></sup>.</p>\n" +
    "\n<section class=\"footnotes\">\n<ol>\n" +
    "<li id=\"fn-a\">First text <a href=\"#fnref-a\" class=\"footnote-backref\">↩</a></li>\n" +
    "<li id=\"fn-b\">Other text <a href=\"#fnref-b\" class=\"footnote-backref\">↩</a></li>\n</ol>\n</section>\n",
  )
}

///|
test "first footnote definitions win across nested and root blocks" {
  let (_, footnotes) = @markdown.parse_blocks_with_footnotes([
    "> [^a]: Nested first", "[^b]: Root second", "[^a]: Root shadow", "> [^b]: Nested shadow",
  ])
  assert_eq(footnotes.length(), 2)
  assert_eq(footnotes[0].label, "a")
  assert_eq(footnotes[0].text, "Nested first")
  assert_eq(footnotes[1].label, "b")
  assert_eq(footnotes[1].text, "Root second")
}

///|
test "wikilink extraction follows the retained footnote definition" {
  let targets = @markdown.extract_wikilink_targets(
    "Ref[^a].\n\n[^a]: See [[soil]].\n[^a]: Shadow [[missing]].",
  )
  assert_eq(targets, [("soil", None)])
  let targets = @markdown.extract_wikilink_targets(
    "Ref[^a].\n\n[^a]: See [[missing]].\n[^a]: Shadow [[soil]].",
  )
  assert_eq(targets, [("missing", None)])
}
