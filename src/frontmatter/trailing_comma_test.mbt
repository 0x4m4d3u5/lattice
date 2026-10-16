///|
test "trailing array commas add no phantom values in YAML or TOML" {
  // Literal values independently confirmed with PyYAML 6.0.3 and tomllib.
  for
    (open, assignment, close) in [
      ("---\n", "values: ", "\n---\nBody.\n"),
      ("+++\n", "values = ", "\n+++\nBody.\n"),
    ] {
    for value in ["[1, 2,]", "[1, 2,   ]", "[1, 2]"] {
      let fm = match @frontmatter.parse(open + assignment + value + close) {
        Ok(fm) => fm
        Err(message) => abort(message)
      }
      guard fm.fields.get("values") is Some(@frontmatter.FArray(items)) else {
        abort("expected an array")
      }
      assert_eq(items.length(), 2)
      assert_true(items[0] is @frontmatter.FInt(1))
      assert_true(items[1] is @frontmatter.FInt(2))
      assert_eq(fm.body, "Body.\n")
    }
    let empty = match
      @frontmatter.parse(open + assignment + "[\"\",]" + close) {
      Ok(fm) => fm
      Err(message) => abort(message)
    }
    guard empty.fields.get("values") is Some(@frontmatter.FArray(items)) else {
      abort("expected an array containing an intentional empty string")
    }
    assert_eq(items.length(), 1)
    assert_true(items[0] is @frontmatter.FStr(""))
    let fm = match
      @frontmatter.parse(open + assignment + "[[1,], [2,],]" + close) {
      Ok(fm) => fm
      Err(message) => abort(message)
    }
    guard fm.fields.get("values") is Some(@frontmatter.FArray(rows)) else {
      abort("expected nested arrays")
    }
    assert_eq(rows.length(), 2)
    for i in 0..<rows.length() {
      guard rows[i] is @frontmatter.FArray(cells) else {
        abort("expected an inner array")
      }
      assert_eq(cells.length(), 1)
      guard cells[0] is @frontmatter.FInt(value) else {
        abort("expected an integer")
      }
      assert_eq(value, i + 1)
    }
  }
}
