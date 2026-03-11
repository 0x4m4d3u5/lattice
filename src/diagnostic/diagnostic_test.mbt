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
  assert_true(rendered.contains("\u001b[1m\u001b[4mcontent/posts/hello.md:12\u001b[0m"))
  assert_true(rendered.contains("\u001b[31m\u001b[1m[error]\u001b[0m missing required field 'title'"))
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
  assert_true(rendered.contains("\u001b[1m\u001b[4mcontent/site.conf:3:9\u001b[0m"))
  assert_true(rendered.contains("\u001b[33m\u001b[1m[warning]\u001b[0m"))
  assert_true(rendered.contains("\u001b[2m[W001]\u001b[0m"))
  assert_true(rendered.contains("\n  hint: use 'base_url' instead"))
}
