///|
test "cache render and parse roundtrip" {
  let source = render({
    version: 1,
    entries: [
      { slug: "posts/hello", fingerprint: "123" },
      { slug: "about", fingerprint: "456" },
    ],
  })
  let parsed = parse(source) catch {
    ParseFailure(_) => {
      assert_true(false)
      { version: 0, entries: [] }
    }
  }
  assert_eq(parsed.version, 1)
  assert_eq(parsed.entries.length(), 2)
  assert_eq(parsed.entries[0].slug, "posts/hello")
  assert_eq(parsed.entries[0].fingerprint, "123")
}

///|
test "fingerprint changes with source content" {
  let same_a = fingerprint_for_source(
    "content/a.md", "---\ntitle: A\n---\nBody",
  )
  let same_b = fingerprint_for_source(
    "content/a.md", "---\ntitle: A\n---\nBody",
  )
  let changed = fingerprint_for_source(
    "content/a.md", "---\ntitle: A\n---\nBody!",
  )
  assert_eq(same_a, same_b)
  assert_true(same_a != changed)
}

///|
test "cache remember and lookup by slug" {
  let store = empty("./dist")
  remember(store, "hello", "one")
  remember(store, "hello", "two")
  remember(store, "about", "three")
  match lookup(store, "hello") {
    Some(fp) => assert_eq(fp, "two")
    None => assert_true(false)
  }
  match lookup(store, "about") {
    Some(fp) => assert_eq(fp, "three")
    None => assert_true(false)
  }
}

///|
test "should_skip force_rebuild bypasses a matching cache hit" {
  let store = empty("./dist")
  remember(store, "post-a", "fp123")
  // force_rebuild must return false (do not skip) even when the fingerprint matches
  assert_true(!should_skip(store, "post-a", "fp123", ".", true))
}

///|
test "should_skip returns false when output file does not exist on disk" {
  let store = empty("./dist")
  remember(store, "post-a", "fp123")
  let missing = "./_cache_test_nonexistent_output_dir/index.html"
  // No file on disk means the output is gone — must rebuild regardless of cache
  assert_true(!should_skip(store, "post-a", "fp123", missing, false))
}

///|
test "should_skip returns false for a slug not yet in the cache" {
  let store = empty("./dist")
  // No prior build record — cannot confirm output is fresh
  assert_true(!should_skip(store, "brand-new-slug", "fp123", ".", false))
}

///|
test "should_skip returns true when fingerprint matches and output exists" {
  let store = empty("./dist")
  remember(store, "post-a", "fp-abc")
  // Fingerprint matches and "." exists on disk — safe to skip
  assert_true(should_skip(store, "post-a", "fp-abc", ".", false))
}

///|
test "should_skip returns false when fingerprint changed since last build" {
  let store = empty("./dist")
  remember(store, "post-a", "fp-old")
  // Source was modified — fingerprint differs from cached value
  assert_true(!should_skip(store, "post-a", "fp-new", ".", false))
}

///|
test "fingerprint_for_source is sensitive to path as well as content" {
  let content = "---\ntitle: Same\n---\nSame body"
  let fp_a = fingerprint_for_source("content/a.md", content)
  let fp_b = fingerprint_for_source("content/b.md", content)
  // Renaming a file with identical content must produce a distinct fingerprint
  assert_true(fp_a != fp_b)
}

///|
test "cache parse rejects completely malformed input" {
  let raised = try {
    let _ = parse("not json at all")
    false
  } catch {
    ParseFailure(_) => true
  }
  assert_true(raised)
}

///|
test "cache parse rejects input missing entries field" {
  let raised = try {
    let _ = parse("{\"version\":1}")
    false
  } catch {
    ParseFailure(_) => true
  }
  assert_true(raised)
}

