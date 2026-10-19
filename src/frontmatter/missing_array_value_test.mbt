///|
test "missing array values never become empty strings" {
  for
    raw in [
      "[,]", "[,1]", "[1,,2]", "[1, ,]", "[[,]]", "[[], , 2]", "[\"a\",,\"b\"]",
    ] {
    match @frontmatter.parse("+++\nvalues = " + raw + "\n+++\n") {
      Err(message) => assert_true(message.contains("expected value before ','"))
      Ok(_) => abort("missing TOML array value must fail: " + raw)
    }
    let fm = match @frontmatter.parse("---\nvalues: " + raw + "\n---\n") {
      Ok(fm) => fm
      Err(message) => abort(message)
    }
    guard fm.fields.get("values") is Some(@frontmatter.FStr(value)) else {
      abort("malformed YAML array must retain whole-value fallback: " + raw)
    }
    assert_eq(value, raw)
  }
}

///|
test "empty and quoted array values remain intentional" {
  for prefix in ["---\nvalues: ", "+++\nvalues = "] {
    let suffix = if prefix.has_prefix("---") { "\n---\n" } else { "\n+++\n" }
    let fm = match @frontmatter.parse(prefix + "[[], \"\", \",\",]" + suffix) {
      Ok(fm) => fm
      Err(message) => abort(message)
    }
    guard fm.fields.get("values") is Some(@frontmatter.FArray(items)) else {
      abort("expected array")
    }
    assert_eq(items.length(), 3)
    guard items[0] is @frontmatter.FArray(empty) else {
      abort("expected empty array")
    }
    assert_eq(empty.length(), 0)
    assert_true(items[1] is @frontmatter.FStr(""))
    assert_true(items[2] is @frontmatter.FStr(","))
  }
}
