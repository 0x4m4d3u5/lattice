///|
test "manifest render and parse roundtrip" {
  let manifest : ManifestFile = {
    version: 1,
    entries: [
      {
        src: "content/posts/hello.md",
        mtime: 123456789L,
        out: "_site/posts/hello/index.html",
        targets: ["about", "contact"],
      },
      { src: "content/lattice.conf", mtime: 42L, out: "", targets: [] },
    ],
  }

  let rendered = render(manifest)
  let parsed = parse(rendered) catch {
    ParseError(_) => {
      assert_true(false)
      { version: 0, entries: [] }
    }
  }

  assert_eq(parsed.version, 1)
  assert_eq(parsed.entries.length(), 2)
  assert_eq(parsed.entries[0].src, "content/posts/hello.md")
  assert_eq(parsed.entries[0].mtime, 123456789L)
  assert_eq(parsed.entries[0].out, "_site/posts/hello/index.html")
  assert_eq(parsed.entries[0].targets.length(), 2)
  assert_eq(parsed.entries[0].targets[0], "about")
  assert_eq(parsed.entries[0].targets[1], "contact")
  assert_eq(parsed.entries[1].targets.length(), 0)
}

///|
test "manifest parse accepts entries without targets" {
  let source = "{\"version\":1,\"entries\":[{\"src\":\"a.md\",\"mtime\":1,\"out\":\"out/index.html\"}]}"
  let parsed = parse(source) catch {
    ParseError(_) => {
      assert_true(false)
      { version: 0, entries: [] }
    }
  }
  assert_eq(parsed.entries.length(), 1)
  assert_eq(parsed.entries[0].targets.length(), 0)
}

///|
test "manifest roundtrip preserves negative mtime" {
  let manifest : ManifestFile = {
    version: 1,
    entries: [{ src: "a.md", mtime: -1000L, out: "dist/a/index.html", targets: [] }],
  }
  let parsed = parse(render(manifest)) catch {
    ParseError(_) => {
      assert_true(false)
      { version: 0, entries: [] }
    }
  }
  assert_eq(parsed.entries[0].mtime, -1000L)
}

///|
test "manifest parse rejects missing required src field" {
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{\"mtime\":1,\"out\":\"out/index.html\"}]}",
    )
    false
  } catch {
    ParseError(_) => true
  }
  assert_true(raised)
}

///|
test "manifest parse rejects completely malformed input" {
  let raised = try {
    let _ = parse("not json")
    false
  } catch {
    ParseError(_) => true
  }
  assert_true(raised)
}

///|
test "manifest render omits targets key when targets array is empty" {
  let manifest : ManifestFile = {
    version: 1,
    entries: [{ src: "a.md", mtime: 1L, out: "out/a/index.html", targets: [] }],
  }
  let rendered = render(manifest)
  // When targets is empty, the rendered JSON should not include the targets key
  assert_true(!rendered.contains("\"targets\""))
}

/// === Error path coverage tests ===
/// The following tests cover the 22 previously uncovered lines in manifest.mbt,
/// focusing on JSON parser error branches that guard against malformed cache files.

///|
test "manifest parse rejects non-string value where string expected" {
  // Covers: parse_json_string_manifest line 40 — raise when char at idx is not '"'
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{\"src\":123,\"mtime\":1,\"out\":\"o\"}]}",
    )
    false
  } catch {
    ParseError(_) => true
  }
  assert_true(raised)
}

///|
test "manifest parse rejects unterminated string escape" {
  // Covers: parse_json_string_manifest line 55 — raise when string ends with \
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{\"src\":\"a\\",
    )
    false
  } catch {
    ParseError(_) => true
  }
  assert_true(raised)
}

///|
test "manifest parse handles backslash-quote escape in string" {
  // Covers: parse_json_string_manifest lines 58-60 — escaped quote handling
  let source = "{\"version\":1,\"entries\":[{\"src\":\"a\\\"b.md\",\"mtime\":1,\"out\":\"o\"}]}"
  let parsed = parse(source) catch {
    ParseError(_) => {
      assert_true(false)
      { version: 0, entries: [] }
    }
  }
  assert_eq(parsed.entries[0].src, "a\"b.md")
}