///|
test "cache error_text formats all three error variants with context" {
  assert_true(error_text(ReadError("disk I/O failure")).contains("read failed"))
  assert_true(error_text(ReadError("disk I/O failure")).contains("disk I/O failure"))
  assert_true(error_text(ParseError("unexpected token")).contains("parse failed"))
  assert_true(error_text(ParseError("unexpected token")).contains("unexpected token"))
  assert_true(error_text(WriteError("permission denied")).contains("write failed"))
  assert_true(error_text(WriteError("permission denied")).contains("permission denied"))
}

///|
test "cache render and parse preserves special characters in slug" {
  let file : CacheFile = {
    version: 1,
    entries: [{ slug: "path/with\"quotes", fingerprint: "fp-val" }],
  }
  let rendered = render(file)
  let parsed = parse(rendered) catch {
    ParseFailure(_) => {
      assert_true(false)
      { version: 0, entries: [] }
    }
  }
  assert_eq(parsed.entries[0].slug, "path/with\"quotes")
}

/// ============================================================
/// Error-path tests for the cache JSON parser
/// ============================================================

///|
/// expect_char_cache: wrong character — parser expects '{' but gets something else
test "cache parse reject non-brace first char" {
  let raised = try {
    let _ = parse("  x")
    false
  } catch {
    ParseFailure(msg) => {
      assert_true(msg.contains("'{'"))
      true
    }
  }
  assert_true(raised)
}

///|
/// expect_char_cache: end-of-input where a character is expected
test "cache parse reject empty input" {
  let raised = try {
    let _ = parse("")
    false
  } catch {
    ParseFailure(_) => true
  }
  assert_true(raised)
}

///|
/// parse_json_string_cache: input is not a string (starts with a digit, not a quote)
test "cache parse reject version value as non-string key" {
  let raised = try {
    let _ = parse("{123}")
    false
  } catch {
    ParseFailure(msg) => {
      assert_true(msg.contains("string"))
      true
    }
  }
  assert_true(raised)
}

///|
/// parse_json_string_cache: \\u escape is rejected
test "cache parse reject unicode escape in string" {
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{\"slug\":\"hello\\u0041\",\"fingerprint\":\"fp\"}]}",
    )
    false
  } catch {
    ParseFailure(msg) => {
      assert_true(msg.contains("unicode"))
      true
    }
  }
  assert_true(raised)
}

///|
/// parse_json_string_cache: invalid escape character (\\x)
test "cache parse reject invalid escape in string" {
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{\"slug\":\"\\x\",\"fingerprint\":\"fp\"}]}",
    )
    false
  } catch {
    ParseFailure(msg) => {
      assert_true(msg.contains("invalid escape"))
      true
    }
  }
  assert_true(raised)
}

///|
/// parse_json_string_cache: unterminated escape (backslash at end of input)
test "cache parse reject unterminated escape" {
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{\"slug\":\"abc\\",
    )
    false
  } catch {
    ParseFailure(msg) => {
      assert_true(msg.contains("unterminated escape"))
      true
    }
  }
  assert_true(raised)
}

///|
/// parse_json_string_cache: unterminated string (no closing quote)
test "cache parse reject unterminated string" {
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{\"slug\":\"no-end",
    )
    false
  } catch {
    ParseFailure(msg) => {
      assert_true(msg.contains("unterminated string"))
      true
    }
  }
  assert_true(raised)
}

///|
/// parse_int_cache: not an integer (first char is not a digit)
test "cache parse reject non-integer version value" {
  let raised = try {
    let _ = parse("{\"version\":\"not-a-number\"")
    false
  } catch {
    ParseFailure(msg) => {
      assert_true(msg.contains("integer"))
      true
    }
  }
  assert_true(raised)
}

///|
/// parse_entry_cache: unterminated object (entry object never closes)
test "cache parse reject unterminated entry object" {
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{\"slug\":\"a\",\"fingerprint\":\"b\"",
    )
    false
  } catch {
    ParseFailure(msg) => {
      assert_true(msg.contains("unterminated"))
      true
    }
  }
  assert_true(raised)
}

