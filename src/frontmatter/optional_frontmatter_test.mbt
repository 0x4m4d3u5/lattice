///|
test "missing headers are opt-in and preserve body bytes after a leading BOM" {
  for
    body in [
      "", "\n", "  \r\n# Heading\r\n\r\nBody  \r\n", "# Note\n[[target]]\n", "\n---\nA thematic break",
    ] {
    for prefix in ["", "\ufeff"] {
      let source = prefix + body
      assert_true(@frontmatter.parse(source) is Err(_))
      assert_true(@frontmatter.parse_yaml(source) is Err(_))
      assert_true(@frontmatter.parse_toml(source) is Err(_))
      assert_true(@frontmatter.parse_with_policy(source) is Err(_))
      let fm = @frontmatter.parse_with_policy(
        source,
        allow_missing_frontmatter=true,
      ).unwrap()
      assert_eq(fm.body, body)
      assert_eq(fm.fields.length(), 0)
      assert_true(fm.fields.get("title") is None)
      assert_true(fm.fields.get("visibility") is None)
      let explicit = @frontmatter.parse("---\n---\n" + body).unwrap()
      assert_eq(fm.body, explicit.body)
      assert_eq(explicit.fields.length(), 0)
    }
  }
}

///|
test "recognized headers never fall back and retain duplicate semantics" {
  for
    source in [
      "---", "+++", "---\nbody", "+++\nbody", "---broken\nbody", "+++broken\nbody",
      "---\nbad metadata\n---\n", "+++\nbad metadata\n+++\n", "---\nvisibility: private\nvisibility: public\n---\n",
    ] {
    let strict = @frontmatter.parse(source)
    let optional = @frontmatter.parse_with_policy(
      source,
      allow_missing_frontmatter=true,
    )
    match (strict, optional) {
      (Err(a), Err(b)) => assert_eq(a, b)
      _ => fail("recognized invalid headers must remain errors")
    }
  }
  for
    source in [
      "---\ntitle: First\ntitle: Second\n---\nBody", "+++\ntitle = First\ntitle = Second\n+++\nBody",
    ] {
    let fm = @frontmatter.parse_with_policy(
      source,
      allow_missing_frontmatter=true,
    ).unwrap()
    assert_true(fm.fields.get("title") is Some(@frontmatter.FStr("Second")))
  }
}

///|
test "policy normalizes only one leading BOM and preserves strict default parity" {
  let source = "\ufeff\ufeff---\ntitle: Note\n---\nBody"
  assert_true(@frontmatter.parse(source) is Err(_))
  assert_true(@frontmatter.parse_with_policy(source) is Err(_))
  assert_true(
    @frontmatter.parse_with_policy(source, allow_missing_frontmatter=false)
    is Err(_),
  )
  let fm = @frontmatter.parse_with_policy(
    source,
    allow_missing_frontmatter=true,
  ).unwrap()
  assert_eq(fm.body, "\ufeff---\ntitle: Note\n---\nBody")
  assert_eq(fm.fields.length(), 0)
}
