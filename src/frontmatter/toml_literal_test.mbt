///|
test "TOML literal strings preserve exact scalar and nested array values" {
  for
    (raw, expected) in [
      ("'Research notes'", "Research notes"),
      ("'Research, notes [draft]'", "Research, notes [draft]"),
      ("'C:\\notes\\draft\\'", "C:\\notes\\draft\\"),
      ("'\\n\\t\\u0041'", "\\n\\t\\u0041"),
      ("'Keep # literal and \"quotes\"'", "Keep # literal and \"quotes\""),
      ("'  café 🌱\t  '", "  café 🌱\t  "),
      ("''", ""),
      ("'true'", "true"),
      ("'42'", "42"),
      ("'2026-01-02'", "2026-01-02"),
    ] {
    let fm = match @frontmatter.parse("+++\nvalue = " + raw + "\nitems = [" + raw + ", [" + raw + ",],]\n+++\nBody.\n") {
      Ok(fm) => fm
      Err(message) => abort(message)
    }
    guard fm.fields.get("value") is Some(@frontmatter.FStr(value)) else { abort("expected literal string") }
    assert_eq(value, expected)
    guard fm.fields.get("items") is Some(@frontmatter.FArray(items)) else { abort("expected array") }
    assert_eq(items.length(), 2)
    assert_true(items[0] is @frontmatter.FStr(value) && value == expected)
    guard items[1] is @frontmatter.FArray(nested) else { abort("expected nested array") }
    assert_eq(nested.length(), 1)
    assert_true(nested[0] is @frontmatter.FStr(value) && value == expected)
    assert_eq(fm.body, "Body.\n")
  }
}

///|
test "TOML literal strings reject malformed boundaries and forbidden controls" {
  for raw in ["'unterminated", "'a'b", "'it''s'", "['a' 'b']", "['a', 'broken]", "'a\r b'", "'a\u0000b'", "'a\u001fb'", "'a\u007fb'"] {
    match @frontmatter.parse("+++\nvalue = " + raw + "\n+++\n") {
      Err(message) => assert_true(message.contains("value error for 'value'"))
      Ok(_) => abort("invalid literal value must fail")
    }
  }
  // These are valid TOML multiline strings, outside the line-based parser's subset.
  for raw in ["'''literal'''", "''''''"] {
    match @frontmatter.parse("+++\nvalue = " + raw + "\n+++\n") {
      Err(message) => assert_true(message.contains("multiline literal strings are not supported"))
      Ok(_) => abort("unsupported multiline syntax must not become a wrong string")
    }
  }
}