///|
/// parse_entry_cache: missing required field when '}' seen (only slug, no fingerprint)
test "cache parse reject entry missing fingerprint field" {
  let raised = try {
    let _ = parse("{\"version\":1,\"entries\":[{\"slug\":\"a\"}]}")
    false
  } catch {
    ParseFailure(msg) => {
      assert_true(msg.contains("required"))
      true
    }
  }
  assert_true(raised)
}

///|
/// parse_entry_cache: missing required field when '}' seen (only fingerprint, no slug)
test "cache parse reject entry missing slug field" {
  let raised = try {
    let _ = parse("{\"version\":1,\"entries\":[{\"fingerprint\":\"fp\"}]}")
    false
  } catch {
    ParseFailure(msg) => {
      assert_true(msg.contains("required"))
      true
    }
  }
  assert_true(raised)
}

///|
/// parse_entry_cache: unknown entry field
test "cache parse reject unknown entry field" {
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{\"slug\":\"a\",\"fingerprint\":\"b\",\"bogus\":1}]}",
    )
    false
  } catch {
    ParseFailure(msg) => {
      assert_true(msg.contains("unknown"))
      true
    }
  }
  assert_true(raised)
}

///|
/// parse_entry_cache: missing comma or '}' between fields
test "cache parse reject missing comma in entry" {
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{\"slug\":\"a\" \"fingerprint\":\"b\"}]}",
    )
    false
  } catch {
    ParseFailure(_) => true
  }
  assert_true(raised)
}

///|
/// parse: wrong first field (not "version")
test "cache parse reject wrong first field" {
  let raised = try {
    let _ = parse("{\"entries\":[],\"version\":1}")
    false
  } catch {
    ParseFailure(msg) => {
      assert_true(msg.contains("version"))
      true
    }
  }
  assert_true(raised)
}

///|
/// parse: no comma after version field
test "cache parse reject missing comma after version" {
  let raised = try {
    let _ = parse("{\"version\":1\"entries\":[]}")
    false
  } catch {
    ParseFailure(msg) => {
      assert_true(msg.contains(","))
      true
    }
  }
  assert_true(raised)
}

///|
/// parse: wrong second field (not "entries")
test "cache parse reject wrong second field" {
  let raised = try {
    let _ = parse("{\"version\":1,\"data\":[]}")
    false
  } catch {
    ParseFailure(msg) => {
      assert_true(msg.contains("entries"))
      true
    }
  }
  assert_true(raised)
}

///|
/// parse: no closing '}' at end of cache file
test "cache parse reject missing closing brace" {
  let raised = try {
    let _ = parse("{\"version\":1,\"entries\":[]")
    false
  } catch {
    ParseFailure(msg) => {
      assert_true(msg.contains("}"))
      true
    }
  }
  assert_true(raised)
}

///|
/// parse: trailing characters after the closing '}'
test "cache parse reject trailing characters after close" {
  let raised = try {
    let _ = parse("{\"version\":1,\"entries\":[]}  extra")
    false
  } catch {
    ParseFailure(msg) => {
      assert_true(msg.contains("trailing"))
      true
    }
  }
  assert_true(raised)
}

///|
/// parse_entries_cache: missing ']' at end of entries array
test "cache parse reject unterminated entries array" {
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{\"slug\":\"a\",\"fingerprint\":\"b\"}",
    )
    false
  } catch {
    ParseFailure(msg) => {
      assert_true(
        msg.contains("unterminated") || msg.contains(",") || msg.contains("'") || msg.contains(
          "expected",
        ),
      )
      true
    }
  }
  assert_true(raised)
}

///|
/// parse_entries_cache: wrong separator between entries (semicolon instead of comma)
test "cache parse reject wrong separator between entries" {
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{\"slug\":\"a\",\"fingerprint\":\"b\"};{\"slug\":\"c\",\"fingerprint\":\"d\"}]}",
    )
    false
  } catch {
    ParseFailure(_) => true
  }
  assert_true(raised)
}
