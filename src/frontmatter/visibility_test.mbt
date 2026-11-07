///|
test "duplicate visibility is rejected without changing other duplicate fields" {
  for (fence, separator) in [("---", ":"), ("+++", "=")] {
    for first in ["private", "public", "true"] {
      let source = fence + "\nvisibility " + separator + " " + first +
        "\nvisibility " + separator + " public\n" + fence + "\n"
      match @frontmatter.parse(source) {
        Err(message) => assert_eq(message, "line 2: duplicate visibility field")
        Ok(_) => fail("duplicate visibility must not use last assignment wins")
      }
    }
    let other = fence + "\ntitle " + separator + " First\ntitle " +
      separator + " Second\n" + fence + "\n"
    match @frontmatter.parse(other) {
      Ok(fm) => match fm.fields.get("title") {
        Some(@frontmatter.FStr(title)) => assert_eq(title, "Second")
        _ => fail("expected existing title semantics")
      }
      Err(_) => fail("ordinary duplicate metadata remains compatible")
    }
  }
}

///|
test "quoted visibility keys normalize and reject mixed duplicates" {
  for (fence, separator) in [("---", ":"), ("+++", "=")] {
    for key in ["\"visibility\"", "'visibility'"] {
      let prefix = fence + "\n" + key + " " + separator + " private\n"
      match @frontmatter.parse(prefix + fence + "\n") {
        Ok(fm) => match fm.fields.get("visibility") {
          Some(@frontmatter.FStr(value)) => assert_eq(value, "private")
          _ => fail("quoted reserved key must normalize")
        }
        Err(_) => fail("quoted visibility should parse")
      }
      match @frontmatter.parse(prefix + "visibility " + separator + " public\n" + fence + "\n") {
        Err(message) => assert_eq(message, "line 2: duplicate visibility field")
        Ok(_) => fail("mixed key spellings must not override private intent")
      }
    }
  }
}
