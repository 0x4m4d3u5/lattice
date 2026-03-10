fn sample_schema() -> Schema {
  {
    name: "posts",
    fields: [
      { name: "title", field_type: TString, required: true },
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

///|
test "schema accepts matching field types and optional absence" {
  let fm = parse_frontmatter_or_fail(
    "---\n" +
    "title = \"Intro\"\n" +
    "published = true\n" +
    "order = 3\n" +
    "tags = [\"moonbit\", \"ssg\"]\n" +
    "---\n" +
    "Body",
  )
  let errors = validate(fm, sample_schema())
  assert_eq(errors.length(), 0)
}

///|
test "schema reports required field missing" {
  let fm = parse_frontmatter_or_fail(
    "---\n" + "published = true\n" + "tags = [\"moonbit\"]\n" + "---\n",
  )
  let errors = validate(fm, sample_schema())
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "title")
  assert_eq(errors[0].message, "required field missing")
}

///|
test "schema reports field type mismatches for scalars and arrays" {
  let fm = parse_frontmatter_or_fail(
    "---\n" +
    "title = 10\n" +
    "published = true\n" +
    "tags = [\"ok\", 2]\n" +
    "---\n",
  )
  let errors = validate(fm, sample_schema())
  assert_eq(errors.length(), 2)
  assert_eq(errors[0].field, "title")
  assert_true(errors[0].message.contains("expected String"))
  assert_eq(errors[1].field, "tags")
  assert_true(errors[1].message.contains("expected Array[String]"))
}

///|
test "schema optional field still validates inner type when present" {
  let fm = parse_frontmatter_or_fail(
    "---\n" +
    "title = \"Intro\"\n" +
    "published = false\n" +
    "tags = [\"moonbit\"]\n" +
    "summary = true\n" +
    "---\n",
  )
  let errors = validate(fm, sample_schema())
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "summary")
  assert_true(errors[0].message.contains("expected String"))
}
