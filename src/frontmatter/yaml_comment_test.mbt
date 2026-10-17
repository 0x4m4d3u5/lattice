///|
test "YAML trailing comments preserve typed values and quoted hashes" {
  // Expected values independently checked with PyYAML 6.0.3.
  let fm = match
    @frontmatter.parse(
      "---\nfeatured: false # explanation\ncount: 42 # count\ndate: 2026-01-02 # date\ntitle: 'Garden''s # notes' # title\ndouble: \"Literal # value\" # double\nplain: Research, notes # plain\nbare: Gardener's notes # bare\nfragment: https://example.test/#heading\nhash: value#tag\nadjacent: 'literal'#comment\ntags: [ai, 'wiki # notes'] # tags\n---\n# Body # keep\n",
    ) {
    Ok(fm) => fm
    Err(message) => abort(message)
  }
  assert_true(fm.fields.get("featured") is Some(@frontmatter.FBool(false)))
  assert_true(fm.fields.get("count") is Some(@frontmatter.FInt(42)))
  assert_true(fm.fields.get("date") is Some(@frontmatter.FDate("2026-01-02")))
  for
    (key, expected) in [
      ("title", "Garden's # notes"),
      ("double", "Literal # value"),
      ("plain", "Research, notes"),
      ("bare", "Gardener's notes"),
      ("fragment", "https://example.test/#heading"),
      ("hash", "value#tag"),
      ("adjacent", "literal"),
    ] {
    guard fm.fields.get(key) is Some(@frontmatter.FStr(value)) else {
      abort("expected string field")
    }
    assert_eq(value, expected)
  }
  guard fm.fields.get("tags") is Some(@frontmatter.FArray(tags)) else {
    abort("expected tags")
  }
  assert_eq(tags.length(), 2)
  assert_true(tags[0] is @frontmatter.FStr("ai"))
  assert_true(tags[1] is @frontmatter.FStr("wiki # notes"))
  assert_eq(fm.body, "# Body # keep\n")
}

///|
test "YAML comments after block-list keys and items remain separate from values" {
  let fm = match
    @frontmatter.parse(
      "---\ntags: # explanation\n  - alpha # note\n  - 'wiki # notes' # note\n---\nBody.\n",
    ) {
    Ok(fm) => fm
    Err(message) => abort(message)
  }
  guard fm.fields.get("tags") is Some(@frontmatter.FArray(tags)) else {
    abort("expected a block list")
  }
  assert_eq(tags.length(), 2)
  assert_true(tags[0] is @frontmatter.FStr("alpha"))
  assert_true(tags[1] is @frontmatter.FStr("wiki # notes"))
}
