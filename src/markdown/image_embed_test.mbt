///|
test "wiki image embeds render through explicit asset destinations without page edges" {
  let body = "![[diagram.png]] and [[note]]"
  let rendered = @markdown.render(
    body,
    Map([("![[diagram.png]]", "/static/diagram.png"), ("note", "/note/")]),
  )
  assert_true(
    rendered.contains("<img src=\"/static/diagram.png\" alt=\"diagram.png\""),
  )
  assert_eq(@markdown.extract_wikilink_targets(body), [("note", None)])
}

///|
test "image embeds are parsed only where rendered and fail inert without assets" {
  let body = "`![[code.png]]`\n\n~~~\n![[fence.png]]\n~~~\n\n<!-- ![[comment.png]] -->\n\n\\![[escaped.png]]\n\n**![[real.png]]**\n\n> ![[quoted.png]]"
  assert_eq(@markdown.extract_image_embeds(body), ["real.png", "quoted.png"])
  assert_false(
    @markdown.render("![[https://evil.test/x.png]]", Map([])).contains("<img"),
  )
  assert_true(@markdown.render("![[x.png]]", Map([])).contains("![[x.png]]"))
  let rendered = @markdown.render(
    "![[photo\".png]]",
    Map([("![[photo\".png]]", "/static/photo%22.png")]),
  )
  assert_true(rendered.contains("alt=\"photo&quot;.png\""))
}
