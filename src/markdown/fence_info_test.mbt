///|
test "backticks in fence info keep the line in ordinary Markdown" {
  // Independent literal output from cmark-gfm --unsafe.
  assert_eq(
    @markdown.render(
      "```bad`info [Guide](/guide/)\n\nVisible paragraph.\n",
      Map([]),
    ),
    "<p>```bad`info <a href=\"/guide/\">Guide</a></p>\n<p>Visible paragraph.</p>\n",
  )
}

///|
test "only backtick fence info rejects backticks" {
  for line in ["```bad`info", "```` bad\\`info", "``` `", "`````🌱`"] {
    assert_false(@markdown.is_fence_start(line))
  }
  for line in ["```", "`````", "```text", "~~~bad`info", "~~~~`"] {
    assert_true(@markdown.is_fence_start(line))
  }
  assert_eq(
    @markdown.render("~~~bad`info\n[[missing]]\n~~~", Map([])),
    "<pre><code class=\"language-bad`info\">[[missing]]</code></pre>\n",
  )
  assert_eq(
    @markdown.extract_wikilink_targets("~~~bad`info\n[[missing]]\n~~~"),
    [],
  )
}

///|
test "invalid fence info keeps nested wiki references active" {
  assert_eq(
    @markdown.extract_wikilink_targets(
      "> ```bad`info\n> [[beta|Guide]]\n\n- ```bad`info\n  [[beta|Nested]]",
    ),
    [("beta", Some("Guide")), ("beta", Some("Nested"))],
  )
}
