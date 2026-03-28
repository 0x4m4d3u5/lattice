///|
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

///|
fn parse_frontmatter_or_fail(src : String) -> @frontmatter.Frontmatter {
  match @frontmatter.parse(src) {
    Ok(fm) => fm
    Err(_) => abort("expected frontmatter parse to succeed")
  }
}

///|
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

///|
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

///|
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

///|
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

///|
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

///|
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

///|
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

///|
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

///|
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

///|
test "TEnum accepts valid values" {
  let schema : Schema = {
    name: "posts",
    fields: [
      {
        name: "status",
        field_type: TEnum(["draft", "published", "archived"]),
        required: true,
      },
    ],
  }
  let fm_valid = parse_frontmatter_or_fail(
    "+++\n" + "status = \"published\"\n" + "+++\n",
  )
  let errors = validate(fm_valid, schema)
  assert_eq(errors.length(), 0)
}

///|
test "TEnum rejects invalid values" {
  let schema : Schema = {
    name: "posts",
    fields: [
      {
        name: "status",
        field_type: TEnum(["draft", "published", "archived"]),
        required: true,
      },
    ],
  }
  let fm_invalid = parse_frontmatter_or_fail(
    "+++\n" + "status = \"wip\"\n" + "+++\n",
  )
  let errors = validate(fm_invalid, schema)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "status")
  assert_eq(
    errors[0].message,
    "expected one of Enum[\"draft\",\"published\",\"archived\"], got \"wip\"",
  )
}

///|
test "TOptional(TEnum) accepts absent field" {
  let schema : Schema = {
    name: "posts",
    fields: [
      {
        name: "status",
        field_type: TOptional(TEnum(["draft", "published"])),
        required: false,
      },
    ],
  }
  let fm_absent = parse_frontmatter_or_fail("+++\n+++\n")
  let errors = validate(fm_absent, schema)
  assert_eq(errors.length(), 0)
}

///|
test "TOptional(TEnum) accepts valid value" {
  let schema : Schema = {
    name: "posts",
    fields: [
      {
        name: "status",
        field_type: TOptional(TEnum(["draft", "published"])),
        required: false,
      },
    ],
  }
  let fm_valid = parse_frontmatter_or_fail(
    "+++\n" + "status = \"draft\"\n" + "+++\n",
  )
  let errors = validate(fm_valid, schema)
  assert_eq(errors.length(), 0)
}

///|
test "TOptional(TEnum) rejects invalid value" {
  let schema : Schema = {
    name: "posts",
    fields: [
      {
        name: "status",
        field_type: TOptional(TEnum(["draft", "published"])),
        required: false,
      },
    ],
  }
  let fm_invalid = parse_frontmatter_or_fail(
    "+++\n" + "status = \"archived\"\n" + "+++\n",
  )
  let errors = validate(fm_invalid, schema)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "status")
  assert_eq(
    errors[0].message,
    "expected one of Enum[\"draft\",\"published\"], got \"archived\"",
  )
}

///|
test "TEnum rejects non-string values" {
  let schema : Schema = {
    name: "posts",
    fields: [
      {
        name: "status",
        field_type: TEnum(["draft", "published"]),
        required: true,
      },
    ],
  }
  let fm_non_string = parse_frontmatter_or_fail(
    "+++\n" + "status = 123\n" + "+++\n",
  )
  let errors = validate(fm_non_string, schema)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "status")
  assert_true(errors[0].message.contains("expected Enum"))
}

///|
test "TEnum in full schema validation" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "title", field_type: TString, required: true },
      {
        name: "status",
        field_type: TEnum(["draft", "published", "archived"]),
        required: true,
      },
      {
        name: "priority",
        field_type: TOptional(TEnum(["low", "medium", "high"])),
        required: false,
      },
    ],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" +
    "title = \"Post Title\"\n" +
    "status = \"published\"\n" +
    "priority = \"high\"\n" +
    "+++\n",
  )
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 0)
}

///|
test "TEnum empty allowed set always fails" {
  let schema : Schema = {
    name: "posts",
    fields: [{ name: "status", field_type: TEnum([]), required: true }],
  }
  let fm = parse_frontmatter_or_fail("+++\n" + "status = \"any\"\n" + "+++\n")
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "status")
  assert_eq(errors[0].message, "expected one of Enum[], got \"any\"")
}


///|
test "TUrl accepts https URL" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "canonical_url", field_type: TUrl, required: true },
    ],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "canonical_url = \"https://example.com\"\n" + "+++\n",
  )
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 0)
}

