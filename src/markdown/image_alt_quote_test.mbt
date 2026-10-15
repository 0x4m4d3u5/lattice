///|
test "image alt quotes stay inside their attribute value" {
  // Literal output independently checked with cmark-gfm --unsafe.
  assert_eq(
    @markdown.render("![He said \"hello\" & waved](/plot.png)", Map([])),
    "<p><img src=\"/plot.png\" alt=\"He said &quot;hello&quot; &amp; waved\" /></p>\n",
  )
}

///|
test "image alt encoding preserves punctuation and Unicode" {
  assert_eq(
    @markdown.render("![A < B & \"C\" 🌱](/plot.png)", Map([])),
    "<p><img src=\"/plot.png\" alt=\"A &lt; B &amp; &quot;C&quot; 🌱\" /></p>\n",
  )
  assert_eq(
    @markdown.missing_image_alt_urls("![He said \"hello\"](/plot.png)"),
    [],
  )
}
