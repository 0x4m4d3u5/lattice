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
  assert_true(!rendered.contains("\n"))
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
  assert_true(text.contains("lattice explain"))
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

///|
test "count_errors returns zero for empty array" {
  assert_eq(count_errors([]), 0)
}

///|
test "count_errors ignores warnings" {
  let items : Array[Diagnostic] = [
    { severity: Warning, code: None, path: None, line: None, column: None, message: "w", note: None },
    { severity: Warning, code: None, path: None, line: None, column: None, message: "w2", note: None },
  ]
  assert_eq(count_errors(items), 0)
}

///|
test "count_errors counts only errors in mixed array" {
  let items : Array[Diagnostic] = [
    { severity: Error, code: Some("E001"), path: None, line: None, column: None, message: "e1", note: None },
    { severity: Warning, code: None, path: None, line: None, column: None, message: "w", note: None },
    { severity: Error, code: Some("E004"), path: None, line: None, column: None, message: "e2", note: None },
  ]
  assert_eq(count_errors(items), 2)
}

///|
test "of_lint_violation assigns correct E-code for BrokenWikilink" {
  let v : @lint.LintViolation = {
    path: "content/posts/hello.md",
    line: Some(5),
    column: None,
    kind: @lint.BrokenWikilink,
    message: "broken wikilink: [[missing]]",
  }
  let d = of_lint_violation(v)
  assert_eq(d.severity, Error)
  assert_eq(d.code, Some("E004"))
  assert_eq(d.path, Some("content/posts/hello.md"))
  assert_eq(d.line, Some(5))
  assert_eq(d.message, "broken wikilink: [[missing]]")
  // BrokenWikilink has a hint
  assert_true(!(d.note is None))
}

///|
test "of_lint_violation assigns correct E-code for DuplicateSlug" {
  let v : @lint.LintViolation = {
    path: "content/posts/dup.md",
    line: None,
    column: None,
    kind: @lint.DuplicateSlug,
    message: "duplicate slug: 'hello'",
  }
  let d = of_lint_violation(v)
  assert_eq(d.severity, Error)
  assert_eq(d.code, Some("E010"))
  assert_eq(d.path, Some("content/posts/dup.md"))
}

///|
test "of_lint_violation is always Error severity" {
  // All lint violations are errors, never warnings — verify this invariant
  // for a representative sample of violation types
  let kinds : Array[@lint.ViolationType] = [
    @lint.MissingRequiredFrontmatter,
    @lint.SchemaError,
    @lint.FrontmatterError,
    @lint.BrokenWikilink,
    @lint.TemplateSlotError,
    @lint.IOError,
  ]
  for kind in kinds {
    let v : @lint.LintViolation = { path: "x.md", line: None, column: None, kind, message: "msg" }
    assert_eq(of_lint_violation(v).severity, Error)
  }
}
