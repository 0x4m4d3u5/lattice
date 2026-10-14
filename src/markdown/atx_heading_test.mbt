///|
test "ATX delimiters are excluded from heading text" {
  // CommonMark ATX examples and cmark-gfm independently define these contents.
  for
    (source, text, anchor) in [
      ("## Guide ###", "Guide", "guide"),
      ("##\tGuide\t#####\t", "Guide", "guide"),
      ("##", "", "section"),
      ("## ###", "", "section"),
    ] {
    assert_eq(
      @markdown.render(source, Map([])),
      "<h2 id=\"" + anchor + "\">" + text + "</h2>\n",
    )
    let entries = @markdown.extract_table_of_contents(source, 3)
    assert_eq(entries.length(), 1)
    assert_eq(entries[0].text, text)
  }
}

///|
test "literal and escaped hashes remain heading content" {
  for
    (source, text) in [
      ("## Guide###", "Guide###"),
      ("## Guide \\###", "Guide ###"),
      ("## Guide #\\##", "Guide ###"),
      ("## Guide ### more", "Guide ### more"),
    ] {
    let entries = @markdown.extract_table_of_contents(source, 3)
    assert_eq(entries.length(), 1)
    assert_eq(entries[0].text, text)
  }
  assert_false(@markdown.is_heading_line("##Guide"))
  assert_false(@markdown.is_heading_line("####### Guide"))
}

///|
test "empty ATX headings accept LF and CRLF terminators" {
  // cmark-gfm emits an empty heading for EOF, LF, CRLF, and trailing CR.
  for ending in ["", "\n", "\r\n", "\r"] {
    for
      (hashes, level) in [
        ("#", "1"),
        ("##", "2"),
        ("###", "3"),
        ("####", "4"),
        ("#####", "5"),
        ("######", "6"),
      ] {
      let source = hashes + ending
      assert_eq(
        @markdown.render(source, Map([])),
        "<h" + level + " id=\"section\"></h" + level + ">\n",
      )
    }
    for heading in ["## ", "##\t", "## ###"] {
      assert_eq(
        @markdown.render(heading + ending, Map([])),
        "<h2 id=\"section\"></h2>\n",
      )
    }
    let entries = @markdown.extract_table_of_contents("##" + ending, 3)
    assert_eq(entries.length(), 1)
    assert_eq(entries[0].text, "")
  }
  assert_false(@markdown.is_heading_line("##\rtext"))
}
