///|
test "unequal header and delimiter widths remain paragraphs" {
  // cmark-gfm -e table recognizes neither of these as a table.
  for
    source in [
      "| A | B |\n| --- |\n| C | D |", "| A |\n| --- | --- |\n| C | D |",
    ] {
    let html = @markdown.render(source, Map([]))
    assert_false(html.contains("<table>"))
    assert_true(html.contains("| C | D |</p>"))
  }
}

///|
test "malformed table shapes preserve links in formerly discarded cells" {
  let source = "| Note |\n| --- | --- |\n| Alpha | [[beta]] |"
  let html = @markdown.render(source, Map([("beta", "/posts/beta/")]))
  assert_false(html.contains("<table>"))
  assert_true(html.contains("<a href=\"/posts/beta/\">beta</a>"))
  assert_eq(@markdown.extract_wikilink_targets(source), [("beta", None)])
}

///|
test "matching table headers still pad or truncate body cells" {
  let html = @markdown.render(
    "| A | B |\n| --- | --- |\n| C |\n| D | E | ignored |",
    Map([]),
  )
  assert_true(html.contains("<table>"))
  assert_true(html.contains("<td>C</td>\n<td></td>"))
  assert_true(html.contains("<td>D</td>\n<td>E</td>"))
  assert_false(html.contains("ignored"))
}
