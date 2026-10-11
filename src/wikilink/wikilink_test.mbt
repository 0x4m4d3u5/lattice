///|
test "wikilink extract finds links outside code spans and fences" {
  let src = "See [[guide]] and [[api|API Docs]].\n" +
    "`[[inline-code]]`\n" +
    "```\n" +
    "[[fenced]]\n" +
    "```\n"
  let links = @wikilink.extract(src, "content/docs/index.md")
  assert_eq(links.length(), 2)
  assert_eq(links[0].target, "guide")
  match links[0].display {
    None => ()
    Some(_) => assert_true(false)
  }
  assert_eq(links[0].source_file, "content/docs/index.md")
  assert_eq(links[1].target, "api")
  match links[1].display {
    Some(v) => assert_eq(v, "API Docs")
    None => assert_true(false)
  }
}

///|
test "wikilink extract trims whitespace and ignores empty targets" {
  let src = "[[  guide page  |  Read next  ]] [[   |ignored]] [[   ]]"
  let links = @wikilink.extract(src, "content/guide.md")
  assert_eq(links.length(), 1)
  assert_eq(links[0].target, "guide page")
  match links[0].display {
    Some(v) => assert_eq(v, "Read next")
    None => assert_true(false)
  }
}

///|
test "wikilink resolve returns canonical urls and broken link errors" {
  let links = @wikilink.extract(
    "[[guide]] and [[missing|Broken]]", "content/index.md",
  )
  let index : Map[String, String] = Map([])
  index.set("guide", "/guide/")
  let (resolved, errors) = @wikilink.resolve(links, index)
  assert_eq(resolved.length(), 1)
  assert_eq(errors.length(), 1)
  assert_eq(resolved[0].url, "/guide/")
  assert_eq(resolved[0].title, "guide")
  assert_eq(errors[0].link.target, "missing")
  assert_true(errors[0].message.contains("target 'missing' not found"))
}

///|
test "wikilink resolve prefers explicit display text" {
  let links = @wikilink.extract("[[guide|Read this first]]", "content/index.md")
  let index : Map[String, String] = Map([])
  index.set("guide", "/guide/")
  let (resolved, errors) = @wikilink.resolve(links, index)
  assert_eq(errors.length(), 0)
  assert_eq(resolved.length(), 1)
  assert_eq(resolved[0].title, "Read this first")
}

///|
test "wikilink resolve normalizes title-like targets" {
  let links = @wikilink.extract(
    "[[My Post]] [[10 - Projects]]", "content/index.md",
  )
  let index : Map[String, String] = Map([])
  index.set("my-post", "/my-post/")
  index.set("10---projects", "/projects/")
  let (resolved, errors) = @wikilink.resolve(links, index)
  assert_eq(errors.length(), 0)
  assert_eq(resolved.length(), 2)
  assert_eq(resolved[0].url, "/my-post/")
  assert_eq(resolved[1].url, "/projects/")
}

///|
test "wikilink lookup_key delegates to slug normalization" {
  // lookup_key should behave like filename_to_slug: spaces→hyphens, uppercase→lower
  assert_eq(@wikilink.lookup_key("My Post"), "my-post")
  assert_eq(@wikilink.lookup_key("API Reference"), "api-reference")
  assert_eq(@wikilink.lookup_key("guide"), "guide")
  assert_eq(@wikilink.lookup_key("ABOUT_ME"), "about-me")
}

///|
test "wikilink extract no links in content" {
  let src = "Just a regular paragraph with no wikilinks.\nAnother line."
  let links = @wikilink.extract(src, "content/plain.md")
  assert_eq(links.length(), 0)
}

///|
test "wikilink extract single link no display" {
  let src = "Check out [[getting-started]] for details."
  let links = @wikilink.extract(src, "content/index.md")
  assert_eq(links.length(), 1)
  assert_eq(links[0].target, "getting-started")
  match links[0].display {
    None => ()
    Some(_) => assert_true(false)
  }
}

