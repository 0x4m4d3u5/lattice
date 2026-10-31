///|
test "Obsidian research callout keeps rich title and nested content" {
  let body = "> [!WARNING] Read **carefully**\n> Evidence in [[source|the source]].\n>\n> - First\n> - Second\n>\n> ## Evidence\n\n## Evidence"
  let html = @markdown.render(body, Map([("source", "/notes/source/")]))
  assert_true(html.contains("class=\"callout callout-warning\""))
  assert_true(html.contains("<strong>carefully</strong>"))
  assert_true(html.contains("href=\"/notes/source/\""))
  assert_true(html.contains("<ul>"))
  assert_true(html.contains("id=\"evidence-2\""))
  assert_false(html.contains("[!WARNING]"))
  let toc = @markdown.extract_table_of_contents(body, 3)
  assert_eq(toc.length(), 2)
  assert_eq(toc[0].anchor, "evidence")
  assert_eq(toc[1].anchor, "evidence-2")
}

///|
test "Obsidian callouts fold natively and nest" {
  let html = @markdown.render("> [!faq]- Question\n> Answer\n>\n> > [!tip]+\n> > Nested answer", Map([]))
  assert_true(html.contains("<details class=\"callout callout-faq\">"))
  assert_true(html.contains("<summary class=\"callout-title\">Question</summary>"))
  assert_true(html.contains("<details class=\"callout callout-tip\" open>"))
  assert_true(html.contains(">Tip</summary>"))
}

///|
test "callout syntax is limited to valid blockquote headers" {
  let html = @markdown.render("[!note] Plain\n\n> Ordinary quote\n> [!tip] not first\n\n> [!bad\"type] Literal\n\n```md\n> [!warning] Code\n```", Map([]))
  assert_false(html.contains("class=\"callout"))
  assert_true(html.contains("<blockquote>"))
  assert_true(html.contains("[!note] Plain"))
}

///|
test "custom callouts have safe default titles and title only bodies" {
  let html = @markdown.render("> [!custom-note]\n\n> [!note] **Title only**", Map([]))
  assert_true(html.contains("class=\"callout callout-custom-note\""))
  assert_true(html.contains(">Custom-note</p>"))
  assert_true(html.contains("<strong>Title only</strong>"))
}

///|
test "callout traversal includes title and body but excludes code" {
  let body = "> [!note] [[title-target]]\n> [[body-target]] ![](body.png)\n>\n> ```md\n> [[not-a-link]]\n> ```"
  let targets = @markdown.extract_wikilink_targets(body)
  assert_eq(targets.length(), 2)
  assert_eq(targets[0].0, "title-target")
  assert_eq(targets[1].0, "body-target")
  assert_eq(@markdown.missing_image_alt_urls(body), ["body.png"])
}

///|
test "callout footnotes and search text retain title and body" {
  let body = "> [!note] A **finding**\n> A measurement[^source].\n>\n> [^source]: Supporting source"
  let (rendered, _, sections) = @markdown.render_with_text_sections(body, Map([]))
  assert_true(rendered.html.contains("class=\"footnotes\""))
  assert_true(rendered.html.contains("Supporting source"))
  assert_true(sections[0].body.contains("finding"))
  assert_true(sections[0].body.contains("measurement"))
  assert_false(sections[0].body.contains("[!note]"))
}
