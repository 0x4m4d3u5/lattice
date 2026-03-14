///|
test "wikilink extract finds links outside code spans and fences" {
  let src = "See [[guide]] and [[api|API Docs]].\n" +
    "`[[inline-code]]`\n" +
    "```\n" +
    "[[fenced]]\n" +
    "```\n"
  let links = extract(src, "content/docs/index.md")
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
  let links = extract(src, "content/guide.md")
  assert_eq(links.length(), 1)
  assert_eq(links[0].target, "guide page")
  match links[0].display {
    Some(v) => assert_eq(v, "Read next")
    None => assert_true(false)
  }
}

///|
test "wikilink resolve returns canonical urls and broken link errors" {
  let links = extract("[[guide]] and [[missing|Broken]]", "content/index.md")
  let index : Map[String, String] = Map::new()
  index.set("guide", "/guide/")
  let (resolved, errors) = resolve(links, index)
  assert_eq(resolved.length(), 1)
  assert_eq(errors.length(), 1)
  assert_eq(resolved[0].url, "/guide/")
  assert_eq(resolved[0].title, "guide")
  assert_eq(errors[0].link.target, "missing")
  assert_true(errors[0].message.contains("target 'missing' not found"))
}

///|
test "wikilink resolve prefers explicit display text" {
  let links = extract("[[guide|Read this first]]", "content/index.md")
  let index : Map[String, String] = Map::new()
  index.set("guide", "/guide/")
  let (resolved, errors) = resolve(links, index)
  assert_eq(errors.length(), 0)
  assert_eq(resolved.length(), 1)
  assert_eq(resolved[0].title, "Read this first")
}

///|
test "wikilink resolve normalizes title-like targets" {
  let links = extract("[[My Post]] [[10 - Projects]]", "content/index.md")
  let index : Map[String, String] = Map::new()
  index.set("my-post", "/my-post/")
  index.set("10---projects", "/projects/")
  let (resolved, errors) = resolve(links, index)
  assert_eq(errors.length(), 0)
  assert_eq(resolved.length(), 2)
  assert_eq(resolved[0].url, "/my-post/")
  assert_eq(resolved[1].url, "/projects/")
}
