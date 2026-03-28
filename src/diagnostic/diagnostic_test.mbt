///|
test "diagnostic formats file line severity and message on one line" {
  let rendered = format_diagnostic({
    severity: Error,
    code: None,
    path: Some("content/posts/hello.md"),
    line: Some(12),
    column: None,
    message: "missing required field 'title'",
    note: None,
  })
  assert_true(
    rendered.contains("\u001b[1m\u001b[4mcontent/posts/hello.md:12\u001b[0m"),
  )
  assert_true(
    rendered.contains(
      "\u001b[31m\u001b[1m[error]\u001b[0m missing required field 'title'",
    ),
  )
  assert_true(not(rendered.contains("\n")))
}

///|
test "diagnostic formats warning code and hint" {
  let rendered = format_diagnostic({
    severity: Warning,
    code: Some("W001"),
    path: Some("content/site.conf"),
    line: Some(3),
    column: Some(9),
    message: "deprecated field",
    note: Some("use 'base_url' instead"),
  })
  assert_true(
    rendered.contains("\u001b[1m\u001b[4mcontent/site.conf:3:9\u001b[0m"),
  )
  assert_true(rendered.contains("\u001b[33m\u001b[1m[warning]\u001b[0m"))
  assert_true(rendered.contains("\u001b[2m[W001]\u001b[0m"))
  assert_true(rendered.contains("\n  hint: use 'base_url' instead"))
}

///|
test "diagnostic summarize empty" {
  let diagnostics : Array[Diagnostic] = []
  let summary = summarize(diagnostics)
  assert_eq(summary.error_count, 0)
  assert_eq(summary.warning_count, 0)
  assert_eq(summary.by_code.length(), 0)
  assert_eq(summary.by_file.length(), 0)
}

///|
test "diagnostic summarize counts errors and warnings" {
  let diagnostics : Array[Diagnostic] = [
    {
      severity: Error,
      code: Some("E002"),
      path: Some("a.md"),
      line: None,
      column: None,
      message: "schema error",
      note: None,
    },
    {
      severity: Error,
      code: Some("E002"),
      path: Some("b.md"),
      line: None,
      column: None,
      message: "another schema error",
      note: None,
    },
    {
      severity: Warning,
      code: None,
      path: None,
      line: None,
      column: None,
      message: "something",
      note: None,
    },
  ]
  let summary = summarize(diagnostics)
  assert_eq(summary.error_count, 2)
  assert_eq(summary.warning_count, 1)
  assert_eq(summary.by_code.length(), 1)
  assert_eq(summary.by_code[0].code, "E002")
  assert_eq(summary.by_code[0].count, 2)
}

///|
test "diagnostic summarize groups by file" {
  let diagnostics : Array[Diagnostic] = [
    {
      severity: Error,
      code: Some("E001"),
      path: Some("posts/a.md"),
      line: None,
      column: None,
      message: "err1",
      note: None,
    },
    {
      severity: Error,
      code: Some("E002"),
      path: Some("posts/a.md"),
      line: None,
      column: None,
      message: "err2",
      note: None,
    },
    {
      severity: Error,
      code: Some("E004"),
      path: Some("posts/b.md"),
      line: None,
      column: None,
      message: "err3",
      note: None,
    },
  ]
  let summary = summarize(diagnostics)
  assert_eq(summary.by_file.length(), 2)
  // posts/a.md has 2 diagnostics, posts/b.md has 1
  assert_eq(summary.by_file[0].path, "posts/a.md")
  assert_eq(summary.by_file[0].count, 2)
  assert_eq(summary.by_file[1].path, "posts/b.md")
  assert_eq(summary.by_file[1].count, 1)
}

///|
test "diagnostic format_summary with errors" {
  let diagnostics : Array[Diagnostic] = [
    {
      severity: Error,
      code: Some("E002"),
      path: Some("hello.md"),
      line: None,
      column: None,
      message: "schema",
      note: None,
    },
    {
      severity: Error,
      code: Some("E004"),
      path: Some("hello.md"),
      line: None,
      column: None,
      message: "wikilink",
      note: None,
    },
  ]
  let summary = summarize(diagnostics)
  let text = format_summary(summary)
  assert_true(text.contains("Summary: 2 error(s), 0 warning(s)"))
  assert_true(text.contains("By code:"))
  assert_true(text.contains("By file:"))
  assert_true(text.contains("hello.md: 2"))
}

///|
test "diagnostic summarize without code or path" {
  let diagnostics : Array[Diagnostic] = [
    {
      severity: Warning,
      code: None,
      path: None,
      line: None,
      column: None,
      message: "orphan diagnostic",
      note: None,
    },
  ]
  let summary = summarize(diagnostics)
  assert_eq(summary.error_count, 0)
  assert_eq(summary.warning_count, 1)
  // No code grouping when code is None
  assert_eq(summary.by_code.length(), 0)
  // No file grouping when path is None
  assert_eq(summary.by_file.length(), 0)
}
