///|
test "autolinks reject ASCII whitespace and preserve invalid source as text" {
  // Space/tab recognition and literal output independently checked with cmark-gfm.
  for
    (source, expected) in [
      (
        "Before <https://example.test/a b> after.", "<p>Before &lt;https://example.test/a b&gt; after.</p>\n",
      ),
      (
        "<http://example.test/a\tb>", "<p>&lt;http://example.test/a\tb&gt;</p>\n",
      ),
    ] {
    assert_eq(@markdown.render(source, Map([])), expected)
  }
  for separator in ["\n", "\r\n", "\u000c", "\u007f"] {
    assert_false(
      @markdown.render("<https://example.test/a" + separator + "b>", Map([])).contains(
        "<a href",
      ),
    )
  }
  assert_true(
    @markdown.render("<https://example.test/a b>", Map([])).contains("<a href"),
  )
  assert_eq(
    @markdown.render("<https://example.test/a%20b>", Map([])),
    "<p><a href=\"https://example.test/a%20b\">https://example.test/a%20b</a></p>\n",
  )
}

///|
test "invalid nested autolink candidates recover later valid links" {
  let source = "<https://invalid/".repeat(4000) + "<https://valid.test/>"
  assert_eq(
    @markdown.render(source, Map([])),
    "<p>" +
    "&lt;https://invalid/".repeat(4000) +
    "<a href=\"https://valid.test/\">https://valid.test/</a></p>\n",
  )
}
