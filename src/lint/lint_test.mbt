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
  let result : LintResult = { violations, }
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
  let result : LintResult = { violations, }
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
  assert_true(not(text.contains("By type:")))
  assert_true(not(text.contains("By file:")))
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
  let result : LintResult = { violations, }
  let summary = summarize(result)
  let text = format_summary(summary)
  assert_true(text.contains("Summary: 2 violation(s)"))
  assert_true(text.contains("By type:"))
  assert_true(text.contains("schema: 1"))
  assert_true(text.contains("broken_wikilink: 1"))
  assert_true(text.contains("By file:"))
  assert_true(text.contains("posts/hello.md: 2"))
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
  let result : LintResult = { violations, }
  let summary = summarize(result)
  assert_eq(summary.total, 1)
  assert_eq(summary.by_type.length(), 1)
  assert_eq(summary.by_type[0].kind, DuplicateSlug)
  assert_eq(summary.by_type[0].count, 1)
  assert_eq(summary.by_file.length(), 1)
  assert_eq(summary.by_file[0].path, "x.md")
  assert_eq(summary.by_file[0].count, 1)
}
