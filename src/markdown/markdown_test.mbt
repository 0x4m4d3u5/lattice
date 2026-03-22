///|
fn empty_wl() -> Map[String, String] {
  Map::new()
}

///|
test "flat list still works" {
  let body = "- One\n- Two\n- Three"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<ul>"))
  assert_true(rendered.contains("<li>One</li>"))
  assert_true(rendered.contains("<li>Two</li>"))
  assert_true(rendered.contains("<li>Three</li>"))
  // Exactly one <ul> open tag — no nested lists
  let ul_count = rendered.split("<ul>").to_array().length()
  assert_eq(ul_count, 2)
}

///|
test "markdown toc duplicate headings get unique anchors" {
  let body = "## Repeat!\n\n## Repeat?\n\n### Repeat\n"
  let entries = extract_table_of_contents(body, 3)
  assert_eq(entries.length(), 3)
  assert_eq(entries[0].anchor, "repeat")
  assert_eq(entries[1].anchor, "repeat-2")
  assert_eq(entries[2].anchor, "repeat-3")
}

///|
test "markdown toc depth filter excludes deeper headings" {
  let body = "## Keep\n\n### Skip\n"
  let entries = extract_table_of_contents(body, 2)
  assert_eq(entries.length(), 1)
  assert_eq(entries[0].anchor, "keep")
}

///|
test "markdown toc html renders anchor links" {
  let body = "## Intro & Setup\n\n### API\n"
  let html = render_table_of_contents(extract_table_of_contents(body, 3))
  assert_true(html.contains("<nav class=\"table-of-contents\">"))
  assert_true(html.contains("href=\"#intro-setup\""))
  assert_true(html.contains("class=\"toc-level-2\""))
  assert_true(html.contains("class=\"toc-level-3\""))
}

///|
test "markdown toc html empty for no headings" {
  assert_eq(
    render_table_of_contents(extract_table_of_contents("Plain text only", 3)),
    "",
  )
}

///|
test "markdown image shortcode" {
  let body = "Before {{< image src=\"/img.png\" alt=\"hero\" >}} after"
  let rendered = render_with_diagnostics(body, empty_wl())
  assert_eq(rendered.shortcode_errors.length(), 0)
  assert_true(rendered.html.contains("<img src=\"/img.png\""))
}

///|
test "markdown unknown shortcode" {
  let rendered = render_with_diagnostics("{{< unknown value=1 >}}", empty_wl())
  assert_eq(rendered.shortcode_errors.length(), 1)
  match rendered.shortcode_errors[0].error {
    @shortcode.UnknownShortcode(name) => assert_eq(name, "unknown")
    _ => assert_true(false)
  }
}

///|
test "markdown callout body" {
  let body = "{{< callout type=\"note\" title=\"Heads up\" >}}Body{{< /callout >}}"
  let rendered = render_with_diagnostics(body, empty_wl())
  assert_eq(rendered.shortcode_errors.length(), 0)
  assert_true(rendered.html.contains("callout-note"))
  assert_true(rendered.html.contains("Body"))
}

///|
test "markdown fenced code highlighting recognized language" {
  let body = "```moonbit\nfn main() {\n  let x = 1\n}\n```"
  let rendered = render(body, empty_wl())
  assert_true(
    rendered.contains("<pre class=\"highlight language-moonbit\"><code>"),
  )
  assert_true(rendered.contains("hl-keyword"))
}

///|
test "markdown fenced code unknown language stays plain" {
  let body = "```brainlang\nloop forever\n```"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<pre><code class=\"language-brainlang\">"))
  assert_true(not(rendered.contains("hl-")))
}

///|
test "markdown fenced code empty language stays plain" {
  let body = "```\nplain text\n```"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<pre><code>plain text</code></pre>"))
  assert_true(not(rendered.contains("hl-")))
}

