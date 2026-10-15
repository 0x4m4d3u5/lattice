///|
test "inline HTML retains greater-than signs inside quoted attributes" {
  // Literal expected output independently checked with cmark-gfm --unsafe.
  assert_eq(
    @markdown.render("Before <span title=\"1 > 0\">after</span>.", Map([])),
    "<p>Before <span title=\"1 > 0\">after</span>.</p>\n",
  )
}

///|
test "quoted HTML attributes stay opaque to wikilink extraction" {
  assert_eq(
    @markdown.extract_wikilink_targets(
      "Before <span title=\"1 > [[missing]]\">after</span> [[beta|Guide]].",
    ),
    [("beta", Some("Guide"))],
  )
}

///|
test "both HTML quote styles retain nested quotes and literal backslashes" {
  for
    fragment in [
      "<span title='1 > \"0\"'>after</span>", "<span title=\"1 > '0'\" data-value='2 > 1'>after</span>",
      "<span title=\"x\\\">after</span>", "<img alt='Chart > legend' src='/🌱.png' />",
      "<span title=\"line one\n1 > 0\">after</span>",
    ] {
    assert_eq(
      @markdown.render("Before " + fragment + ".", Map([])),
      "<p>Before " + fragment + ".</p>\n",
    )
  }
}

///|
test "unterminated HTML quotes remain literal within the current inline slice" {
  let body = "Before <span title=\"1 > 0"
  assert_eq(
    @markdown.render(body, Map([])),
    "<p>Before &lt;span title=\"1 &gt; 0</p>\n",
  )
  let source = "<span title=\"1 > 0\">after</span>"
  let end = 17 // excludes the attribute's closing quote
  let inlines = @markdown.parse_inlines(source, 0, end)
  assert_eq(
    inlines.map(@markdown.plain_text_inline).join(""),
    source[:end].to_owned(),
  )
  let malformed = "<span title='".repeat(4000)
  assert_eq(
    @markdown.render("Before " + malformed, Map([])),
    "<p>Before " + "&lt;span title='".repeat(4000) + "</p>\n",
  )
}