///|
test "manifest parse handles backslash and forward slash escape" {
  // Covers: parse_json_string_manifest escape branches for \\, \/, \n, \r, \t
  // Test via render roundtrip with chars that render as JSON escape sequences
  // (not \uXXXX — those are for control chars below 0x20 that the parser can't read)
  let manifest : ManifestFile = {
    version: 1,
    entries: [
      { src: "a\\b/c", mtime: 1L, out: "o\nr\tt", targets: [] },
    ],
  }
  let rendered = render(manifest)
  let parsed = parse(rendered) catch {
    ParseError(msg) => {
      assert_true(false, msg=msg)
      { version: 0, entries: [] }
    }
  }
  assert_eq(parsed.entries[0].src, "a\\b/c")
  assert_eq(parsed.entries[0].out, "o\nr\tt")
}

///|
test "manifest parse handles forward slash escape in JSON string" {
  // Covers: parse_json_string_manifest line 64 — escaped forward slash \/
  // Manually construct JSON where the src value contains \/ (JSON escape for /)
  // MoonBit "\\/" = literal string "\/" — two chars: backslash + forward-slash
  // JSON parser sees \/ → parses as /
  let source = "{\"version\":1,\"entries\":[{\"src\":\"a\\/b.md\",\"mtime\":1,\"out\":\"o\"}]}"
  let parsed = parse(source) catch {
    ParseError(msg) => {
      assert_true(false, msg=msg)
      { version: 0, entries: [] }
    }
  }
  assert_eq(parsed.entries[0].src, "a/b.md")
}

///|
test "manifest parse handles backspace escape in JSON string" {
  // Covers: parse_json_string_manifest line 66 — escaped backspace \b
  // MoonBit "\\b" = literal string "\b" — two chars: backslash + b
  // JSON parser sees \b → parses as backspace char
  let source = "{\"version\":1,\"entries\":[{\"src\":\"a\\bb.md\",\"mtime\":1,\"out\":\"o\"}]}"
  let parsed = parse(source) catch {
    ParseError(msg) => {
      assert_true(false, msg=msg)
      { version: 0, entries: [] }
    }
  }
  assert_eq(parsed.entries[0].src.length(), 6)
}

///|
test "manifest parse handles formfeed escape in JSON string" {
  // Covers: parse_json_string_manifest line 68 — escaped formfeed \f
  let source = "{\"version\":1,\"entries\":[{\"src\":\"a\\fb.md\",\"mtime\":1,\"out\":\"o\"}]}"
  let parsed = parse(source) catch {
    ParseError(msg) => {
      assert_true(false, msg=msg)
      { version: 0, entries: [] }
    }
  }
  assert_eq(parsed.entries[0].src.length(), 6)
}

///|
test "manifest parse handles carriage return escape in JSON string" {
  // Covers: parse_json_string_manifest line 72 — escaped carriage return \r
  let source = "{\"version\":1,\"entries\":[{\"src\":\"a\\rb.md\",\"mtime\":1,\"out\":\"o\"}]}"
  let parsed = parse(source) catch {
    ParseError(msg) => {
      assert_true(false, msg=msg)
      { version: 0, entries: [] }
    }
  }
  assert_true(parsed.entries[0].src.contains("\r"))
}

///|
test "manifest parse rejects entry with immediate closing brace" {
  // Covers: parse_entry_manifest line 178 — '}' reached at top of while loop
  // before any fields are parsed (all seen_* flags are false)
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{}]}",
    )
    false
  } catch {
    ParseError(_) => true
  }
  assert_true(raised)
}

///|
test "manifest parse rejects entry truncated after field comma" {
  // Covers: parse_entry_manifest line 175 — source exhaustion after processing
  // a field and consuming the comma separator (top of while loop: i >= source.length())
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{\"src\":\"a.md\",",
    )
    false
  } catch {
    ParseError(_) => true
  }
  assert_true(raised)
}

