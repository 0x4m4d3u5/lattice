///|
test "nested footnote definitions survive quote and list parsing" {
  // cmark-gfm -e footnotes retains these definitions and resolves their refs.
  for
    source in [
      "Text[^source].\n\n> [^source]: Nested source.\n", "- Text[^source].\n  [^source]: Nested source.\n",
      "1. Text[^source].\n  [^source]: Nested source.\n", "> - Text[^source].\n>   [^source]: Nested source.\n",
    ] {
    let result = @markdown.render_with_diagnostics(source, Map([]))
    assert_eq(result.footnotes.map(fn(note) { note.label }), ["source"])
    assert_true(
      result.html.contains("href=\"#fn-source\" id=\"fnref-source\">[1]</a>"),
    )
    assert_true(result.html.contains("<li id=\"fn-source\">Nested source."))
  }
}

///|
test "nested and outer footnotes retain declaration order and code examples" {
  let source = "Text[^first][^second][^third].\n\n> [^first]: One.\n\n[^second]: Two.\n\n- Item\n  [^third]: Three.\n\n> ```\n> [^literal]: Example only.\n> ```\n"
  let result = @markdown.render_with_diagnostics(source, Map([]))
  assert_eq(result.footnotes.map(fn(note) { note.label }), [
    "first", "second", "third",
  ])
  assert_true(
    result.html.contains("<pre><code>[^literal]: Example only.</code></pre>"),
  )
}
