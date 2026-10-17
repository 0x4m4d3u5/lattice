///|
test "single-quoted YAML flow aliases retain commas apostrophes and string types" {
  // Literal values independently confirmed with PyYAML 6.0.3.
  let expected = ["Research, notes", "Garden's 🌱", "true", "42"]
  let fm = match
    @frontmatter.parse(
      "---\naliases: ['Research, notes', 'Garden''s 🌱', 'true', '42']\nnested: [['Research, notes']]\n---\nBody.\n",
    ) {
    Ok(fm) => fm
    Err(message) => abort(message)
  }
  guard fm.fields.get("aliases") is Some(@frontmatter.FArray(items)) else {
    abort("expected an alias array")
  }
  assert_eq(items.length(), expected.length())
  for i in 0..<expected.length() {
    guard items[i] is @frontmatter.FStr(value) else {
      abort("expected a quoted string")
    }
    assert_eq(value, expected[i])
  }
  guard fm.fields.get("nested") is Some(@frontmatter.FArray(rows)) else {
    abort("expected nested arrays")
  }
  assert_eq(rows.length(), 1)
  guard rows[0] is @frontmatter.FArray(cells) else {
    abort("expected an inner array")
  }
  assert_eq(cells.length(), 1)
  assert_true(cells[0] is @frontmatter.FStr("Research, notes"))
  assert_eq(fm.body, "Body.\n")
}
