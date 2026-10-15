///|
test "section text shares rendering but uses top-level Markdown boundaries" {
  let source = "Introduction with **emphasis**.\n\n# Manual\n\nOpening.\n\n## Care & Feeding\n\nA <mark>small</mark> garden.\n\n> ### Nested reminder\n> Water daily.\n\n~~~markdown\n## Not a boundary\n~~~\n\n## Care & Feeding\n\nA [seed](/seed/) & soil.\n"
  let (rendered, boundary, sections) = @markdown.render_with_text_sections(
    source,
    Map([]),
  )
  let (ordinary, ordinary_boundary) = @markdown.render_with_leading_h1_boundary(
    source,
    Map([]),
  )
  assert_eq(rendered.html, ordinary.html)
  assert_eq(boundary, ordinary_boundary)
  assert_eq(sections.length(), 4)
  assert_eq(sections[0].heading, "")
  assert_eq(sections[0].body, "Introduction with emphasis.")
  assert_eq(sections[1].heading, "Manual")
  assert_eq(sections[1].body, "Opening.")
  assert_eq(sections[2].heading, "Care & Feeding")
  assert_eq(
    sections[2].body,
    "A small garden. Nested reminder Water daily. ## Not a boundary",
  )
  assert_eq(sections[3].heading, "Care & Feeding")
  assert_eq(sections[3].body, "A seed & soil.")
  assert_true(rendered.html.contains("id=\"care-feeding-2\""))
}

///|
test "empty sections and heading-only sections keep ordinal identity" {
  let (_, _, empty) = @markdown.render_with_text_sections("", Map([]))
  assert_eq(empty.length(), 0)
  let (_, boundary, sections) = @markdown.render_with_text_sections(
    "# Manual\n\n## First\n\n## Second\n",
    Map([]),
  )
  assert_true(boundary is Some(_))
  assert_eq(sections.length(), 3)
  assert_eq(sections[1].heading, "First")
  assert_eq(sections[1].body, "")
  assert_eq(sections[2].heading, "Second")
}

///|
test "comments across headings keep hidden text out of sections" {
  let source = "<!--\n\n## Private heading\n\nprivate marker\n\n-->\n\n## Public\n\nvisible\n"
  let (rendered, _, sections) = @markdown.render_with_text_sections(
    source,
    Map([]),
  )
  // The standalone closing marker is escaped by Markdown, leaving the comment
  // unclosed in the rendered HTML. Preserve the whole-document extraction.
  assert_eq(@strutil.strip_html_tags(rendered.html), "")
  assert_eq(sections.length(), 0)
}

///|
test "visible footnote definitions remain searchable passages" {
  let source = "## Recovery\n\nPractice regularly.[^source]\n\n[^source]: The zirconium protocol documents restoration checksums.\n"
  let (rendered, _, sections) = @markdown.render_with_text_sections(
    source,
    Map([]),
  )
  assert_true(
    @strutil.strip_html_tags(rendered.html).contains("zirconium protocol"),
  )
  assert_eq(sections.length(), 2)
  assert_eq(sections[1].heading, "Footnotes")
  assert_true(sections[1].body.contains("zirconium protocol"))
}

///|
test "closed comments preserve following public sections" {
  let source = "Before.\n\n<!--\n\n## Hidden\n\nsecret\n\n<div>--></div>\n\n## Public\n\nvisible\n"
  let (rendered, _, sections) = @markdown.render_with_text_sections(
    source,
    Map([]),
  )
  assert_eq(@strutil.strip_html_tags(rendered.html), "Before. Public visible")
  assert_eq(sections.length(), 2)
  assert_eq(sections[0].body, "Before.")
  assert_eq(sections[1].heading, "Public")
  assert_eq(sections[1].body, "visible")
}

///|
test "raw text does not turn apparent headings into section labels" {
  for
    tag in [
      "textarea", "script", "style", "title", "xmp", "iframe", "noembed", "noframes",
    ] {
    let source = "<" +
      tag +
      ">\n\n## Literal heading\n\nliteral body\n\n</" +
      tag +
      ">\n\n## Public\n\nvisible\n"
    let (rendered, _, sections) = @markdown.render_with_text_sections(
      source,
      Map([]),
    )
    assert_eq(sections.length(), 2)
    assert_eq(sections[0].heading, "")
    assert_true(sections[0].body.contains("<h2"))
    assert_eq(sections[1].heading, "Public")
    assert_eq(sections[1].body, "visible")
    assert_eq(
      sections[0].body + " Public visible",
      @strutil.strip_html_tags(rendered.html),
    )
  }
}

///|
test "a heading opening raw text stays inside the enclosing passage" {
  let source = "## Public <textarea>\n\nliteral marker\n\n</textarea>\n\n## Next\n\nMore.\n"
  let (rendered, _, sections) = @markdown.render_with_text_sections(
    source,
    Map([]),
  )
  assert_eq(sections.length(), 2)
  assert_eq(sections[0].heading, "")
  assert_true(sections[0].body.contains("literal marker"))
  assert_eq(sections[1].heading, "Next")
  assert_eq(
    sections[0].body + " Next More.",
    @strutil.strip_html_tags(rendered.html),
  )
}
