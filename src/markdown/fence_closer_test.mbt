///|
test "fence-like code lines with trailing text do not close the block" {
  // cmark-gfm keeps every line through the standalone closing fence in code.
  for fence in ["```", "~~~"] {
    let source = fence +
      "\nfirst\n" +
      fence +
      "still code\n[[missing]]\nlast\n" +
      fence +
      "\n\nVisible paragraph."
    let result = @markdown.render_with_diagnostics(source, Map([]))
    assert_eq(
      result.html,
      "<pre><code>first\n" +
      fence +
      "still code\n[[missing]]\nlast</code></pre>\n<p>Visible paragraph.</p>\n",
    )
    assert_eq(@markdown.extract_wikilink_targets(source).length(), 0)
    assert_eq(result.shortcode_errors.length(), 0)
  }
}

///|
test "closing fences allow only delimiter runs and trailing horizontal space" {
  assert_false(@markdown.is_fence_end("```text", '`'))
  assert_false(@markdown.is_fence_end("~~~ text", '~'))
  assert_false(@markdown.is_fence_end("``` \t`", '`'))
  assert_true(@markdown.is_fence_end("```` \t\r", '`'))
  assert_true(@markdown.is_fence_end("~~~~\t", '~'))
}
