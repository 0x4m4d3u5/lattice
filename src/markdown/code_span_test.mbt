///|
test "code spans match complete backtick runs and keep shorter runs literal" {
  assert_eq(
    @markdown.render("Use ``[[missing]] ` literal``.\n", Map([])),
    "<p>Use <code>[[missing]] ` literal</code>.</p>\n",
  )
  let rendered = @markdown.render_with_diagnostics(
    "Example ```{{< unknown >}} `` ticks```.\n",
    Map([]),
  )
  assert_eq(
    rendered.html,
    "<p>Example <code>{{&lt; unknown &gt;}} `` ticks</code>.</p>\n",
  )
  assert_eq(rendered.shortcode_errors.length(), 0)
  assert_eq(
    @markdown.render("A `one `` two` B.\n", Map([])),
    "<p>A <code>one `` two</code> B.</p>\n",
  )
}

///|
test "unmatched backtick runs remain literal and do not hide following syntax" {
  assert_eq(@markdown.render("Use ``open.\n", Map([])), "<p>Use ``open.</p>\n")
  assert_eq(@markdown.render("Ticks ``.\n", Map([])), "<p>Ticks ``.</p>\n")
}