///|
test "wikilink extract multiple links same line" {
  let src = "See [[alpha]], [[bravo|B]], and [[charlie]]."
  let links = @wikilink.extract(src, "content/multi.md")
  assert_eq(links.length(), 3)
  assert_eq(links[0].target, "alpha")
  assert_eq(links[1].target, "bravo")
  assert_eq(links[2].target, "charlie")
}

///|
test "wikilink extract unclosed brackets at end of content" {
  // Should not panic, should return zero links
  let src = "Some text [[never closed"
  let links = @wikilink.extract(src, "content/broken.md")
  assert_eq(links.length(), 0)
}

///|
test "wikilink extract link at start of content" {
  let src = "[[first-link]] is at the very start."
  let links = @wikilink.extract(src, "content/start.md")
  assert_eq(links.length(), 1)
  assert_eq(links[0].target, "first-link")
}

///|
test "wikilink extract nested code fence second triple backtick closes" {
  // First ``` opens fence, second ``` closes it. Wikilinks inside are skipped,
  // wikilinks after fence are extracted.
  let src = "```\n[[inside-fence]]\n```\n[[outside-fence]]\n"
  let links = @wikilink.extract(src, "content/fence.md")
  assert_eq(links.length(), 1)
  assert_eq(links[0].target, "outside-fence")
}

///|
test "wikilink resolve empty links array returns empty results" {
  let index : Map[String, String] = Map([])
  index.set("guide", "/guide/")
  let (resolved, errors) = @wikilink.resolve([], index)
  assert_eq(resolved.length(), 0)
  assert_eq(errors.length(), 0)
}

///|
test "wikilink resolve empty index makes all links errors" {
  let links = @wikilink.extract("[[a]] [[b]] [[c]]", "content/index.md")
  let index : Map[String, String] = Map([])
  let (resolved, errors) = @wikilink.resolve(links, index)
  assert_eq(resolved.length(), 0)
  assert_eq(errors.length(), 3)
}

///|
test "wikilink resolve lookup uses lookup_key normalization" {
  // Target "My Page" should match index key "my-page" (via lookup_key)
  let links = @wikilink.extract("[[My Page]]", "content/index.md")
  let index : Map[String, String] = Map([])
  index.set("my-page", "/my-page/")
  let (resolved, errors) = @wikilink.resolve(links, index)
  assert_eq(errors.length(), 0)
  assert_eq(resolved.length(), 1)
  assert_eq(resolved[0].url, "/my-page/")
}

///|
test "wikilink resolve display text is title when Some, target when None" {
  let src = "[[explicit|Custom Title]] [[implicit]]"
  let links = @wikilink.extract(src, "content/index.md")
  let index : Map[String, String] = Map([])
  index.set("explicit", "/explicit/")
  index.set("implicit", "/implicit/")
  let (resolved, _) = @wikilink.resolve(links, index)
  assert_eq(resolved[0].title, "Custom Title")
  assert_eq(resolved[1].title, "implicit")
}

///|
test "wikilink resolve multiple errors accumulate as separate entries" {
  let links = @wikilink.extract("[[a]] [[b]] [[c]]", "content/index.md")
  let index : Map[String, String] = Map([])
  index.set("b", "/b/")
  let (resolved, errors) = @wikilink.resolve(links, index)
  assert_eq(resolved.length(), 1)
  assert_eq(errors.length(), 2)
  assert_eq(errors[0].link.target, "a")
  assert_eq(errors[1].link.target, "c")
}

///|
test "wikilink resolve error message contains target name" {
  let links = @wikilink.extract("[[missing-page]]", "content/index.md")
  let index : Map[String, String] = Map([])
  let (_, errors) = @wikilink.resolve(links, index)
  assert_eq(errors.length(), 1)
  assert_true(errors[0].message.contains("missing-page"))
}