///|
test "manifest parse rejects unicode escape in string" {
  // Covers: parse_json_string_manifest — raise ParseError("unicode escapes are not supported")
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{\"src\":\"\\u0041.md\",\"mtime\":1,\"out\":\"o\"}]}",
    )
    false
  } catch {
    ParseError(msg) => {
      assert_true(msg.contains("unicode"))
      true
    }
  }
  assert_true(raised)
}

///|
test "manifest parse rejects invalid escape character in string" {
  // Covers: parse_json_string_manifest line 78 — raise ParseError("invalid escape")
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{\"src\":\"\\x.md\",\"mtime\":1,\"out\":\"o\"}]}",
    )
    false
  } catch {
    ParseError(msg) => {
      assert_true(msg.contains("invalid escape"))
      true
    }
  }
  assert_true(raised)
}

///|
test "manifest parse rejects empty source for integer" {
  // Covers: parse_int64_manifest line 92 — raise when source exhausted
  // This exercises the "i >= source.length()" path by passing a value position
  // where there is nothing after the colon. We trigger this via mtime field.
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{\"src\":\"a.md\",\"mtime\":",
    )
    false
  } catch {
    ParseError(_) => true
  }
  assert_true(raised)
}

///|
test "manifest parse rejects non-digit characters in mtime" {
  // Covers: parse_int64_manifest line 102 — raise when char after optional '-' is not a digit
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{\"src\":\"a.md\",\"mtime\":\"notanumber\",\"out\":\"o\"}]}",
    )
    false
  } catch {
    ParseError(_) => true
  }
  assert_true(raised)
}

///|
test "manifest parse accepts negative sign followed by digits for mtime" {
  // Covers: parse_int64_manifest negative branch (already covered by negative mtime test,
  // but this explicitly tests the negative = true path)
  let source = "{\"version\":1,\"entries\":[{\"src\":\"a.md\",\"mtime\":-42,\"out\":\"o\"}]}"
  let parsed = parse(source) catch {
    ParseError(_) => {
      assert_true(false)
      { version: 0, entries: [] }
    }
  }
  assert_eq(parsed.entries[0].mtime, -42L)
}

///|
test "manifest parse rejects unterminated string at end of source" {
  // Covers: parse_json_string_manifest final raise ("unterminated string")
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{\"src\":\"unterminated",
    )
    false
  } catch {
    ParseError(_) => true
  }
  assert_true(raised)
}

///|
test "manifest parse handles empty targets array explicitly" {
  // Covers: parse_targets_manifest line 137 — return early for "targets":[]
  let source = "{\"version\":1,\"entries\":[{\"src\":\"a.md\",\"mtime\":1,\"out\":\"o\",\"targets\":[]}]}"
  let parsed = parse(source) catch {
    ParseError(_) => {
      assert_true(false)
      { version: 0, entries: [] }
    }
  }
  assert_eq(parsed.entries[0].targets.length(), 0)
}

///|
test "manifest parse rejects unterminated targets array" {
  // Covers: parse_targets_manifest line 144 — raise when source ends mid-array
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{\"src\":\"a.md\",\"mtime\":1,\"out\":\"o\",\"targets\":[\"x\"",
    )
    false
  } catch {
    ParseError(_) => true
  }
  assert_true(raised)
}

///|
test "manifest parse rejects bad separator in targets array" {
  // Covers: parse_targets_manifest line 151 — raise on unexpected char between targets
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{\"src\":\"a.md\",\"mtime\":1,\"out\":\"o\",\"targets\":[\"x\";\"y\"]}]}",
    )
    false
  } catch {
    ParseError(_) => true
  }
  assert_true(raised)
}

///|
test "manifest parse rejects unterminated entry object" {
  // Covers: parse_entry_manifest line 175 — raise when source ends mid-entry
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{\"src\":\"a.md\"",
    )
    false
  } catch {
    ParseError(_) => true
  }
  assert_true(raised)
}

