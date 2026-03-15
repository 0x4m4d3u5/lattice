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
