///|
test "thematic breaks accept repeated markers and horizontal spacing" {
  // Literal HTML independently checked with cmark-gfm 0.29.0.gfm.13 --unsafe.
  for
    rule in [
      "----", "*****", "______", "- - -", "* * *", "_ _ _", "*\t*\t*", "   *****  ",
    ] {
    assert_true(@markdown.is_hrule(rule))
    for ending in ["", "\n", "\r\n"] {
      assert_eq(@markdown.render(rule + ending, Map([])), "<hr />\n")
    }
  }
  assert_eq(
    @markdown.render("Before.\n* * *\nAfter.", Map([])),
    "<p>Before.</p>\n<hr />\n<p>After.</p>\n",
  )
  assert_eq(
    @markdown.render("> Before.\n>\n> * * *\n>\n> After.", Map([])),
    "<blockquote>\n<p>Before.</p>\n<hr />\n<p>After.</p>\n</blockquote>\n",
  )
}

///|
test "thematic breaks reject short mixed escaped and nonspace markers" {
  for
    line in [
      "", "--", "* *", "_ _", "-*-", "* _ *", "*** text", "\\* * *", "* * *", "_x__",
    ] {
    assert_false(@markdown.is_hrule(line))
  }
  for source in ["`* * *`", "```\n* * *\n```", "~~~\n----\n~~~"] {
    assert_false(@markdown.render(source, Map([])).contains("<hr"))
  }
}

///|
test "thematic breaks take precedence over list continuation" {
  // Literal cmark-gfm output: a divider separates the two lists.
  for marker in ["*", "-"] {
    let source = marker +
      " Before.\n" +
      marker +
      " " +
      marker +
      " " +
      marker +
      "\n" +
      marker +
      " After."
    assert_eq(
      @markdown.render(source, Map([])),
      "<ul>\n<li>Before.</li>\n</ul>\n<hr />\n<ul>\n<li>After.</li>\n</ul>\n",
    )
  }
}
