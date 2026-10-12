///|
test "DateTime enforces Gregorian calendar days" {
  let schema : @schema.Schema = {
    name: "events",
    fields: [
      { name: "starts_at", field_type: TDateTime(None, None), required: true, },
    ],
  }
  for
    invalid in [
      "2026-02-29T10:30:00Z", "2028-02-30T10:30:00Z", "1900-02-29T10:30:00Z", "2100-02-29T10:30:00Z",
      "2026-04-31T10:30:00Z", "2026-06-31 10:30:00",
    ] {
    let fm = @frontmatter.parse("---\nstarts_at: " + invalid + "\n---\n").unwrap()
    let errors = @schema.validate(fm, schema)
    assert_eq(errors.length(), 1)
    assert_eq(errors[0].field, "starts_at")
    assert_eq(
      errors[0].message,
      "expected ISO 8601 datetime (YYYY-MM-DDTHH:MM:SS[Z|+HH:MM]), got: \"" +
      invalid +
      "\"",
    )
  }
  for
    valid in [
      "2028-02-29T10:30:00Z", "2000-02-29T10:30:00+05:30", "2026-04-30T23:59:59-08:00",
      "2026-01-31 10:30:00", "2026-03-15T10:30:00", "2026-03-15 10:30:00Z",
    ] {
    let fm = @frontmatter.parse("---\nstarts_at: " + valid + "\n---\n").unwrap()
    assert_eq(@schema.validate(fm, schema).length(), 0)
  }
}
///|
test "DateTime requires digits in every numeric timezone offset position" {
  let schema : @schema.Schema = {
    name: "events",
    fields: [{ name: "starts_at", field_type: TDateTime(None, None), required: true }],
  }
  for invalid in [
    "2026-03-15T10:30:00+/0:00", "2026-03-15T10:30:00-0/:00",
    "2026-03-15T10:30:00+00:/0", "2026-03-15T10:30:00-00:0/",
  ] {
    let fm = @frontmatter.parse("---\nstarts_at: " + invalid + "\n---\n").unwrap()
    let errors = @schema.validate(fm, schema)
    assert_eq(errors.length(), 1)
    assert_eq(errors[0].message, "expected ISO 8601 datetime (YYYY-MM-DDTHH:MM:SS[Z|+HH:MM]), got: \"" + invalid + "\"")
  }
  for valid in ["2026-03-15T10:30:00+23:59", "2026-03-15T10:30:00-23:59"] {
    let fm = @frontmatter.parse("---\nstarts_at: " + valid + "\n---\n").unwrap()
    assert_eq(@schema.validate(fm, schema).length(), 0)
  }
}
