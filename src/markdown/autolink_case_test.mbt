///|
test "autolink schemes accept ASCII case variants without changing URL text" {
  // Literal output independently checked with cmark-gfm --unsafe.
  for
    (source, expected) in [
      (
        "<HTTPS://example.test/Guide>", "<p><a href=\"HTTPS://example.test/Guide\">HTTPS://example.test/Guide</a></p>\n",
      ),
      (
        "Before <HtTp://example.test/> after.", "<p>Before <a href=\"HtTp://example.test/\">HtTp://example.test/</a> after.</p>\n",
      ),
      (
        "<MAILTO:user@example.test>", "<p><a href=\"MAILTO:user@example.test\">MAILTO:user@example.test</a></p>\n",
      ),
    ] {
    assert_eq(@markdown.render(source, Map([])), expected)
  }
  assert_eq(@markdown.render("<div>Raw</div>", Map([])), "<div>Raw</div>\n")
  assert_eq(
    @markdown.render("`<HTTPS://example.test/>`", Map([])),
    "<p><code>&lt;HTTPS://example.test/&gt;</code></p>\n",
  )
}
