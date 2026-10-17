///|
test "fence language uses the first info word" {
  // Language classes independently confirmed with cmark-gfm --unsafe.
  // Keep Lattice's existing code-body newline convention.
  for fence in ["```", "~~~~"] {
    for
      info in [
        "text title=example.txt", "text\tlinenums", " text   title=example.txt  ",
      ] {
      let source = fence + info + "\n[[missing]]\n" + fence
      assert_eq(
        @markdown.render(source, Map([])),
        "<pre><code class=\"language-text\">[[missing]]</code></pre>\n",
      )
      assert_eq(@markdown.extract_wikilink_targets(source), [])
    }
  }
  assert_eq(
    @markdown.render("~~~🌱 title=example.txt\nhello\n~~~", Map([])),
    "<pre><code class=\"language-🌱\">hello</code></pre>\n",
  )
  assert_eq(
    @markdown.render("~~~text note\nhello\n~~~", Map([])),
    "<pre><code class=\"language-text note\">hello</code></pre>\n",
  )
}

///|
test "additional fence info preserves supported language highlighting" {
  let expected = @markdown.render(
    "```python\ndef greet():\n    return 42\n```",
    Map([]),
  )
  assert_true(expected.contains("class=\"highlight language-python\""))
  for fence in ["```", "~~~~"] {
    assert_eq(
      @markdown.render(
        fence + "python title=demo.py\ndef greet():\n    return 42\n" + fence,
        Map([]),
      ),
      expected,
    )
  }
  assert_eq(
    @markdown.render("~~~ \t\nhello\n~~~", Map([])),
    "<pre><code>hello</code></pre>\n",
  )
}