///|
test "markdown table basic" {
  let body = "| Name | Age |\n| ---- | --- |\n| Alice | 30 |\n| Bob | 25 |"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<table>"))
  assert_true(rendered.contains("<thead>"))
  assert_true(rendered.contains("<tbody>"))
  assert_true(rendered.contains("<th>Name</th>"))
  assert_true(rendered.contains("<th>Age</th>"))
  assert_true(rendered.contains("<td>Alice</td>"))
  assert_true(rendered.contains("<td>30</td>"))
  assert_true(rendered.contains("<td>Bob</td>"))
  assert_true(rendered.contains("<td>25</td>"))
}

///|
test "markdown table alignment" {
  let body = "| L | C | R |\n| :--- | :---: | ---: |\n| a | b | c |"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<th style=\"text-align:left\">L</th>"))
  assert_true(rendered.contains("<th style=\"text-align:center\">C</th>"))
  assert_true(rendered.contains("<th style=\"text-align:right\">R</th>"))
  assert_true(rendered.contains("<td style=\"text-align:left\">a</td>"))
  assert_true(rendered.contains("<td style=\"text-align:center\">b</td>"))
  assert_true(rendered.contains("<td style=\"text-align:right\">c</td>"))
}

///|
test "markdown table inline content in cells" {
  let body = "| Feature | Status |\n| --- | --- |\n| **bold** | `code` |"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<strong>bold</strong>"))
  assert_true(rendered.contains("<code>code</code>"))
}

///|
test "markdown table no data rows" {
  let body = "| X | Y |\n| --- | --- |"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<table>"))
  assert_true(rendered.contains("<th>X</th>"))
  assert_true(rendered.contains("<th>Y</th>"))
  assert_true(rendered.contains("<tbody>"))
}

///|
test "non-table pipe line not parsed as table" {
  // A line with | but no separator row should become a paragraph
  let body = "a | b | c\nno separator here"
  let rendered = render(body, empty_wl())
  assert_true(not(rendered.contains("<table>")))
  assert_true(rendered.contains("<p>"))
}

///|
test "markdown image basic" {
  let body = "![hero image](/images/hero.png)"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<img src=\"/images/hero.png\""))
  assert_true(rendered.contains("alt=\"hero image\""))
  assert_true(rendered.contains("/>"))
}

///|
test "markdown image empty alt" {
  let body = "![](/logo.svg)"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<img src=\"/logo.svg\""))
  assert_true(rendered.contains("alt=\"\""))
}

///|
test "markdown image with special chars in alt escaped" {
  let body = "![a & b](/img.png)"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("alt=\"a &amp; b\""))
}

///|
test "markdown image inline in paragraph" {
  let body = "Before ![photo](/p.jpg) after"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<img src=\"/p.jpg\""))
  assert_true(rendered.contains("alt=\"photo\""))
  assert_true(rendered.contains("Before"))
  assert_true(rendered.contains("after"))
}

///|
test "markdown bare exclamation not image" {
  // ! without following [ is literal
  let body = "Hello! World"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("Hello! World"))
  assert_true(not(rendered.contains("<img")))
}

///|
test "strikethrough basic" {
  let body = "~~hello~~"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<del>hello</del>"))
}

///|
test "strikethrough nested inline" {
  let body = "~~**bold**~~"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<del><strong>bold</strong></del>"))
}

///|
test "strikethrough unclosed falls back" {
  let body = "~~hello"
  let rendered = render(body, empty_wl())
  // Unclosed ~~ should be treated as literal text, no <del> tag
  assert_true(not(rendered.contains("<del>")))
  assert_true(rendered.contains("~~hello"))
}

///|
test "task list unchecked" {
  let body = "- [ ] buy milk"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<input type=\"checkbox\" disabled"))
}

///|
test "task list checked" {
  let body = "- [x] done"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<input type=\"checkbox\" checked disabled"))
}

///|
test "task list checked uppercase" {
  let body = "- [X] done"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<input type=\"checkbox\" checked disabled"))
}

