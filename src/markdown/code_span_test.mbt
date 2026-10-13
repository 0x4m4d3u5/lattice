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

///|
test "multiline code preserves callout examples while a following callout stays active" {
  let rendered = @markdown.render_with_diagnostics(
    "Example ``\n{{< callout type=\"note\" >}}\nLiteral body.\n``.\n\n{{< callout type=\"note\" >}}\nLive body.\n",
    Map([]),
  )
  assert_eq(rendered.shortcode_errors.length(), 0)
  assert_eq(
    rendered.html,
    "<p>Example <code>\n{{&lt; callout type=\"note\" &gt;}}\nLiteral body.\n</code>.</p>\n<aside class=\"callout callout-note\"><p>Live body.</p></aside>\n",
  )
}

///|
test "unmatched code and a paragraph boundary do not disable next-line callouts" {
  let rendered = @markdown.render_with_diagnostics(
    "Unmatched `` opener.\n\n{{< callout type=\"note\" >}}\nLive body.\n",
    Map([]),
  )
  assert_eq(rendered.shortcode_errors.length(), 0)
  assert_eq(
    rendered.html,
    "<p>Unmatched `` opener.</p>\n<aside class=\"callout callout-note\"><p>Live body.</p></aside>\n",
  )
}

///|
test "code ranges inside emphasis preserve literal callout lines" {
  let rendered = @markdown.render_with_diagnostics(
    "**Example ``\n{{< callout type=\"note\" >}}\nLiteral body.\n``**.\n",
    Map([]),
  )
  assert_eq(rendered.shortcode_errors.length(), 0)
  assert_eq(
    rendered.html,
    "<p><strong>Example <code>\n{{&lt; callout type=\"note\" &gt;}}\nLiteral body.\n</code></strong>.</p>\n",
  )
}

///|
test "unmatched runs and backticks in active callout bodies stay active" {
  let unmatched = @markdown.render_with_diagnostics(
    "Unmatched `` opener.\n{{< callout type=\"note\" >}}\nLive body.\n",
    Map([]),
  )
  assert_eq(unmatched.shortcode_errors.length(), 0)
  assert_true(
    unmatched.html.contains(
      "<aside class=\"callout callout-note\"><p>Live body.</p></aside>",
    ),
  )
  let bodies = @markdown.render_with_diagnostics(
    "{{< callout type=\"note\" >}}\nBody `` literal.\n{{< callout type=\"note\" >}}\nLive body.\nTail ``.\n",
    Map([]),
  )
  assert_eq(bodies.shortcode_errors.length(), 0)
  assert_true(
    bodies.html.contains(
      "<aside class=\"callout callout-note\"><p>Body `` literal.</p></aside>",
    ),
  )
  assert_true(
    bodies.html.contains(
      "<aside class=\"callout callout-note\"><p>Live body.</p></aside>",
    ),
  )
}

///|
test "code in a separate footnote definition does not capture a live callout" {
  let rendered = @markdown.render_with_diagnostics(
    "[^example]: Unmatched `` opener.\n{{< callout type=\"note\" >}}\nLive body.\nTail ``.\n",
    Map([]),
  )
  assert_eq(rendered.shortcode_errors.length(), 0)
  assert_true(
    rendered.html.contains(
      "<aside class=\"callout callout-note\"><p>Live body.</p></aside>",
    ),
  )
}

///|
test "multiple code ranges in one paragraph retain their source rows" {
  let rendered = @markdown.render_with_diagnostics(
    "Intro `one`.\nExample ``\n{{< callout type=\"note\" >}}\nLiteral body.\n``.\n",
    Map([]),
  )
  assert_eq(rendered.shortcode_errors.length(), 0)
  assert_eq(
    rendered.html,
    "<p>Intro <code>one</code>. Example <code>\n{{&lt; callout type=\"note\" &gt;}}\nLiteral body.\n</code>.</p>\n",
  )
}

///|
test "active callout block bodies retain legacy expansion behavior" {
  let rendered = @markdown.render_with_diagnostics(
    "{{< callout type=\"note\" >}}\n# Live heading.\n",
    Map([]),
  )
  assert_eq(rendered.shortcode_errors.length(), 0)
  assert_eq(
    rendered.html,
    "<aside class=\"callout callout-note\"><p># Live heading.</p></aside>\n",
  )
}

///|
test "nested code retains callout indentation" {
  let rendered = @markdown.render_with_diagnostics(
    "- Item\n  Example ``\n  {{< callout type=\"note\" >}}\n  Literal body.\n  ``.\n",
    Map([]),
  )
  assert_eq(rendered.shortcode_errors.length(), 0)
  assert_true(
    rendered.html.contains(
      "<code>\n{{&lt; callout type=\"note\" &gt;}}\nLiteral body.\n</code>",
    ),
  )
  assert_false(rendered.html.contains("<aside"))
}

///|
test "a retained block-body expansion invalidates later nested code restoration" {
  let rendered = @markdown.render_with_diagnostics(
    "- Item\n  Example ``\n  {{< callout type=\"note\" >}}\n  # Heading\n  {{< callout type=\"note\" >}}\n  Live body.\n  ``.\n",
    Map([]),
  )
  assert_eq(rendered.shortcode_errors.length(), 0)
  assert_eq(
    rendered.html,
    "<ul>\n<li>Item<p>Example ``</p>\n</li>\n</ul>\n<p><aside class=\"callout callout-note\"><p># Heading</p></aside> <aside class=\"callout callout-note\"><p>Live body.</p></aside>   ``.</p>\n",
  )
}
