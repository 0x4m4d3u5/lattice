///|
test "frontmatter parses typed values and preserves body" {
  let src =
    "---\n" +
    "# comment\n" +
    "title = \"Hello\"\n" +
    "count = 42\n" +
    "draft = false\n" +
    "tags = [\"moonbit\", \"ssg\"]\n" +
    "slug = hello-world\n" +
    "---\n" +
    "Body text\n"
  match parse(src) {
    Ok(fm) => {
      assert_eq(fm.body, "Body text\n")
      match fm.fields.get("title") {
        Some(FStr(v)) => assert_eq(v, "Hello")
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
  let src =
    "---\n" +
    "matrix = [[1, 2], [3, 4]]\n" +
    "summary = \"line\\nnext\\tindent\\\"quote\\\"\"\n" +
    "---\n" +
    "\n"
  match parse(src) {
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
  let src =
    "---\n" +
    "title = \"ok\"\n" +
    "broken = [1 2]\n" +
    "---\n"
  match parse(src) {
    Ok(_) => assert_true(false)
    Err(msg) => {
      assert_true(msg.contains("line 2"))
      assert_true(msg.contains("expected ',' or ']' inside array"))
    }
  }
}

///|
test "frontmatter rejects missing closing delimiter" {
  let src = "---\n" + "title = \"open\"\n"
  match parse(src) {
    Ok(_) => assert_true(false)
    Err(msg) => assert_eq(msg, "missing closing '---' delimiter")
  }
}

///|
test "frontmatter parses yaml-style obsidian metadata" {
  let src =
    "---\n" +
    "title: Home\n" +
    "type: home\n" +
    "created: 2026-03-08\n" +
    "tags:\n" +
    "  - type/moc\n" +
    "  - vault/home\n" +
    "---\n" +
    "Body\n"
  match parse(src) {
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
        Some(FStr(v)) => assert_eq(v, "2026-03-08")
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