///|
test "task list mixed" {
  let body = "- [ ] todo\n- [x] done\n- [ ] another"
  let rendered = render(body, empty_wl())
  // Should have both checked and unchecked checkboxes
  assert_true(rendered.contains("<input type=\"checkbox\" disabled"))
  assert_true(rendered.contains("<input type=\"checkbox\" checked disabled"))
}

///|
test "regular list unaffected" {
  let body = "- plain item"
  let rendered = render(body, empty_wl())
  // Should not have checkbox input
  assert_true(not(rendered.contains("<input")))
  assert_true(rendered.contains("<li>"))
  assert_true(rendered.contains("plain item"))
}

///|
test "footnote single reference and definition" {
  let body = "Text with a footnote[^1].\n\n[^1]: This is the footnote text."
  let rendered = render(body, empty_wl())
  // Check inline reference
  assert_true(
    rendered.contains("<sup><a href=\"#fn-1\" id=\"fnref-1\">[1]</a></sup>"),
  )
  // Check footnotes section
  assert_true(rendered.contains("<section class=\"footnotes\">"))
  assert_true(rendered.contains("<li id=\"fn-1\">This is the footnote text."))
  // Check back-link
  assert_true(rendered.contains("href=\"#fnref-1\""))
  assert_true(rendered.contains("class=\"footnote-backref\">↩</a>"))
}

///|
test "footnote multiple references" {
  let body = "First[^a] and second[^b] footnotes.\n\n[^a]: First note\n[^b]: Second note"
  let rendered = render(body, empty_wl())
  // Check inline references with correct ordinals
  assert_true(
    rendered.contains("<sup><a href=\"#fn-a\" id=\"fnref-a\">[1]</a></sup>"),
  )
  assert_true(
    rendered.contains("<sup><a href=\"#fn-b\" id=\"fnref-b\">[2]</a></sup>"),
  )
  // Check footnotes section
  assert_true(rendered.contains("<li id=\"fn-a\">First note"))
  assert_true(rendered.contains("<li id=\"fn-b\">Second note"))
}

///|
test "footnote declaration order preserved" {
  let body = "Ref[^z] Ref[^a]\n\n[^a]: First defined\n[^z]: Later defined"
  let rendered = render(body, empty_wl())
  // Ordinals follow definition order: [^a] is defined first → 1, [^z] second → 2
  assert_true(rendered.contains("id=\"fnref-a\">[1]</a></sup>"))
  assert_true(rendered.contains("id=\"fnref-z\">[2]</a></sup>"))
  // Footnotes section in definition order: fn-a before fn-z
  assert_true(rendered.contains("<li id=\"fn-a\">First defined"))
  assert_true(rendered.contains("<li id=\"fn-z\">Later defined"))
  // Both footnotes should be in the footnotes section
  assert_true(rendered.contains("<section class=\"footnotes\">"))
}

///|
test "footnote in paragraph" {
  let body = "This is a paragraph with a footnote[^note].\n\n[^note]: The footnote content"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<p>"))
  assert_true(rendered.contains("This is a paragraph with a footnote"))
  assert_true(rendered.contains("<sup><a href=\"#fn-note\""))
  // Footnote definition not in main content
  assert_true(not(rendered.contains("<p>[^note]:")))
}

///|
test "footnote with special characters in label" {
  let body = "Text[^note-123] and more[^note_2].\n\n[^note-123]: Dash\n[^note_2]: Underscore"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("href=\"#fn-note-123\""))
  assert_true(rendered.contains("id=\"fnref-note-123\">[1]</a></sup>"))
  assert_true(rendered.contains("href=\"#fn-note_2\""))
  assert_true(rendered.contains("id=\"fnref-note_2\">[2]</a></sup>"))
}

///|
test "footnote backlink present" {
  let body = "Ref[^1]\n\n[^1]: Note text"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("href=\"#fnref-1\""))
  assert_true(rendered.contains("class=\"footnote-backref\">↩</a>"))
}

