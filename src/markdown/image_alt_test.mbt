///|
test "missing image alt uses parsed nested Markdown rather than scanning source" {
  for
    (body, urls) in [
      ("# ![](/heading.png)", ["/heading.png"]),
      (
        "**![](/bold.png)** *![](/italic.png)* ~~![](/strike.png)~~",
        ["/bold.png", "/italic.png", "/strike.png"],
      ),
      (
        "> ![](/quote.png)\n>\n> - ![](/quoted-list.png)",
        ["/quote.png", "/quoted-list.png"],
      ),
      ("- ![](/list.png)\n  - ![](/nested.png)", ["/list.png", "/nested.png"]),
      (
        "| ![](/header.png) |\n| --- |\n| ![](/cell.png) |",
        ["/header.png", "/cell.png"],
      ),
      (
        "Term ![](/term.png)\n: Definition ![](/definition.png)",
        ["/term.png", "/definition.png"],
      ),
      ("Footnote[^n]\n\n[^n]: ![](/footnote.png)", ["/footnote.png"]),
      ("![](/same.png) ![ \t ](/same.png)", ["/same.png", "/same.png"]),
      (
        "![ ](/unicode-space.png) ![星空](/described.png)",
        ["/unicode-space.png"],
      ),
    ] {
    assert_eq(@markdown.missing_image_alt_urls(body), urls)
  }
}

///|
test "missing image alt excludes code math raw HTML and explicit decorative shortcodes" {
  for
    body in [
      "`![](/example.png)`", "```markdown\n![](/example.png)\n```", "> ~~~\n> ![](/example.png)\n> ~~~",
      "$![](/example.png)$", "$$\n![](/example.png)\n$$", "<img src=\"/decorative.png\" alt=\"\">",
      "{{< image src=\"/decorative.png\" alt=\"\" >}}", "![Actual description](/example.png)",
    ] {
    assert_eq(@markdown.missing_image_alt_urls(body), [])
  }
  // Linked inline images use the same Image node and alt policy.
  assert_eq(
    @markdown.missing_image_alt_urls("[![](/linked.png)](/destination)"),
    ["/linked.png"],
  )
  assert_true(
    @markdown.render("[![](/linked.png)](/destination)", Map([])).contains(
      "<img",
    ),
  )
  assert_eq(
    @markdown.render("![](/plain.png)", Map([])),
    "<p><img src=\"/plain.png\" alt=\"\" /></p>\n",
  )
}

///|
test "missing image alt rejects whitespace-only image and figure shortcode values" {
  for name in ["image", "figure"] {
    let body = "{{< " + name + " src=\"/blank.png\" alt=\"   \" >}}"
    assert_true(
      @markdown.render(body, Map([])).contains(
        "src=\"/blank.png\" alt=\"   \"",
      ),
    )
    for
      context in [
        body,
        "**" + body + "**",
        "> " + body,
        "Note[^n]\n\n[^n]: " + body,
      ] {
      assert_eq(@markdown.missing_image_alt_urls(context), ["/blank.png"])
    }
  }
}
