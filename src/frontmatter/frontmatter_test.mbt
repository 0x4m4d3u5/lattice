///|
test "frontmatter parses typed values and preserves body (TOML format)" {
  let src = "+++\n" +
    "# comment\n" +
    "title = \"Hello\"\n" +
    "date = 2026-03-11\n" +
    "count = 42\n" +
    "draft = false\n" +
    "tags = [\"moonbit\", \"ssg\"]\n" +
    "slug = \"hello-world\"\n" +
    "+++\n" +
    "Body text\n"
  match @frontmatter.parse(src) {
    Ok(fm) => {
      assert_eq(fm.body, "Body text\n")
      match fm.fields.get("title") {
        Some(FStr(v)) => assert_eq(v, "Hello")
        _ => assert_true(false)
      }
      match fm.fields.get("date") {
        Some(FDate(v)) => assert_eq(v, "2026-03-11")
        _ => assert_true(false)
      }
      match fm.fields.get("count") {
        Some(FInt(v)) => assert_eq(v, 42)
        _ => assert_true(false)
      }
      match fm.fields.get("draft") {
        Some(FBool(v)) => assert_eq(v, false)
        _ => assert_true(false)
      }
      match fm.fields.get("slug") {
        Some(FStr(v)) => assert_eq(v, "hello-world")
        _ => assert_true(false)
      }
      match fm.fields.get("tags") {
        Some(FArray(items)) => {
          assert_eq(items.length(), 2)
          match items[0] {
            FStr(v) => assert_eq(v, "moonbit")
            _ => assert_true(false)
          }
          match items[1] {
            FStr(v) => assert_eq(v, "ssg")
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "frontmatter parses nested arrays and escapes in strings" {
  let src = "+++\n" +
    "matrix = [[1, 2], [3, 4]]\n" +
    "summary = \"line\\nnext\\tindent\\\"quote\\\"\"\n" +
    "+++\n" +
    "\n"
  match @frontmatter.parse(src) {
    Ok(fm) => {
      match fm.fields.get("matrix") {
        Some(FArray(rows)) => {
          assert_eq(rows.length(), 2)
          match rows[0] {
            FArray(first) => {
              assert_eq(first.length(), 2)
              match first[0] {
                FInt(v) => assert_eq(v, 1)
                _ => assert_true(false)
              }
              match first[1] {
                FInt(v) => assert_eq(v, 2)
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
      match fm.fields.get("summary") {
        Some(FStr(v)) => assert_eq(v, "line\nnext\tindent\"quote\"")
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "frontmatter rejects malformed assignments with line context" {
  let src = "+++\n" +
    "# comment\n" +
    "title = \"ok\"\n" +
    "broken = [1 2]\n" +
    "+++\n"
  match @frontmatter.parse(src) {
    Ok(_) => assert_true(false)
    Err(msg) => {
      assert_true(msg.contains("line 3"))
      assert_true(msg.contains("expected ',' or ']' inside array"))
    }
  }
}

///|
test "frontmatter rejects missing closing delimiter" {
  let src = "+++\n" + "title = \"open\"\n"
  match @frontmatter.parse(src) {
    Ok(_) => assert_true(false)
    Err(msg) => assert_eq(msg, "missing closing '+++' delimiter")
  }
}

///|
test "frontmatter parses yaml-style obsidian metadata" {
  let src = "---\n" +
    "title: Home\n" +
    "type: home\n" +
    "created: 2026-03-08\n" +
    "tags:\n" +
    "  - type/moc\n" +
    "  - vault/home\n" +
    "---\n" +
    "Body\n"
  match @frontmatter.parse(src) {
    Ok(fm) => {
      match fm.fields.get("title") {
        Some(FStr(v)) => assert_eq(v, "Home")
        _ => assert_true(false)
      }
      match fm.fields.get("type") {
        Some(FStr(v)) => assert_eq(v, "home")
        _ => assert_true(false)
      }
      match fm.fields.get("created") {
        Some(FDate(v)) => assert_eq(v, "2026-03-08")
        _ => assert_true(false)
      }
      match fm.fields.get("tags") {
        Some(FArray(items)) => {
          assert_eq(items.length(), 2)
          match items[0] {
            FStr(v) => assert_eq(v, "type/moc")
            _ => assert_true(false)
          }
          match items[1] {
            FStr(v) => assert_eq(v, "vault/home")
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
      assert_eq(fm.body, "Body\n")
    }
    Err(_) => assert_true(false)
  }
}

///|
fn parse_frontmatter_or_fail(src : String) -> @frontmatter.Frontmatter {
  match @frontmatter.parse(src) {
    Ok(fm) => fm
    Err(_) => abort("expected frontmatter parse to succeed")
  }
}

///|
test "frontmatter accepts valid date in various positions" {
  // Date in quoted string (TOML)
  let fm1 = parse_frontmatter_or_fail(
    "+++\n" + "date = \"2026-03-11\"\n" + "+++\n",
  )
  match fm1.fields.get("date") {
    Some(FDate(v)) => assert_eq(v, "2026-03-11")
    _ => assert_true(false)
  }

  // Date as bare string (TOML)
  let fm2 = parse_frontmatter_or_fail("+++\n" + "date = 2026-03-11\n" + "+++\n")
  match fm2.fields.get("date") {
    Some(FDate(v)) => assert_eq(v, "2026-03-11")
    _ => assert_true(false)
  }

  // Date in YAML-style single quotes (YAML)
  let fm3 = parse_frontmatter_or_fail(
    "---\n" + "date: '2026-03-11'\n" + "---\n",
  )
  match fm3.fields.get("date") {
    Some(FDate(v)) => assert_eq(v, "2026-03-11")
    _ => assert_true(false)
  }
}

///|
test "frontmatter validates date format strictly" {
  // Invalid month - should be treated as string, not FDate (TOML)
  let fm1 = parse_frontmatter_or_fail(
    "+++\n" + "created = 2026-13-01\n" + "+++\n",
  )
  match fm1.fields.get("created") {
    Some(FStr(v)) => assert_eq(v, "2026-13-01")
    _ => assert_true(false)
  }

  // Invalid day - should be treated as string, not FDate (TOML)
  let fm2 = parse_frontmatter_or_fail(
    "+++\n" + "created = 2026-02-30\n" + "+++\n",
  )
  match fm2.fields.get("created") {
    Some(FStr(v)) => assert_eq(v, "2026-02-30")
    _ => assert_true(false)
  }

  // Wrong separator format (YYYY/MM/DD) - should be treated as string (TOML)
  let fm3 = parse_frontmatter_or_fail(
    "+++\n" + "created = 2026/03/11\n" + "+++\n",
  )
  match fm3.fields.get("created") {
    Some(FStr(v)) => assert_eq(v, "2026/03/11")
    _ => assert_true(false)
  }

  // Too short - should be treated as string (TOML)
  let fm4 = parse_frontmatter_or_fail("+++\n" + "created = 2026-03\n" + "+++\n")
  match fm4.fields.get("created") {
    Some(FStr(v)) => assert_eq(v, "2026-03")
    _ => assert_true(false)
  }

  // Too long - should be treated as string (TOML)
  let fm5 = parse_frontmatter_or_fail(
    "+++\n" + "created = 2026-03-11-extra\n" + "+++\n",
  )
  match fm5.fields.get("created") {
    Some(FStr(v)) => assert_eq(v, "2026-03-11-extra")
    _ => assert_true(false)
  }
}

///|
test "frontmatter parses YAML format with --- delimiters" {
  let src = "---\n" +
    "# comment\n" +
    "title: \"Hello\"\n" +
    "date: 2026-03-11\n" +
    "count: 42\n" +
    "draft: false\n" +
    "tags:\n" +
    "  - moonbit\n" +
    "  - ssg\n" +
    "slug: hello-world\n" +
    "---\n" +
    "Body text\n"
  match @frontmatter.parse(src) {
    Ok(fm) => {
      assert_eq(fm.body, "Body text\n")
      match fm.fields.get("title") {
        Some(FStr(v)) => assert_eq(v, "Hello")
        _ => assert_true(false)
      }
      match fm.fields.get("date") {
        Some(FDate(v)) => assert_eq(v, "2026-03-11")
        _ => assert_true(false)
      }
      match fm.fields.get("count") {
        Some(FInt(v)) => assert_eq(v, 42)
        _ => assert_true(false)
      }
      match fm.fields.get("draft") {
        Some(FBool(v)) => assert_eq(v, false)
        _ => assert_true(false)
      }
      match fm.fields.get("slug") {
        Some(FStr(v)) => assert_eq(v, "hello-world")
        _ => assert_true(false)
      }
      match fm.fields.get("tags") {
        Some(FArray(items)) => {
          assert_eq(items.length(), 2)
          match items[0] {
            FStr(v) => assert_eq(v, "moonbit")
            _ => assert_true(false)
          }
          match items[1] {
            FStr(v) => assert_eq(v, "ssg")
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "frontmatter parses YAML with quoted and unquoted strings" {
  let src = "---\n" +
    "quoted: \"quoted string\"\n" +
    "unquoted: bare string value\n" +
    "single_quoted: 'also quoted'\n" +
    "---\n"
  match @frontmatter.parse(src) {
    Ok(fm) => {
      match fm.fields.get("quoted") {
        Some(FStr(v)) => assert_eq(v, "quoted string")
        _ => assert_true(false)
      }
      match fm.fields.get("unquoted") {
        Some(FStr(v)) => assert_eq(v, "bare string value")
        _ => assert_true(false)
      }
      match fm.fields.get("single_quoted") {
        Some(FStr(v)) => assert_eq(v, "also quoted")
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "frontmatter parses YAML with flow arrays" {
  let src = "---\n" +
    "tags: [a, b, c]\n" +
    "nested: [[1, 2], [3, 4]]\n" +
    "---\n"
  match @frontmatter.parse(src) {
    Ok(fm) => {
      match fm.fields.get("tags") {
        Some(FArray(items)) => {
          assert_eq(items.length(), 3)
          match items[0] {
            FStr(v) => assert_eq(v, "a")
            _ => assert_true(false)
          }
          match items[1] {
            FStr(v) => assert_eq(v, "b")
            _ => assert_true(false)
          }
          match items[2] {
            FStr(v) => assert_eq(v, "c")
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
      match fm.fields.get("nested") {
        Some(FArray(rows)) => {
          assert_eq(rows.length(), 2)
          match rows[0] {
            FArray(first) => {
              assert_eq(first.length(), 2)
              match first[0] {
                FInt(v) => assert_eq(v, 1)
                _ => assert_true(false)
              }
              match first[1] {
                FInt(v) => assert_eq(v, 2)
                _ => assert_true(false)
              }
            }
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "frontmatter parses YAML with block arrays" {
  let src = "---\n" +
    "tags:\n" +
    "  - first\n" +
    "  - second\n" +
    "  - third\n" +
    "---\n"
  match @frontmatter.parse(src) {
    Ok(fm) =>
      match fm.fields.get("tags") {
        Some(FArray(items)) => {
          assert_eq(items.length(), 3)
          match items[0] {
            FStr(v) => assert_eq(v, "first")
            _ => assert_true(false)
          }
          match items[1] {
            FStr(v) => assert_eq(v, "second")
            _ => assert_true(false)
          }
          match items[2] {
            FStr(v) => assert_eq(v, "third")
            _ => assert_true(false)
          }
        }
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "frontmatter detects missing delimiter" {
  let src = "title: \"no delimiter\"\nbody text\n"
  match @frontmatter.parse(src) {
    Ok(_) => assert_true(false)
    Err(msg) => {
      assert_true(msg.contains("missing opening frontmatter delimiter"))
      assert_true(msg.contains("---"))
      assert_true(msg.contains("+++"))
    }
  }
}
