///|
test "leading H1 boundary preserves duplicate anchors and Unicode" {
  let (result, boundary) = @markdown.render_with_leading_h1_boundary(
    "\n# 🌱 Garden\n\n# 🌱 Garden\n\n## Garden\n",
    Map([]),
  )
  let prefix = "<h1 id=\"garden\">🌱 Garden</h1>\n"
  let suffix = "<h1 id=\"garden-2\">🌱 Garden</h1>\n<h2 id=\"garden-3\">Garden</h2>\n"
  assert_eq(boundary, Some(prefix.length()))
  assert_eq(result.html, prefix + suffix)
  assert_eq(result.toc.length(), 1)
  assert_eq(result.toc[0].anchor, "garden-3")
}

///|
test "only the first top-level block can own the H1 boundary" {
  for
    body in [
      "", "Body.\n\n# Later", "> # Nested", "- # Nested", "## Subtitle", "<h1>Raw</h1>",
    ] {
    let (result, boundary) = @markdown.render_with_leading_h1_boundary(
      body,
      Map([]),
    )
    assert_eq(boundary, None)
    assert_eq(result.html, @markdown.render(body, Map([])))
  }
}

///|
test "leading title keeps footnotes and shortcode diagnostics in the full render" {
  let body = "[^note]: Evidence\n\n# Title[^note] {{< image src=\"/chart.png\" >}}\n\nBody[^note].\n\n## Title\n"
  let (result, boundary) = @markdown.render_with_leading_h1_boundary(
    body,
    Map([]),
  )
  let legacy = @markdown.render_with_diagnostics(body, Map([]))
  assert_eq(result.html, legacy.html)
  assert_eq(result.shortcode_errors.length(), 1)
  assert_eq(legacy.shortcode_errors.length(), 1)
  assert_eq(result.footnotes.length(), 1)
  assert_eq(result.footnotes[0].label, "note")
  assert_eq(result.toc.length(), legacy.toc.length())
  assert_eq(result.toc[0].anchor, legacy.toc[0].anchor)
  let suffix = match boundary {
    Some(end) => result.html[end:].to_owned()
    None => abort("expected leading Markdown H1")
  }
  assert_true(suffix.has_prefix("<p>Body<sup"))
  assert_true(suffix.contains("<li id=\"fn-note\">Evidence"))
  assert_true(suffix.contains("href=\"#fnref-note\""))
}