///|
test "footnote unresolved reference falls back" {
  let body = "Text[^missing]"
  let rendered = render(body, empty_wl())
  // Unresolved footnote should render as plain text
  assert_true(rendered.contains("[^missing]"))
  assert_true(not(rendered.contains("<sup><a href=\"#fn-missing\"")))
}

///|
test "footnote no section when no definitions" {
  let body = "Text[^1] but no definition"
  let rendered = render(body, empty_wl())
  // Should not have footnotes section
  assert_true(not(rendered.contains("<section class=\"footnotes\">")))
}

///|
test "footnote with inline formatting" {
  let body = "Text[^fmt]\n\n[^fmt]: Note with **bold** and `code`"
  let rendered = render(body, empty_wl())
  assert_true(
    rendered.contains(
      "<li id=\"fn-fmt\">Note with <strong>bold</strong> and <code>code</code>",
    ),
  )
}

///|
test "footnote empty text" {
  let body = "Text[^empty]\n\n[^empty]:"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<li id=\"fn-empty\">"))
}

///|
test "footnote multiline text" {
  let body = "Text[^multi]\n\n[^multi]: Line one\n\nParagraph two"
  let rendered = render(body, empty_wl())
  // Only the first line after the definition is captured
  assert_true(rendered.contains("<li id=\"fn-multi\">Line one"))
}

///|
test "nested unordered list basic" {
  let body = "- Item 1\n  - Nested 1\n  - Nested 2\n- Item 2"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<ul>"))
  // Parent item has nested children so it renders as <li>Item 1<ul>...</ul></li>
  assert_true(rendered.contains("<li>Item 1"))
  assert_true(rendered.contains("<ul>") && rendered.contains("</ul>"))
  assert_true(rendered.contains("<li>Nested 1</li>"))
  assert_true(rendered.contains("<li>Nested 2</li>"))
  assert_true(rendered.contains("<li>Item 2</li>"))
}

///|
test "nested ordered list basic" {
  let body = "1. First\n  2. Nested first\n  2. Nested second\n2. Second"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<ol>"))
  // Parent item has nested children so it renders as <li>First<ol>...</ol></li>
  assert_true(rendered.contains("<li>First"))
  assert_true(rendered.contains("<ol>") && rendered.contains("</ol>"))
  assert_true(rendered.contains("<li>Nested first</li>"))
  assert_true(rendered.contains("<li>Nested second</li>"))
  assert_true(rendered.contains("<li>Second</li>"))
}

///|
test "mixed nested list ul inside ol" {
  let body = "1. Ordered item\n  - Nested unordered\n  - Another nested\n2. Next ordered"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<ol>"))
  // Parent item has nested children so it renders as <li>Ordered item<ul>...</ul></li>
  assert_true(rendered.contains("<li>Ordered item"))
  assert_true(rendered.contains("<ul>"))
  assert_true(rendered.contains("<li>Nested unordered</li>"))
  assert_true(rendered.contains("<li>Another nested</li>"))
  assert_true(rendered.contains("<li>Next ordered</li>"))
}

///|
test "mixed nested list ol inside ul" {
  let body = "- Unordered item\n  1. Nested ordered\n  2. Another nested\n- Next unordered"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<ul>"))
  // Parent item has nested children so it renders as <li>Unordered item<ol>...</ol></li>
  assert_true(rendered.contains("<li>Unordered item"))
  assert_true(rendered.contains("<ol>"))
  assert_true(rendered.contains("<li>Nested ordered</li>"))
  assert_true(rendered.contains("<li>Another nested</li>"))
  assert_true(rendered.contains("<li>Next unordered</li>"))
}

