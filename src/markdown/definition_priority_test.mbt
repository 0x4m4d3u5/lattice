///|
test "definition lists yield to headings even before colon-prefixed prose" {
  let source = "Term\n: definition\n## Recovery\n: literal note"
  assert_eq(
    @markdown.render(source, Map([])),
    "<dl>\n<dt>Term</dt>\n<dd>definition</dd>\n</dl>\n<h2 id=\"recovery\">Recovery</h2>\n<p>: literal note</p>\n",
  )
  let toc = @markdown.render_with_diagnostics(source, Map([])).toc
  assert_eq(toc.length(), 1)
  assert_eq(toc[0].anchor, "recovery")
}

///|
test "definition lists yield to fenced examples beginning with colon" {
  assert_eq(
    @markdown.render("Term\n: definition\n~~~\n: literal code\n~~~", Map([])),
    "<dl>\n<dt>Term</dt>\n<dd>definition</dd>\n</dl>\n<pre><code>: literal code</code></pre>\n",
  )
}

///|
test "definition lists preserve following block priority" {
  let prefix = "Term\n: definition\n"
  let rendered_prefix = "<dl>\n<dt>Term</dt>\n<dd>definition</dd>\n</dl>\n"
  for
    tail in [
      "---\n: tail", "- Item\n: tail", "1. Step\n: tail", "> Quote\n: tail",
    ] {
    // A preceding definition list cannot change how a standalone block parses.
    assert_eq(
      @markdown.render(prefix + tail, Map([])),
      rendered_prefix + @markdown.render(tail, Map([])),
    )
  }
}

///|
test "definition lists preserve following footnote definitions" {
  let source = "Term\n: Citation[^source]\n[^source]: Reference text.\n: literal note"
  let rendered = @markdown.render_with_diagnostics(source, Map([]))
  assert_eq(rendered.footnotes.length(), 1)
  assert_eq(rendered.footnotes[0].label, "source")
  assert_eq(rendered.footnotes[0].text, "Reference text.")
  assert_true(rendered.html.contains("<p>: literal note</p>"))
  assert_true(rendered.html.contains("href=\"#fn-source\""))
}

///|
test "inline HTML terms retain their definition-list precedence" {
  assert_eq(
    @markdown.render("<em>Term</em>\n: definition", Map([])),
    "<dl>\n<dt><em>Term</em></dt>\n<dd>definition</dd>\n</dl>\n",
  )
  assert_eq(
    @markdown.render("Initial\n: first\n<em>Term</em>\n: second", Map([])),
    "<dl>\n<dt>Initial</dt>\n<dd>first</dd>\n<dt><em>Term</em></dt>\n<dd>second</dd>\n</dl>\n",
  )
}

///|
test "paragraph footnote boundaries remain unchanged before colon prose" {
  let source = "Intro.[^source]\n[^source]: Reference text.\n: literal note"
  let rendered = @markdown.render_with_diagnostics(source, Map([]))
  assert_eq(rendered.footnotes.length(), 1)
  assert_eq(rendered.footnotes[0].text, "Reference text.")
  assert_true(rendered.html.contains("href=\"#fn-source\""))
  assert_true(rendered.html.contains("<p>: literal note</p>"))
}
