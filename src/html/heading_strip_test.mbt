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
