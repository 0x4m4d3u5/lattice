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
