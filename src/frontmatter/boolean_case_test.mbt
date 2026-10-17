///|
test "YAML core boolean spellings preserve scalar and flow-list types" {
  // Literal values independently confirmed with PyYAML 6.0.3.
  for
    (word, expected) in [
      ("true", true),
      ("True", true),
      ("TRUE", true),
      ("false", false),
      ("False", false),
      ("FALSE", false),
    ] {
    let fm = match
      @frontmatter.parse(
        "---\nvalue: " +
        word +
        " # comment\nvalues: [" +
        word +
        "]\nblocks:\n  - " +
        word +
        "\n---\nBody.\n",
      ) {
      Ok(fm) => fm
      Err(message) => abort(message)
    }
    guard fm.fields.get("value") is Some(@frontmatter.FBool(value)) else {
      abort("expected a YAML boolean")
    }
    assert_eq(value, expected)
    guard fm.fields.get("values") is Some(@frontmatter.FArray(items)) else {
      abort("expected boolean array")
    }
    assert_eq(items.length(), 1)
    guard items[0] is @frontmatter.FBool(value) else {
      abort("expected array boolean")
    }
    assert_eq(value, expected)
    guard fm.fields.get("blocks") is Some(@frontmatter.FArray(blocks)) else {
      abort("expected block array")
    }
    assert_eq(blocks.length(), 1)
    guard blocks[0] is @frontmatter.FBool(block_value) else {
      abort("expected block boolean")
    }
    assert_eq(block_value, expected)
  }
}

///|
test "quoted prefixed and mixed-case words do not become YAML booleans" {
  for word in ["TrUe", "True-crime", "FALSEhood", "'TRUE'", "\"False\""] {
    let fm = match @frontmatter.parse("---\nvalue: " + word + "\n---\n") {
      Ok(fm) => fm
      Err(message) => abort(message)
    }
    assert_true(fm.fields.get("value") is Some(@frontmatter.FStr(_)))
  }
  for word in ["True", "TRUE", "False", "FALSE"] {
    let fm = match @frontmatter.parse("+++\nvalue = " + word + "\n+++\n") {
      Ok(fm) => fm
      Err(message) => abort(message)
    }
    guard fm.fields.get("value") is Some(@frontmatter.FStr(value)) else {
      abort("TOML spellings must retain their existing type")
    }
    assert_eq(value, word)
  }
}
