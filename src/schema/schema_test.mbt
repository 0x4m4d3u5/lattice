fn sample_schema() -> Schema {
  {
    name: "posts",
    fields: [
      { name: "title", field_type: TString, required: true },
      { name: "date", field_type: TDate, required: true },
      { name: "published", field_type: TBool, required: true },
      { name: "order", field_type: TInt, required: false },
      { name: "tags", field_type: TArray(TString), required: true },
      { name: "summary", field_type: TOptional(TString), required: false },
    ],
  }
}

fn parse_frontmatter_or_fail(src : String) -> @frontmatter.Frontmatter {
  match @frontmatter.parse(src) {
    Ok(fm) => fm
    Err(_) => abort("expected frontmatter parse to succeed")
  }
}

test "schema accepts matching field types and optional absence" {
  let fm = parse_frontmatter_or_fail(
    "+++\n" +
    "title = \"Intro\"\n" +
    "date = 2026-03-11\n" +
    "published = true\n" +
    "order = 3\n" +
    "tags = [\"moonbit\", \"ssg\"]\n" +
    "+++\n" +
    "Body",
  )
  let errors = validate(fm, sample_schema())
  assert_eq(errors.length(), 0)
}

test "schema reports required field missing" {
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "published = true\n" + "tags = [\"moonbit\"]\n" + "+++\n",
  )
  let errors = validate(fm, sample_schema())
  assert_eq(errors.length(), 2)
  assert_eq(errors[0].field, "title")
  assert_eq(errors[0].message, "required field missing")
  assert_eq(errors[1].field, "date")
  assert_eq(errors[1].message, "required field missing")
}

test "schema reports field type mismatches for scalars and arrays" {
  let fm = parse_frontmatter_or_fail(
    "+++\n" +
    "title = 10\n" +
    "date = 2026/03/11\n" +
    "published = true\n" +
    "tags = [\"ok\", 2]\n" +
    "+++\n",
  )
  let errors = validate(fm, sample_schema())
  assert_eq(errors.length(), 3)
  assert_eq(errors[0].field, "title")
  assert_true(errors[0].message.contains("expected String"))
  assert_eq(errors[1].field, "date")
  assert_true(errors[1].message.contains("expected Date"))
  assert_eq(errors[2].field, "tags")
  assert_true(errors[2].message.contains("expected Array[String]"))
}

test "schema optional field still validates inner type when present" {
  let fm = parse_frontmatter_or_fail(
    "+++\n" +
    "title = \"Intro\"\n" +
    "date = 2026-03-11\n" +
    "published = false\n" +
    "tags = [\"moonbit\"]\n" +
    "summary = true\n" +
    "+++\n",
  )
  let errors = validate(fm, sample_schema())
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "summary")
  assert_true(errors[0].message.contains("expected String"))
}

test "schema accepts valid date field" {
  let schema : Schema = {
    name: "posts",
    fields: [{ name: "published_at", field_type: TDate, required: true }],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "published_at = 2026-03-11\n" + "+++\n",
  )
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 0)
}

test "schema rejects invalid date string format with typed error" {
  let schema : Schema = {
    name: "posts",
    fields: [{ name: "published_at", field_type: TDate, required: true }],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "published_at = 2026/03/11\n" + "+++\n",
  )
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "published_at")
  assert_true(errors[0].message.contains("expected Date"))
}

test "schema optional date field handles absence valid value and non-date error" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "published_at", field_type: TOptional(TDate), required: false },
    ],
  }

  let absent = parse_frontmatter_or_fail("+++\n+++\n")
  let absent_errors = validate(absent, schema)
  assert_eq(absent_errors.length(), 0)

  let present_valid = parse_frontmatter_or_fail(
    "+++\n" + "published_at = 2026-03-11\n" + "+++\n",
  )
  let valid_errors = validate(present_valid, schema)
  assert_eq(valid_errors.length(), 0)

  let present_invalid = parse_frontmatter_or_fail(
    "+++\n" + "published_at = false\n" + "+++\n",
  )
  let invalid_errors = validate(present_invalid, schema)
  assert_eq(invalid_errors.length(), 1)
  assert_eq(invalid_errors[0].field, "published_at")
  assert_true(invalid_errors[0].message.contains("expected Date"))
}

test "schema rejects unrecognized field not in schema" {
  let fm = parse_frontmatter_or_fail(
    "+++\n" +
    "title = \"Intro\"\n" +
    "date = 2026-03-11\n" +
    "published = true\n" +
    "tags = [\"moonbit\", \"ssg\"]\n" +
    "typo_field = \"should error\"\n" +
    "+++\n",
  )
  let errors = validate(fm, sample_schema())
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "typo_field")
  assert_true(errors[0].message.contains("unrecognized"))
}

test "schema accepts all fields when every key matches schema" {
  let fm = parse_frontmatter_or_fail(
    "+++\n" +
    "title = \"Complete Post\"\n" +
    "date = 2026-03-11\n" +
    "published = true\n" +
    "order = 42\n" +
    "tags = [\"moonbit\", \"ssg\"]\n" +
    "summary = \"A complete frontmatter\"\n" +
    "+++\n",
  )
  let errors = validate(fm, sample_schema())
  assert_eq(errors.length(), 0)
}
