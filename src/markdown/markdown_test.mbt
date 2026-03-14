///|
fn empty_wl() -> Map[String, String] {
  Map::new()
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