///|
test "TUrl accepts http URL" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "canonical_url", field_type: TUrl, required: true },
    ],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "canonical_url = \"http://example.com/path\"\n" + "+++\n",
  )
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 0)
}

///|
test "TUrl accepts relative URL" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "canonical_url", field_type: TUrl, required: true },
    ],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "canonical_url = \"/relative/path\"\n" + "+++\n",
  )
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 0)
}

///|
test "TUrl rejects empty string" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "canonical_url", field_type: TUrl, required: true },
    ],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "canonical_url = \"\"\n" + "+++\n",
  )
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "canonical_url")
  assert_true(errors[0].message.contains("expected Url"))
}

///|
test "TUrl rejects plain text" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "canonical_url", field_type: TUrl, required: true },
    ],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "canonical_url = \"not-a-url\"\n" + "+++\n",
  )
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "canonical_url")
  assert_true(errors[0].message.contains("expected Url"))
}

///|
test "TUrl rejects ftp URL" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "canonical_url", field_type: TUrl, required: true },
    ],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "canonical_url = \"ftp://example.com\"\n" + "+++\n",
  )
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "canonical_url")
  assert_true(errors[0].message.contains("expected Url"))
}

///|
test "TOptional(TUrl) absent field produces no error" {
  let schema : Schema = {
    name: "posts",
    fields: [
      {
        name: "og_url",
        field_type: TOptional(TUrl),
        required: false,
      },
    ],
  }
  let fm = parse_frontmatter_or_fail("+++\n+++\n")
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 0)
}

///|
test "schema with canonical_url:Url rejects invalid value" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "title", field_type: TString, required: true },
      { name: "canonical_url", field_type: TUrl, required: true },
    ],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" +
    "title = \"My Post\"\n" +
    "canonical_url = \"not-valid\"\n" +
    "+++\n",
  )
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "canonical_url")
  assert_true(errors[0].message.contains("expected Url"))
}



///|
test "TSlug accepts valid slug" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "category", field_type: TSlug, required: true },
    ],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "category = \"my-category\"\n" + "+++\n",
  )
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 0)
}

///|
test "TSlug accepts simple lowercase slug" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "category", field_type: TSlug, required: true },
    ],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "category = \"hello\"\n" + "+++\n",
  )
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 0)
}

///|
test "TSlug accepts numeric slug" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "category", field_type: TSlug, required: true },
    ],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "category = \"2026\"\n" + "+++\n",
  )
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 0)
}

///|
test "TSlug accepts hyphenated slug" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "category", field_type: TSlug, required: true },
    ],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "category = \"my-cool-post-2026\"\n" + "+++\n",
  )
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 0)
}

///|
test "TSlug rejects slug with spaces" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "category", field_type: TSlug, required: true },
    ],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "category = \"not a slug\"\n" + "+++\n",
  )
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "category")
  assert_true(
    errors[0].message.contains("expected a URL slug (lowercase alphanumeric and hyphens)"),
  )
}

///|
test "TSlug rejects empty string" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "category", field_type: TSlug, required: true },
    ],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "category = \"\"\n" + "+++\n",
  )
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "category")
  assert_true(
    errors[0].message.contains("expected a URL slug (lowercase alphanumeric and hyphens)"),
  )
}

///|
test "TSlug rejects uppercase letters" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "category", field_type: TSlug, required: true },
    ],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "category = \"My-Post\"\n" + "+++\n",
  )
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "category")
  assert_true(
    errors[0].message.contains("expected a URL slug (lowercase alphanumeric and hyphens)"),
  )
}

///|
test "TSlug rejects special characters" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "category", field_type: TSlug, required: true },
    ],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "category = \"hello_world!\"\n" + "+++\n",
  )
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 1)
}

///|
test "TSlug rejects non-string values" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "category", field_type: TSlug, required: true },
    ],
  }
  let fm = parse_frontmatter_or_fail("+++\n" + "category = 42\n" + "+++\n")
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "category")
  assert_true(errors[0].message.contains("expected Slug"))
}

///|
test "TOptional(TSlug) absent field produces no error" {
  let schema : Schema = {
    name: "posts",
    fields: [
      {
        name: "category",
        field_type: TOptional(TSlug),
        required: false,
      },
    ],
  }
  let fm = parse_frontmatter_or_fail("+++\n+++\n")
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 0)
}

///|
test "TOptional(TSlug) accepts valid slug when present" {
  let schema : Schema = {
    name: "posts",
    fields: [
      {
        name: "category",
        field_type: TOptional(TSlug),
        required: false,
      },
    ],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "category = \"tutorial\"\n" + "+++\n",
  )
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 0)
}
