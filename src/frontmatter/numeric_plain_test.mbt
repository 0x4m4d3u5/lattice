///|
test "numeric-prefixed YAML aliases agree in flow and block lists" {
  // Literal values independently confirmed with PyYAML 6.0.3.
  let expected = ["3D printing", "2026 roadmap", "1.5 release", "-beta notes"]
  for
    value in [
      "[3D printing, 2026 roadmap, 1.5 release, -beta notes]", "\n  - 3D printing\n  - 2026 roadmap\n  - 1.5 release\n  - -beta notes",
    ] {
    let fm = match
      @frontmatter.parse(
        "---\naliases: " +
        value +
        "\nnested: [[3D printing, 2026 roadmap]]\n---\nBody.\n",
      ) {
      Ok(fm) => fm
      Err(message) => abort(message)
    }
    guard fm.fields.get("aliases") is Some(@frontmatter.FArray(items)) else {
      abort("aliases must stay an array")
    }
    assert_eq(items.length(), expected.length())
    for i in 0..<expected.length() {
      guard items[i] is @frontmatter.FStr(value) else {
        abort("expected a string alias")
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
    assert_eq(cells.length(), 2)
    assert_true(cells[0] is @frontmatter.FStr("3D printing"))
    assert_true(cells[1] is @frontmatter.FStr("2026 roadmap"))
    assert_eq(fm.body, "Body.\n")
  }
}

///|
test "numeric scalar types and TOML comma diagnostics are preserved" {
  for
    source in [
      "---\nvalues: [42 , -7\t, 1.5 , 2026-01-02 , true , \"42\"]\n---\n", "+++\nvalues = [42 , -7\t, 1.5 , 2026-01-02 , true , \"42\"]\n+++\n",
    ] {
    let fm = match @frontmatter.parse(source) {
      Ok(fm) => fm
      Err(message) => abort(message)
    }
    guard fm.fields.get("values") is Some(@frontmatter.FArray(items)) else {
      abort("expected typed values")
    }
    assert_eq(items.length(), 6)
    assert_true(items[0] is @frontmatter.FInt(42))
    assert_true(items[1] is @frontmatter.FInt(-7))
    match items[2] {
      @frontmatter.FFloat(value) => assert_eq(value, 1.5)
      _ => abort("expected Float")
    }
    assert_true(items[3] is @frontmatter.FDate("2026-01-02"))
    assert_true(items[4] is @frontmatter.FBool(true))
    assert_true(items[5] is @frontmatter.FStr("42"))
  }
  match @frontmatter.parse("+++\nvalues = [1 2]\n+++\n") {
    Err(message) => assert_true(message.contains("expected ',' or ']'"))
    Ok(_) => abort("TOML missing commas must still be rejected")
  }
}