///|
test "manifest parse rejects entry closed without required fields" {
  // Covers: parse_entry_manifest line 178 — raise when '}' seen before src/mtime/out
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{\"src\":\"a.md\"}]}",
    )
    false
  } catch {
    ParseError(_) => true
  }
  assert_true(raised)
}

///|
test "manifest parse rejects unknown entry field" {
  // Covers: parse_entry_manifest line 206 — raise on unexpected key
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{\"src\":\"a.md\",\"mtime\":1,\"out\":\"o\",\"unknown\":1}]}",
    )
    false
  } catch {
    ParseError(msg) => {
      assert_true(msg.contains("unknown entry field"))
      true
    }
  }
  assert_true(raised)
}

///|
test "manifest parse rejects missing comma between entry fields" {
  // Covers: parse_entry_manifest line 222 — raise when separator is not ',' or '}'
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{\"src\":\"a.md\";\"mtime\":1;\"out\":\"o\"}]}",
    )
    false
  } catch {
    ParseError(_) => true
  }
  assert_true(raised)
}

///|
test "manifest parse rejects entry ending mid-object after field value" {
  // Covers: parse_entry_manifest line 210 — raise when source ends after reading a field value
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{\"src\":\"a.md\",\"mtime\":1,\"out\":\"o\"",
    )
    false
  } catch {
    ParseError(_) => true
  }
  assert_true(raised)
}

///|
test "manifest parse rejects wrong first key" {
  // Covers: parse() line 236 — raise when first key is not "version"
  let raised = try {
    let _ = parse("{\"wrong\":1,\"entries\":[]}")
    false
  } catch {
    ParseError(msg) => {
      assert_true(msg.contains("version"))
      true
    }
  }
  assert_true(raised)
}

///|
test "manifest parse rejects missing comma after version" {
  // Covers: parse() line 242 — raise when no comma after version value
  let raised = try {
    let _ = parse("{\"version\":1 \"entries\":[]}")
    false
  } catch {
    ParseError(msg) => {
      assert_true(msg.contains(","))
      true
    }
  }
  assert_true(raised)
}

///|
test "manifest parse rejects wrong second key" {
  // Covers: parse() line 249 — raise when second key is not "entries"
  let raised = try {
    let _ = parse("{\"version\":1,\"wrong\":[]}")
    false
  } catch {
    ParseError(msg) => {
      assert_true(msg.contains("entries"))
      true
    }
  }
  assert_true(raised)
}

///|
test "manifest parse accepts empty entries array" {
  // Covers: parse() line 256 — early return when entries array is []
  let source = "{\"version\":1,\"entries\":[]}"
  let parsed = parse(source) catch {
    ParseError(_) => {
      assert_true(false)
      { version: 0, entries: [] }
    }
  }
  assert_eq(parsed.entries.length(), 0)
}

///|
test "manifest parse rejects unterminated entries array" {
  // Covers: parse() line 263 — raise when source ends mid-entries
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{\"src\":\"a.md\",\"mtime\":1,\"out\":\"o\"}",
    )
    false
  } catch {
    ParseError(_) => true
  }
  assert_true(raised)
}

///|
test "manifest parse rejects bad separator in entries array" {
  // Covers: parse() line 271 — raise when entries separator is not ',' or ']'
  let raised = try {
    let _ = parse(
      "{\"version\":1,\"entries\":[{\"src\":\"a.md\",\"mtime\":1,\"out\":\"o\"};{\"src\":\"b.md\",\"mtime\":2,\"out\":\"o\"}]}",
    )
    false
  } catch {
    ParseError(_) => true
  }
  assert_true(raised)
}

///|
test "manifest parse rejects trailing content after closing brace" {
  // Covers: parse() line 279 — raise when there is content after the final '}'
  let raised = try {
    let _ = parse("{\"version\":1,\"entries\":[]}extra")
    false
  } catch {
    ParseError(msg) => {
      assert_true(msg.contains("trailing"))
      true
    }
  }
  assert_true(raised)
}
