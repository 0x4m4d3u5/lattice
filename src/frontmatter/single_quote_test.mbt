///|
test "YAML single-quoted scalar and block-list values decode doubled apostrophes" {
  // The first literal is YAML 1.2.2 example 7.7, independent of Lattice.
  for
    (source, expected) in [
      ("'here''s to \"quotes\"'", "here's to \"quotes\""),
      ("'it''s Justin''s notes'", "it's Justin's notes"),
      ("''''", "'"),
      ("''''''", "''"),
      ("'C:\\notes\\draft and ''quotes'''", "C:\\notes\\draft and 'quotes'"),
      ("'  café ''🌱''  '", "  café '🌱'  "),
      ("''", ""),
    ] {
    let fm = match
      @frontmatter.parse(
        "---\ntitle: " + source + "\ntags:\n  - " + source + "\n---\nBody.\n",
      ) {
      Ok(fm) => fm
      Err(message) => abort(message)
    }
    guard fm.fields.get("title") is Some(@frontmatter.FStr(title)) else {
      abort("expected a string title")
    }
    assert_eq(title, expected)
    guard fm.fields.get("tags") is Some(@frontmatter.FArray(items)) else {
      abort("expected a tag array")
    }
    assert_eq(items.length(), 1)
    guard items[0] is @frontmatter.FStr(tag) else {
      abort("expected a string tag")
    }
    assert_eq(tag, expected)
    assert_eq(fm.body, "Body.\n")
  }
}

///|
test "apostrophe pairs remain literal outside YAML single quotes" {
  for
    source in [
      "---\ntitle: rock''roll\n---\n", "---\ntitle: \"rock''roll\"\n---\n", "+++\ntitle = \"rock''roll\"\n+++\n",
    ] {
    let fm = match @frontmatter.parse(source) {
      Ok(fm) => fm
      Err(message) => abort(message)
    }
    guard fm.fields.get("title") is Some(@frontmatter.FStr(title)) else {
      abort("expected a string title")
    }
    assert_eq(title, "rock''roll")
  }
}
