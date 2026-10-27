///|
test "linked inline image renders an actual clickable thumbnail" {
  assert_eq(
    @markdown.render(
      "[![Garden map](/static/map.png)](/static/map-large.png)",
      Map([]),
    ),
    "<p><a href=\"/static/map-large.png\"><img src=\"/static/map.png\" alt=\"Garden map\" /></a></p>\n",
  )
}

///|
test "linked images preserve labels destinations and surrounding formatting" {
  for
    (source, expected) in [
      (
        "[View ![Map](/map.png) now](/full)", "<p><a href=\"/full\">View <img src=\"/map.png\" alt=\"Map\" /> now</a></p>\n",
      ),
      (
        "[![Map \\] detail](/a(b).png)](/full(c))", "<p><a href=\"/full(c)\"><img src=\"/a(b).png\" alt=\"Map ] detail\" /></a></p>\n",
      ),
      (
        "[![One](/one.png) ![Two](/two.png)](/both)", "<p><a href=\"/both\"><img src=\"/one.png\" alt=\"One\" /> <img src=\"/two.png\" alt=\"Two\" /></a></p>\n",
      ),
      (
        "**[![Map](/map.png)](/full)**", "<p><strong><a href=\"/full\"><img src=\"/map.png\" alt=\"Map\" /></a></strong></p>\n",
      ),
      (
        "[![Map](/a]b.png)](/full)", "<p><a href=\"/full\"><img src=\"/a]b.png\" alt=\"Map\" /></a></p>\n",
      ),
    ] {
    assert_eq(@markdown.render(source, Map([])), expected)
  }
}

///|
test "linked images participate in existing alt validation and plain text" {
  assert_eq(@markdown.missing_image_alt_urls("[![](/blank.png)](/full)"), [
    "/blank.png",
  ])
  assert_eq(@markdown.missing_image_alt_urls("`[![](/code.png)](/full)`"), [])
  assert_eq(
    @markdown.missing_image_alt_urls("```md\n[![](/code.png)](/full)\n```"),
    [],
  )
  assert_eq(@markdown.missing_image_alt_urls("[![Map](/map.png)](/full)"), [])
}

///|
test "linked image matching respects slices escaped openers and malformed recovery" {
  let source = "xx[![Map](/map.png)](/full)yy"
  assert_eq(
    @markdown.parse_inlines(source, 2, source.length() - 2)
    .map(x => @markdown.render_inline(x, Map([])))
    .join(""),
    "<a href=\"/full\"><img src=\"/map.png\" alt=\"Map\" /></a>",
  )
  assert_false(
    @markdown.render("[\\![Map](/map.png)](/full)", Map([])).contains("<img"),
  )
  assert_true(
    @markdown.render("[![broken](unclosed [Guide](/guide)", Map([])).contains(
      "<a href=\"/guide\">Guide</a>",
    ),
  )
  let repeated = "[![Map](/map.png)](/full) ".repeat(1000)
  assert_eq(@markdown.render(repeated, Map([])).split("<img ").length(), 1001)
}

///|
test "linked image text and attributes retain existing escaping" {
  let source = "[![Map & \"detail\"](/map.png?x=1&y=2)](/full?x=1&y=2)"
  let rendered = @markdown.render(source, Map([]))
  assert_true(rendered.contains("src=\"/map.png?x=1&amp;y=2\""))
  assert_true(rendered.contains("href=\"/full?x=1&amp;y=2\""))
  assert_true(rendered.contains("alt=\"Map &amp; &quot;detail&quot;\""))
  let plain = "[![Garden map](/map.png)](/full)"
  assert_eq(
    @markdown.plain_text_inlines(
      @markdown.parse_inlines(plain, 0, plain.length()),
    ),
    "Garden map",
  )
}

///|
test "image-like code does not consume following active links or alt checks" {
  assert_true(
    @markdown.render("`![x](foo` [Guide](/guide) tail)", Map([])).contains(
      "<a href=\"/guide\">Guide</a>",
    ),
  )
  assert_eq(
    @markdown.missing_image_alt_urls("`![x](foo` ![](/blank.png) tail)"),
    ["/blank.png"],
  )
}

///|
test "image-like opaque regions preserve following links and images" {
  for
    prefix in [
      "$![x](foo$", "<span title='![x](foo'>", "<!-- ![x](foo -->", "<https://example.test/![x](foo>",
    ] {
    assert_eq(
      @markdown.render("Before " + prefix + " [Guide](/guide) tail)", Map([])).contains(
        "<a href=\"/guide\">Guide</a>",
      ),
      true,
      msg=prefix,
    )
    assert_eq(
      @markdown.missing_image_alt_urls(
        "Before " + prefix + " ![](/blank.png) tail)",
      ),
      ["/blank.png"],
    )
  }
}

///|
test "literal image labels destinations and shortcode parameters stay literal" {
  assert_true(
    @markdown.render("![Price $5](/price.png) costs $5", Map([])).contains(
      "<img src=\"/price.png\" alt=\"Price $5\" />",
    ),
  )
  for
    source in [
      "[A](/price$5) [Guide](/guide) end$", "Before {{< image src=\"/photo.png\" alt=\"![x](foo\" >}} [Guide](/guide) tail)",
    ] {
    assert_true(
      @markdown.render(source, Map([])).contains("<a href=\"/guide\">Guide</a>"),
    )
  }
  assert_eq(
    @markdown.missing_image_alt_urls(
      "Before {{< image src=\"/photo.png\" alt=\"![x](foo\" >}} ![](/blank.png) tail)",
    ),
    ["/blank.png"],
  )
}

///|
test "literal alt and reference tokens cannot hide later Markdown" {
  for alt in ["Price $5", "`literal", "<span title='", "{{< literal"] {
    let body = "[![" + alt + "](/thumb.png)](/full) [Guide](/guide) $5 ` >}}"
    let html = @markdown.render(body, Map([]))
    assert_true(html.contains("<a href=\"/full\"><img src=\"/thumb.png\""))
    assert_true(html.contains("<a href=\"/guide\">Guide</a>"))
  }
  for
    prefix in [
      "[[![x](foo]]", "[^![x](foo]", "{{< callout >}} ![x](foo {{< /callout >}}",
      "{{< invalid =\"![x](foo\" >}}",
    ] {
    assert_eq(
      @markdown.missing_image_alt_urls(prefix + " ![](/blank.png) tail)"),
      ["/blank.png"],
    )
  }
}

///|
test "opaque matching respects recursive formatting slices" {
  for marker in ["*", "**", "***", "_", "__", "___", "~~"] {
    for opener in ["$5", "`code", "<span title='", "![x](foo"] {
      let prefix = marker + opener + marker
      let suffix = " $5 ` >)"
      assert_true(
        @markdown.render(prefix + " [Guide](/guide)" + suffix, Map([])).contains(
          "<a href=\"/guide\">Guide</a>",
        ),
      )
      assert_eq(
        @markdown.missing_image_alt_urls(prefix + " ![](/blank.png)" + suffix),
        ["/blank.png"],
      )
    }
  }
}
