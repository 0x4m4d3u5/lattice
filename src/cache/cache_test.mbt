///|
test "cache render and parse roundtrip" {
  let source = render({
    version: 1,
    entries: [
      { slug: "posts/hello", fingerprint: "123" },
      { slug: "about", fingerprint: "456" },
    ],
  })
  let parsed = parse(source) catch {
    ParseFailure(_) => {
      assert_true(false)
      { version: 0, entries: [] }
    }
  }
  assert_eq(parsed.version, 1)
  assert_eq(parsed.entries.length(), 2)
  assert_eq(parsed.entries[0].slug, "posts/hello")
  assert_eq(parsed.entries[0].fingerprint, "123")
}

///|
test "fingerprint changes with source content" {
  let same_a = fingerprint_for_source(
    "content/a.md", "---\ntitle: A\n---\nBody",
  )
  let same_b = fingerprint_for_source(
    "content/a.md", "---\ntitle: A\n---\nBody",
  )
  let changed = fingerprint_for_source(
    "content/a.md", "---\ntitle: A\n---\nBody!",
  )
  assert_eq(same_a, same_b)
  assert_true(same_a != changed)
}

///|
test "cache remember and lookup by slug" {
  let store = empty("./dist")
  remember(store, "hello", "one")
  remember(store, "hello", "two")
  remember(store, "about", "three")
  match lookup(store, "hello") {
    Some(fp) => assert_eq(fp, "two")
    None => assert_true(false)
  }
  match lookup(store, "about") {
    Some(fp) => assert_eq(fp, "three")
    None => assert_true(false)
  }
}
