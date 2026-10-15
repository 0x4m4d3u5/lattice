///|
test "quoted destinations stay inside link and image URL attributes" {
  // Literal destination expectations independently checked with cmark-gfm.
  assert_eq(
    @markdown.render("[x](/doc\"data-probe=\"yes)", Map([])),
    "<p><a href=\"/doc%22data-probe=%22yes\">x</a></p>\n",
  )
  assert_eq(
    @markdown.render("![x](/img.png\\\"data-probe=\\\"yes)", Map([])),
    "<p><img src=\"/img.png%22data-probe=%22yes\" alt=\"x\" /></p>\n",
  )
}

///|
test "destination encoding preserves existing percent query and Unicode text" {
  for
    (url, attribute) in [
      ("/a\"b?x=%22&plus=a+b#frag", "/a%22b?x=%22&amp;plus=a+b#frag"),
      (
        "/a%22/%2f/%25/%zz?x=a+b&y=%20#frag", "/a%22/%2f/%25/%zz?x=a+b&amp;y=%20#frag",
      ),
      ("/庭/🌱?q=土&x=%22", "/庭/🌱?q=土&amp;x=%22"),
      ("/a'b?x=1&y=2", "/a'b?x=1&amp;y=2"),
    ] {
    assert_eq(
      @markdown.render("[x](" + url + ")", Map([])),
      "<p><a href=\"" + attribute + "\">x</a></p>\n",
    )
    assert_eq(
      @markdown.render("![x](" + url + ")", Map([])),
      "<p><img src=\"" + attribute + "\" alt=\"x\" /></p>\n",
    )
  }
}

///|
test "autolinks and wikilink URL maps use the same destination encoding" {
  assert_eq(
    @markdown.render("<https://example.test/a\"b?x=%22&plus=a+b#frag>", Map([])),
    "<p><a href=\"https://example.test/a%22b?x=%22&amp;plus=a+b#frag\">https://example.test/a\"b?x=%22&amp;plus=a+b#frag</a></p>\n",
  )
  assert_eq(
    @markdown.render(
      "[[soil|Guide]]",
      Map([("soil", "/wiki\"data-probe=\"yes?x=%2f&plus=a+b#frag")]),
    ),
    "<p><a href=\"/wiki%22data-probe=%22yes?x=%2f&amp;plus=a+b#frag\">Guide</a></p>\n",
  )
}
