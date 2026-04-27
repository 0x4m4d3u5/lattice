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

///|
test "frontmatter parses float values in TOML format" {
  let src = "+++\n" +
    "rating = 4.5\n" +
    "price = 9.99\n" +
    "weight = -1.2\n" +
    "+++\n" +
    "Body\n"
  match @frontmatter.parse(src) {
    Ok(fm) => {
      match fm.fields.get("rating") {
        Some(FFloat(v)) => assert_true((v - 4.5).abs() < 0.0001)
        _ => assert_true(false)
      }
      match fm.fields.get("price") {
        Some(FFloat(v)) => assert_true((v - 9.99).abs() < 0.0001)
        _ => assert_true(false)
      }
      match fm.fields.get("weight") {
        Some(FFloat(v)) => assert_true((v - -1.2).abs() < 0.0001)
        _ => assert_true(false)
      }
      assert_eq(fm.body, "Body\n")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "frontmatter parses float values in YAML format" {
  let src = "---\n" + "rating: 4.5\n" + "lat: 39.1031\n" + "---\n" + "Body\n"
  match @frontmatter.parse(src) {
    Ok(fm) => {
      match fm.fields.get("rating") {
        Some(FFloat(v)) => assert_true((v - 4.5).abs() < 0.0001)
        _ => assert_true(false)
      }
      match fm.fields.get("lat") {
        Some(FFloat(v)) => assert_true((v - 39.1031).abs() < 0.0001)
        _ => assert_true(false)
      }
      assert_eq(fm.body, "Body\n")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "frontmatter distinguishes float from int" {
  let src = "+++\n" + "count = 42\n" + "rating = 4.5\n" + "+++\n"
  match @frontmatter.parse(src) {
    Ok(fm) => {
      match fm.fields.get("count") {
        Some(FInt(v)) => assert_eq(v, 42)
        _ => assert_true(false)
      }
      match fm.fields.get("rating") {
        Some(FFloat(v)) => assert_true((v - 4.5).abs() < 0.0001)
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "yaml frontmatter with = separator gives actionable error" {
  // Using --- delimiters with TOML-style key = value is a common mistake.
  // The error should hint at using +++ delimiters or switching to key: value.
  let src = "---\ntitle = \"Hello\"\n---\nbody"
  match @frontmatter.parse(src) {
    Ok(_) => assert_true(false)
    Err(e) => {
      assert_true(e.contains("+++ delimiters"))
      assert_true(e.contains("TOML"))
    }
  }
}

///|
test "yaml frontmatter missing colon gives clear error" {
  let src = "---\ntitle\n---\nbody"
  match @frontmatter.parse(src) {
    Ok(_) => assert_true(false)
    Err(e) => assert_true(e.contains("':' separator"))
  }
}

///|
test "frontmatter empty TOML block produces empty fields and preserves body" {
  let src = "+++\n+++\nbody text here\n"
  match @frontmatter.parse(src) {
    Ok(fm) => {
      assert_eq(fm.fields.length(), 0)
      assert_eq(fm.body, "body text here\n")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "frontmatter empty YAML block produces empty fields and preserves body" {
  let src = "---\n---\nbody text here\n"
  match @frontmatter.parse(src) {
    Ok(fm) => {
      assert_eq(fm.fields.length(), 0)
      assert_eq(fm.body, "body text here\n")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "frontmatter TOML boolean true parses as FBool(true)" {
  // Tests only covered false before — true is a separate branch in parse_value_at
  let src = "+++\ndraft = true\npublished = false\n+++\n"
  match @frontmatter.parse(src) {
    Ok(fm) => {
      match fm.fields.get("draft") {
        Some(FBool(v)) => assert_eq(v, true)
        _ => assert_true(false)
      }
      match fm.fields.get("published") {
        Some(FBool(v)) => assert_eq(v, false)
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "frontmatter TOML negative integer parses as FInt" {
  // parse_int_str handles negation — tests previously only used positive values
  let src = "+++\noffset = -42\nzero = 0\n+++\n"
  match @frontmatter.parse(src) {
    Ok(fm) => {
      match fm.fields.get("offset") {
        Some(FInt(v)) => assert_eq(v, -42)
        _ => assert_true(false)
      }
      match fm.fields.get("zero") {
        Some(FInt(v)) => assert_eq(v, 0)
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "frontmatter TOML empty array produces FArray with length 0" {
  // parse_array_at has an early-return branch for the empty case — untested
  let src = "+++\ntags = []\n+++\n"
  match @frontmatter.parse(src) {
    Ok(fm) =>
      match fm.fields.get("tags") {
        Some(FArray(items)) => assert_eq(items.length(), 0)
        _ => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "frontmatter TOML with no body text produces empty body string" {
  // body is the substring after the closing delimiter — empty when file ends there
  let src = "+++\ntitle = \"hello\"\n+++\n"
  match @frontmatter.parse(src) {
    Ok(fm) => {
      match fm.fields.get("title") {
        Some(FStr(v)) => assert_eq(v, "hello")
        _ => assert_true(false)
      }
      assert_eq(fm.body, "")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "frontmatter YAML boolean true and false parse correctly" {
  // YAML uses parse_yaml_value → parse_value_strict → starts_with "true"/"false"
  let src = "---\nactive: true\ndisabled: false\n---\n"
  match @frontmatter.parse(src) {
    Ok(fm) => {
      match fm.fields.get("active") {
        Some(FBool(v)) => assert_eq(v, true)
        _ => assert_true(false)
      }
      match fm.fields.get("disabled") {
        Some(FBool(v)) => assert_eq(v, false)
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "frontmatter YAML negative integer parses as FInt" {
  let src = "---\npriority: -5\nbase: -1\n---\n"
  match @frontmatter.parse(src) {
    Ok(fm) => {
      match fm.fields.get("priority") {
        Some(FInt(v)) => assert_eq(v, -5)
        _ => assert_true(false)
      }
      match fm.fields.get("base") {
        Some(FInt(v)) => assert_eq(v, -1)
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "frontmatter YAML empty value colon produces FStr empty string" {
  // parse_yaml_assignment: when value after colon is empty and no block items follow,
  // returns FStr(""). This is the fallback for "field:" with no value.
  let src = "---\ndescription:\ntitle: hello\n---\n"
  match @frontmatter.parse(src) {
    Ok(fm) => {
      match fm.fields.get("description") {
        Some(FStr(v)) => assert_eq(v, "")
        _ => assert_true(false)
      }
      match fm.fields.get("title") {
        Some(FStr(v)) => assert_eq(v, "hello")
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "frontmatter YAML no body produces empty body string" {
  let src = "---\ntitle: hello\n---\n"
  match @frontmatter.parse(src) {
    Ok(fm) => {
      match fm.fields.get("title") {
        Some(FStr(v)) => assert_eq(v, "hello")
        _ => assert_true(false)
      }
      assert_eq(fm.body, "")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "frontmatter TOML unterminated array gives parse error" {
  // parse_array_at: no closing ] → Err("unterminated array literal")
  let src = "+++\ntags = [1, 2\n+++\n"
  match @frontmatter.parse(src) {
    Ok(_) => assert_true(false)
    Err(msg) => assert_true(msg.contains("unterminated array"))
  }
}

///|
test "frontmatter parse_toml rejects non-TOML delimiter directly" {
  // parse_toml is a public function — test it directly with wrong delimiter
  match @frontmatter.parse_toml("---\ntitle: hello\n---\n") {
    Ok(_) => assert_true(false)
    Err(msg) => assert_true(msg.contains("+++"))
  }
}

///|
test "frontmatter parse_yaml rejects non-YAML delimiter directly" {
  // parse_yaml is a public function — test it directly with wrong delimiter
  match @frontmatter.parse_yaml("+++\ntitle = \"hello\"\n+++\n") {
    Ok(_) => assert_true(false)
    Err(msg) => assert_true(msg.contains("---"))
  }
}

///|
test "frontmatter TOML comment-only block produces empty fields" {
  // Lines starting with # are skipped; the block should produce no fields
  let src = "+++\n# this is a comment\n# another comment\n+++\nbody\n"
  match @frontmatter.parse(src) {
    Ok(fm) => {
      assert_eq(fm.fields.length(), 0)
      assert_eq(fm.body, "body\n")
    }
    Err(_) => assert_true(false)
  }
}
