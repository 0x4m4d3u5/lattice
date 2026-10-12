///|
test "footnote shortcode diagnostics join body diagnostics in declaration order" {
  let rendered = @markdown.render_with_diagnostics(
    "{{< unknown_body >}}\n\nText[^source].\n\n[^source]: **{{< image src=\"/chart.png\" >}}** and {{< image src=\"/chart.png\" alt=\"Chart\" width=\"wide\" >}}\n[^unused]: {{< unknown_note >}}\n",
    Map([]),
  )
  assert_eq(
    rendered.shortcode_errors.map(fn(issue) {
      @shortcode.error_text(issue.error)
    }),
    [
      "unknown shortcode 'unknown_body'", "shortcode 'image' missing param 'alt'",
      "shortcode 'image' param 'width' expected Int", "unknown shortcode 'unknown_note'",
    ],
  )
  assert_eq(rendered.shortcode_errors[1].call.unwrap().name, "image")
}

///|
test "valid and code-example footnote shortcodes keep their literal HTML" {
  let rendered = @markdown.render_with_diagnostics(
    "Text[^source].\n\n[^source]: {{< image src=\"/chart.png\" alt=\"Data chart\" >}} and `{{< image src=\"/example.png\" >}}`\n",
    Map([]),
  )
  assert_eq(rendered.shortcode_errors.length(), 0)
  assert_eq(
    rendered.html,
    "<p>Text<sup><a href=\"#fn-source\" id=\"fnref-source\">[1]</a></sup>.</p>\n\n<section class=\"footnotes\">\n<ol>\n<li id=\"fn-source\"><img src=\"/chart.png\" alt=\"Data chart\" /> and <code>{{&lt; image src=\"/example.png\" &gt;}}</code> <a href=\"#fnref-source\" class=\"footnote-backref\">↩</a></li>\n</ol>\n</section>\n",
  )
}
