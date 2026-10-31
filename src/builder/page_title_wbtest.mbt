///|
test "visible page title is separate escaped text, not a split document title" {
  let slots = build_template_slots(
    "Pipes | Site & <notes> | Site",
    "",
    "",
    "",
    "/notes/",
    "Site",
    "",
    "",
    "",
    "",
    "https://example.test",
    page_title=Some("Pipes | Site & <notes>"),
  )
  let tpl = @template.parse_template(
    "<title>{{title}}</title><h1>{{page_title}}</h1>",
  ).unwrap()
  assert_eq(
    @template.render_template(tpl, slots, Map([])).unwrap(),
    "<title>Pipes | Site & <notes> | Site</title><h1>Pipes | Site &amp; &lt;notes&gt;</h1>",
  )
  let generated = build_template_slots(
    "Archive", "", "", "", "/archive/", "Site", "", "", "", "", "https://example.test",
  )
  assert_eq(generated.get(@template.PageTitle), Some("Archive"))
}
