///|
test "lint summarize empty result" {
  let result = empty_result()
  let summary = summarize(result)
  assert_eq(summary.total, 0)
  assert_eq(summary.by_type.length(), 0)
  assert_eq(summary.by_file.length(), 0)
}

///|
test "lint summarize groups by violation type" {
  let violations : Array[LintViolation] = [
    {
      path: "a.md",
      line: None,
      column: None,
      kind: SchemaError,
      message: "bad schema",
    },
    {
      path: "b.md",
      line: None,
      column: None,
      kind: SchemaError,
      message: "bad schema 2",
    },
    {
      path: "c.md",
      line: None,
      column: None,
      kind: BrokenWikilink,
      message: "broken link",
    },
  ]
  let result : LintResult = { violations, messages: [] }
  let summary = summarize(result)
  assert_eq(summary.total, 3)
  // SchemaError should be first (count 2) then BrokenWikilink (count 1)
  assert_eq(summary.by_type.length(), 2)
  assert_eq(summary.by_type[0].kind, SchemaError)
  assert_eq(summary.by_type[0].count, 2)
  assert_eq(summary.by_type[1].kind, BrokenWikilink)
  assert_eq(summary.by_type[1].count, 1)
}

///|
test "lint summarize groups by file" {
  let violations : Array[LintViolation] = [
    {
      path: "a.md",
      line: Some(1),
      column: None,
      kind: SchemaError,
      message: "err1",
    },
    {
      path: "a.md",
      line: Some(5),
      column: None,
      kind: BrokenWikilink,
      message: "err2",
    },
    {
      path: "b.md",
      line: None,
      column: None,
      kind: SchemaError,
      message: "err3",
    },
  ]
  let result : LintResult = { violations, messages: [] }
  let summary = summarize(result)
  assert_eq(summary.total, 3)
  assert_eq(summary.by_file.length(), 2)
  // a.md has 2 violations, b.md has 1
  assert_eq(summary.by_file[0].path, "a.md")
  assert_eq(summary.by_file[0].count, 2)
  assert_eq(summary.by_file[1].path, "b.md")
  assert_eq(summary.by_file[1].count, 1)
}

///|
test "lint format_summary empty" {
  let result = empty_result()
  let summary = summarize(result)
  let text = format_summary(summary)
  assert_true(text.contains("Summary: 0 violation(s)"))
  assert_true(!text.contains("By type:"))
  assert_true(!text.contains("By file:"))
}

///|
test "lint format_summary with violations" {
  let violations : Array[LintViolation] = [
    {
      path: "posts/hello.md",
      line: None,
      column: None,
      kind: SchemaError,
      message: "bad",
    },
    {
      path: "posts/hello.md",
      line: None,
      column: None,
      kind: BrokenWikilink,
      message: "link",
    },
  ]
  let result : LintResult = { violations, messages: [] }
  let summary = summarize(result)
  let text = format_summary(summary)
  assert_true(text.contains("Summary: 2 violation(s)"))
  assert_true(text.contains("By type:"))
  assert_true(text.contains("schema: 1"))
  assert_true(text.contains("broken_wikilink: 1"))
  assert_true(text.contains("By file:"))
  assert_true(text.contains("posts/hello.md: 2"))
  assert_true(text.contains("lattice explain"))
}

///|
test "lint format_violations_json empty" {
  let result = empty_result()
  let json = format_violations_json(result)
  assert_true(json.contains("\"violations\": []"))
  assert_true(json.contains("\"total\": 0"))
  assert_true(json.contains("\"by_type\": []"))
  assert_true(json.contains("\"by_file\": []"))
}

///|
test "lint format_violations_json with line and column" {
  let violations : Array[LintViolation] = [
    {
      path: "content/posts/foo.md",
      line: Some(12),
      column: Some(5),
      kind: BrokenWikilink,
      message: "unknown slug 'bar'",
    },
  ]
  let result : LintResult = { violations, messages: [] }
  let json = format_violations_json(result)
  assert_true(json.contains("\"path\": \"content/posts/foo.md\""))
  assert_true(json.contains("\"line\": 12"))
  assert_true(json.contains("\"column\": 5"))
  assert_true(json.contains("\"kind\": \"broken_wikilink\""))
  assert_true(json.contains("\"message\": \"unknown slug 'bar'\""))
  assert_true(json.contains("\"total\": 1"))
}

