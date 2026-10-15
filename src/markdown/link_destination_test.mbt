///|
test "reference URLs retain balanced parentheses" {
  // Literal expected output independently checked with cmark-gfm --unsafe.
  assert_eq(
    @markdown.render(
      "See [AI](https://en.wikipedia.org/wiki/Artificial_intelligence_(disambiguation)).",
      Map([]),
    ),
    "<p>See <a href=\"https://en.wikipedia.org/wiki/Artificial_intelligence_(disambiguation)\">AI</a>.</p>\n",
  )
}

///|
test "nested and escaped URL parentheses stop at the matching close" {
  for
    (body, expected) in [
      ("[x](/a(b(c(d)))e).", "<p><a href=\"/a(b(c(d)))e\">x</a>.</p>\n"),
      (
        "![Chart](/figures/loss_(train).png).", "<p><img src=\"/figures/loss_(train).png\" alt=\"Chart\" />.</p>\n",
      ),
      ("[x](/a\\(b\\)c).", "<p><a href=\"/a(b)c\">x</a>.</p>\n"),
      ("[x](/a\\)b).", "<p><a href=\"/a)b\">x</a>.</p>\n"),
      ("[x](/a(b)", "<p>[x](/a(b)</p>\n"),
      ("![x](/a(b)", "<p>![x](/a(b)</p>\n"),
      (
        "[x](/a(b)) after [y](/plain).", "<p><a href=\"/a(b)\">x</a> after <a href=\"/plain\">y</a>.</p>\n",
      ),
      (
        "[**Guide**](/notes/(draft)/guide).", "<p><a href=\"/notes/(draft)/guide\"><strong>Guide</strong></a>.</p>\n",
      ),
      (
        "[empty]() and ![empty]().", "<p><a href=\"\">empty</a> and <img src=\"\" alt=\"empty\" />.</p>\n",
      ),
      (
        "[x](/庭/🌱_(draft)?x=1&y=2).", "<p><a href=\"/庭/🌱_(draft)?x=1&amp;y=2\">x</a>.</p>\n",
      ),
    ] {
    assert_eq(@markdown.render(body, Map([])), expected)
  }
}

///|
test "destinations stay opaque to wiki extraction and retain image URLs" {
  let body = "[Guide](/notes/([[missing]])). ![Chart](/images/(chart).png)"
  assert_eq(@markdown.extract_wikilink_targets(body), [])
  assert_eq(@markdown.missing_image_alt_urls(body), [])
  assert_eq(@markdown.missing_image_alt_urls("![](/images/(chart).png)"), [
    "/images/(chart).png",
  ])
}

///|
test "many unmatched destinations leave later valid links active" {
  for token in ["[x](()", "![x](()"] {
    let malformed = token.repeat(4000)
    assert_eq(
      @markdown.render(malformed + " [Guide](/a(b)).", Map([])),
      "<p>" + malformed + " <a href=\"/a(b)\">Guide</a>.</p>\n",
    )
  }
}

///|
test "shared matching keeps deep destinations and respects inline slice bounds" {
  let url = "/a" + "(".repeat(1024) + "b" + ")".repeat(1024)
  assert_eq(
    @markdown.render("[Deep](" + url + ")", Map([])),
    "<p><a href=\"" + url + "\">Deep</a></p>\n",
  )
  let source = "[x](/a(b))"
  let inlines = @markdown.parse_inlines(source, 0, source.length() - 1)
  assert_eq(inlines.map(@markdown.plain_text_inline), ["[x](/a(b)"])
  assert_eq(
    @markdown.render("\\( `(` [**Guide**](/a(b)) [x](/a\\)b).", Map([])),
    "<p>( <code>(</code> <a href=\"/a(b)\"><strong>Guide</strong></a> <a href=\"/a)b\">x</a>.</p>\n",
  )
}