///|
test "nested list with task list item" {
  let body = "- [ ] Parent task\n  - [x] Nested checked\n  - [ ] Nested unchecked"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<input type=\"checkbox\" disabled"))
  assert_true(rendered.contains("<input type=\"checkbox\" checked disabled"))
  assert_true(rendered.contains("Parent task"))
  assert_true(rendered.contains("Nested checked"))
  assert_true(rendered.contains("Nested unchecked"))
}

///|
test "deeply nested lists" {
  let body = "- Level 1\n  - Level 2\n    - Level 3\n- Back to 1"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("Level 1"))
  assert_true(rendered.contains("Level 2"))
  assert_true(rendered.contains("Level 3"))
  assert_true(rendered.contains("Back to 1"))
  // Count ul tags - should have multiple nesting levels
  let ul_count = rendered.split("<ul>").to_array().length()
  assert_true(ul_count >= 2)
}

///|
test "nested list with inline formatting" {
  let body = "- **Bold** item\n  - *Italic* nested\n  - `code` nested"
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<strong>Bold</strong>"))
  assert_true(rendered.contains("<em>Italic</em>"))
  assert_true(rendered.contains("<code>code</code>"))
}

///|
test "definition list basic" {
  let body = "Apple\n:   A fruit that grows on trees."
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<dl>"))
  assert_true(rendered.contains("<dt>Apple</dt>"))
  assert_true(rendered.contains("<dd>A fruit that grows on trees.</dd>"))
  assert_true(rendered.contains("</dl>"))
}

///|
test "definition list multiple definitions per term" {
  let body = "Orange\n:   A citrus fruit.\n:   Also a color."
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<dl>"))
  assert_true(rendered.contains("<dt>Orange</dt>"))
  assert_true(rendered.contains("<dd>A citrus fruit.</dd>"))
  assert_true(rendered.contains("<dd>Also a color.</dd>"))
  assert_true(rendered.contains("</dl>"))
}

///|
test "definition list multiple terms" {
  let body = "Apple\n:   A fruit.\nOrange\n:   A citrus."
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<dl>"))
  assert_true(rendered.contains("<dt>Apple</dt>"))
  assert_true(rendered.contains("<dd>A fruit.</dd>"))
  assert_true(rendered.contains("<dt>Orange</dt>"))
  assert_true(rendered.contains("<dd>A citrus.</dd>"))
  assert_true(rendered.contains("</dl>"))
}

///|
test "definition list followed by paragraph" {
  let body = "Apple\n:   A fruit.\n\nThis is a paragraph."
  let rendered = render(body, empty_wl())
  // Definition list should be complete
  assert_true(rendered.contains("<dl>"))
  assert_true(rendered.contains("<dt>Apple</dt>"))
  assert_true(rendered.contains("</dl>"))
  // Paragraph should follow
  assert_true(rendered.contains("<p>This is a paragraph.</p>"))
}

///|
test "definition list html escaping" {
  let body = "Apple & Banana\n:   A <b>fruit</b> that grows on trees."
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<dt>Apple &amp; Banana</dt>"))
  assert_true(
    rendered.contains(
      "<dd>A &lt;b&gt;fruit&lt;/b&gt; that grows on trees.</dd>",
    ),
  )
}

///|
test "definition list complex" {
  let body = "Apple\n:   A fruit.\n:   Sweet and crunchy.\n\nOrange\n:   A citrus fruit.\n\nThis is a paragraph."
  let rendered = render(body, empty_wl())
  assert_true(rendered.contains("<dl>"))
  assert_true(rendered.contains("<dt>Apple</dt>"))
  assert_true(rendered.contains("<dd>A fruit.</dd>"))
  assert_true(rendered.contains("<dd>Sweet and crunchy.</dd>"))
  assert_true(rendered.contains("<dt>Orange</dt>"))
  assert_true(rendered.contains("<dd>A citrus fruit.</dd>"))
  assert_true(rendered.contains("</dl>"))
  assert_true(rendered.contains("<p>This is a paragraph.</p>"))
}
