///|
test "leading h1 attributes do not prevent title removal" {
  for opening in [
    "<h1 id=\"title\">",
    "<h1 class='title' id='title'>",
    "<h1 data-label=\"</h1> >\" id=\"title\">",
  ] {
    assert_eq(
      @html.strip_leading_h1(opening + "Title <em>text</em></h1>\n<p>Body.</p>"),
      "<p>Body.</p>",
    )
  }
}

///|
test "heading stripping preserves other tags and incomplete opening tags" {
  for source in [
    "<h10>Title</h1><p>Body.</p>",
    "<h1-extra>Title</h1><p>Body.</p>",
    "<h1 id=\"unfinished>Title</h1><p>Body.</p>",
    "<h1 id=\"title\"",
  ] {
    assert_eq(@html.strip_leading_h1(source), source)
  }
}

///|
test "nested attributes and comments do not close the leading heading" {
  for inner in [
    "<span data-label=\"</h1>\">Title</span>",
    "<span data-label='> </h1>'>Title</span>",
    "Title<!-- > </h1> <script> -->",
    "<span data-label='<script> </h1>'>Title</span>",
    "<script-widget data-label='</h1>'>Title</script-widget>",
  ] {
    assert_eq(
      @html.strip_leading_h1("<h1 id=\"title\">" + inner + "</h1><p>Body</p>"),
      "<p>Body</p>",
    )
  }
}

///|
test "incomplete child markup leaves the heading unchanged" {
  for source in [
    "<h1 id='title'><span data-label='</h1>'>Title</span>",
    "<h1 id='title'><!-- > </h1>",
    "<h1 id='title'><span data-label='</h1>Title",
  ] {
    assert_eq(@html.strip_leading_h1(source), source)
  }
}

///|
test "raw text children conservatively preserve the original heading" {
  for tag in [
    "script", "style", "textarea", "title", "xmp", "iframe", "noembed",
    "noframes", "plaintext", "SCRIPT",
  ] {
    let source = "<h1 id='title'><" + tag + ">literal </h1></" + tag +
      "></h1><p>Body</p>"
    assert_eq(@html.strip_leading_h1(source), source)
  }
}

///|
test "SVG title and style do not trigger HTML raw text fallback" {
  // Chrome DOMParser verifies SVG namespaces and the following paragraph.
  for
    inner in [
      "<svg><title>Icon</title></svg> Title", "<svg><style>.icon{fill:green}</style></svg> Title",
      "<svg><foreignObject><span><svg><title>Icon</title><style>.x{}</style></svg></span></foreignObject></svg>",
      "<svg><title/><style>.x{}</style></svg> Title", "<svg data-label=icon/><title>Icon</title></svg>",
      "<svg><foreignObject><desc><br><svg><title>Icon</title></svg></desc></foreignObject></svg>",
    ] {
    for opening in ["<h1>", "<h1 id='title'>"] {
      assert_eq(
        @html.strip_leading_h1(opening + inner + "</h1><p>Body</p>"),
        "<p>Body</p>",
      )
    }
  }
}

///|
test "SVG integration points retain HTML raw text protections" {
  // Chrome DOMParser verifies the nested title/style/textarea are HTML nodes.
  for
    inner in [
      "<svg><foreignObject><title>literal </h1></title></foreignObject></svg>", "<svg><desc><textarea>literal </h1></textarea></desc></svg>",
      "<svg><title><span><style>.x{content:\"</h1>\"}</style></span></title></svg>",
      "<svg/><style>.x{content:\"</h1>\"}</style>", "<svg hidden/><title>literal </h1></title>",
    ] {
    let source = "<h1>" + inner + "</h1><p>Body</p>"
    assert_eq(@html.strip_leading_h1(source), source)
  }
}

///|
test "optional ruby and option end tags do not block heading removal" {
  // Chrome DOMParser inserts the omitted rt/rp/option end tags.
  for inner in [
    "<ruby>漢<rt>kan</ruby>",
    "<ruby>漢<rp>(<rt>kan<rp>)</ruby>",
    "<select><option>A<option>B</select>",
    "<svg><foreignObject><ruby>漢<rt>kan</ruby></foreignObject></svg>",
  ] {
    for opening in ["<h1>", "<h1 id='title'>"] {
      assert_eq(@html.strip_leading_h1(opening + inner + "</h1><p>Body</p>"), "<p>Body</p>")
    }
  }
}

///|
test "foreign CDATA and declarations do not create element contexts" {
  for inner in [
    "<svg><![CDATA[literal </h1> >]]></svg> Title",
    "<svg><title><![CDATA[literal </h1>]]></title></svg> Title",
    "<svg><style><![CDATA[.x{content:\"</h1>\"}]]></style></svg> Title",
    "<svg><foreignObject><![CDATA[literal </h1>]]></foreignObject></svg> Title",
    "<svg><![CDATA[<script>\"</h1>\"</script>]]></svg> Title",
    "<!DOCTYPE html>Title",
    "<?xml version='1.0'?>Title",
  ] {
    for opening in ["<h1>", "<h1 id='title'>"] {
      assert_eq(@html.strip_leading_h1(opening + inner + "</h1><p>Body</p>"), "<p>Body</p>")
    }
  }
}

///|
test "unclosed or HTML-context CDATA leaves the original input unchanged" {
  for inner in [
    "<svg><![CDATA[literal </h1>",
    "<![CDATA[literal </h1>]]>",
    "<math><![CDATA[literal </h1>]]></math>",
    "<svg><foreignObject><span><![CDATA[literal </h1>]]></span></foreignObject></svg>",
  ] {
    let source = "<h1>" + inner + "</h1><p>Body</p>"
    assert_eq(@html.strip_leading_h1(source), source)
  }
}
