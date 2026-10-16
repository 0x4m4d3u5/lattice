///|
test "space hard breaks match cmark across line endings" {
  // Literal cmark-gfm 0.29.0.gfm.13 output, independent of Lattice.
  for ending in ["\r\n", "\n", "\r"] {
    for spaces in ["  ", "    "] {
      let source = "First" + spaces + ending + "Second"
      assert_eq(
        @markdown.render(source, Map([])),
        "<p>First<br />\nSecond</p>\n",
      )
    }
  }
}

///|
test "line endings produce one soft break and preserve code span text" {
  for ending in ["\n", "\r\n", "\r"] {
    assert_eq(
      @markdown.render("First" + ending + "Second", Map([])),
      "<p>First Second</p>\n",
    )
    let code = "`First  " + ending + "Second`"
    let inlines = @markdown.parse_inlines(code, 0, code.length())
    assert_eq(inlines.length(), 1)
    guard inlines[0] is @markdown.InlineCode(text) else {
      abort("expected a literal code span")
    }
    assert_eq(text, "First  " + ending + "Second")
  }
}

///|
test "space break lookbehind and CRLF lookahead stay inside inline slices" {
  let source = "  \nSecond"
  let render_slice = fn(source : String, from : Int, to : Int) {
    @markdown.parse_inlines(source, from, to).map(fn(inline) {
      @markdown.render_inline(inline, Map([]))
    })
  }
  assert_eq(render_slice(source, 1, source.length()), [" ", " ", "Second"])
  let source = "First  \r\nSecond"
  assert_eq(render_slice(source, 0, 8), ["First", "<br />\n"])
  assert_eq(render_slice(source, 0, 9), ["First", "<br />\n"])
}

///|
test "paragraph boundaries ignore trailing spaces and CRLF markers" {
  // Literal cmark-gfm 0.29.0.gfm.13 output for both line-ending forms.
  for ending in ["\r\n", "\n"] {
    for spaces in ["", "  "] {
      let source = "Text" + spaces + ending + ending + "Next" + ending
      assert_eq(@markdown.render(source, Map([])), "<p>Text</p>\n<p>Next</p>\n")
    }
  }
}

///|
test "paragraph endings at EOF never introduce an inline break" {
  // cmark-gfm also discards trailing spaces when there is no final newline.
  for ending in ["\r\n", "\n", ""] {
    for spaces in ["  ", ""] {
      assert_eq(
        @markdown.render("Text" + spaces + ending, Map([])),
        "<p>Text</p>\n",
      )
    }
  }
}

///|
test "paragraph boundary trimming preserves internal code span text" {
  let source = "`Literal  \r\ncode`  \r\n\r\nNext"
  assert_eq(
    @markdown.render(source, Map([])),
    "<p><code>Literal  \r\ncode</code></p>\n<p>Next</p>\n",
  )
}

///|
test "single-line block fields discard terminal CRLF markers" {
  for ending in ["\r\n", "\n"] {
    for spaces in ["", "  "] {
      for
        (source, expected) in [
          ("- Text" + spaces + ending, "<ul>\n<li>Text</li>\n</ul>\n"),
          ("1. Text" + spaces + ending, "<ol>\n<li>Text</li>\n</ol>\n"),
          (
            "Term" + spaces + ending + ": Text" + spaces + ending,
            "<dl>\n<dt>Term</dt>\n<dd>Text</dd>\n</dl>\n",
          ),
          ("$$" + spaces + ending, "<p>$$</p>\n"),
        ] {
        assert_eq(@markdown.render(source, Map([])), expected)
      }
    }
  }
}