///|
test "lint format_violations_json null line and column" {
  let violations : Array[LintViolation] = [
    {
      path: "content/posts/bar.md",
      line: None,
      column: None,
      kind: SchemaError,
      message: "field error",
    },
  ]
  let result : LintResult = { violations, messages: [] }
  let json = format_violations_json(result)
  assert_true(json.contains("\"line\": null"))
  assert_true(json.contains("\"column\": null"))
  assert_true(json.contains("\"kind\": \"schema\""))
}

///|
test "lint format_violations_json escapes special chars in message" {
  let violations : Array[LintViolation] = [
    {
      path: "a.md",
      line: None,
      column: None,
      kind: DataError,
      message: "field \"x\" contains \\backslash",
    },
  ]
  let result : LintResult = { violations, messages: [] }
  let json = format_violations_json(result)
  // backslash and quote must be escaped in JSON
  assert_true(json.contains("\\\"x\\\""))
  assert_true(json.contains("\\\\backslash"))
}

///|
test "lint summarize single violation" {
  let violations : Array[LintViolation] = [
    {
      path: "x.md",
      line: Some(3),
      column: None,
      kind: DuplicateSlug,
      message: "dup",
    },
  ]
  let result : LintResult = { violations, messages: [] }
  let summary = summarize(result)
  assert_eq(summary.total, 1)
  assert_eq(summary.by_type.length(), 1)
  assert_eq(summary.by_type[0].kind, DuplicateSlug)
  assert_eq(summary.by_type[0].count, 1)
  assert_eq(summary.by_file.length(), 1)
  assert_eq(summary.by_file[0].path, "x.md")
  assert_eq(summary.by_file[0].count, 1)
}



///|
test "lint has_violations returns false for empty result" {
  let result = empty_result()
  assert_true(!has_violations(result))
}

///|
test "lint has_violations returns true when violations present" {
  let violations : Array[LintViolation] = [
    {
      path: "a.md",
      line: None,
      column: None,
      kind: SchemaError,
      message: "bad",
    },
  ]
  let result : LintResult = { violations, messages: [] }
  assert_true(has_violations(result))
}

///|
test "lint violation_type_name maps all variants" {
  assert_eq(violation_type_name(SchemaError), "schema")
  assert_eq(
    violation_type_name(MissingRequiredFrontmatter),
    "missing_required_field",
  )
  assert_eq(violation_type_name(BrokenWikilink), "broken_wikilink")
  assert_eq(violation_type_name(DanglingTagReference), "dangling_tag")
  assert_eq(violation_type_name(TemplateSlotError), "template_slot")
  assert_eq(violation_type_name(DataError), "data")
  assert_eq(violation_type_name(ShortcodeError), "shortcode")
  assert_eq(violation_type_name(FrontmatterError), "frontmatter")
  assert_eq(violation_type_name(CollectionsError), "collections")
  assert_eq(violation_type_name(DuplicateSlug), "duplicate_slug")
  assert_eq(violation_type_name(IOError), "io")
}

///|
test "lint format_violation with line and column" {
  let v : LintViolation = {
    path: "path/file.md",
    line: Some(5),
    column: Some(12),
    kind: BrokenWikilink,
    message: "target not found",
  }
  let s = format_violation(v)
  assert_eq(s, "path/file.md:5:12: broken_wikilink: target not found")
}

///|
test "lint format_violation with line only" {
  let v : LintViolation = {
    path: "path/file.md",
    line: Some(5),
    column: None,
    kind: SchemaError,
    message: "bad value",
  }
  let s = format_violation(v)
  assert_eq(s, "path/file.md:5: schema: bad value")
}

///|
test "lint format_violation with no position" {
  let v : LintViolation = {
    path: "path/file.md",
    line: None,
    column: None,
    kind: MissingRequiredFrontmatter,
    message: "required",
  }
  let s = format_violation(v)
  assert_eq(s, "path/file.md: missing_required_field: required")
}
