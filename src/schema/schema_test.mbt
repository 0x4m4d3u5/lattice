///|
fn sample_schema() -> Schema {
  {
    name: "posts",
    fields: [
      { name: "title", field_type: TString, required: true },
      { name: "date", field_type: TDate(None, None), required: true },
      { name: "published", field_type: TBool, required: true },
      { name: "order", field_type: TInt(None, None), required: false },
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
    fields: [
      { name: "published_at", field_type: TDate(None, None), required: true },
    ],
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
    fields: [
      { name: "published_at", field_type: TDate(None, None), required: true },
    ],
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
      {
        name: "published_at",
        field_type: TOptional(TDate(None, None)),
        required: false,
      },
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
    fields: [{ name: "canonical_url", field_type: TUrl, required: true }],
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
    fields: [{ name: "canonical_url", field_type: TUrl, required: true }],
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
    fields: [{ name: "canonical_url", field_type: TUrl, required: true }],
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
    fields: [{ name: "canonical_url", field_type: TUrl, required: true }],
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
    fields: [{ name: "canonical_url", field_type: TUrl, required: true }],
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
    fields: [{ name: "canonical_url", field_type: TUrl, required: true }],
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
    fields: [{ name: "og_url", field_type: TOptional(TUrl), required: false }],
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
    fields: [{ name: "category", field_type: TSlug, required: true }],
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
    fields: [{ name: "category", field_type: TSlug, required: true }],
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
    fields: [{ name: "category", field_type: TSlug, required: true }],
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
    fields: [{ name: "category", field_type: TSlug, required: true }],
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
    fields: [{ name: "category", field_type: TSlug, required: true }],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "category = \"not a slug\"\n" + "+++\n",
  )
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "category")
  assert_true(
    errors[0].message.contains(
      "expected a URL slug (lowercase alphanumeric and hyphens)",
    ),
  )
}

///|
test "TSlug rejects empty string" {
  let schema : Schema = {
    name: "posts",
    fields: [{ name: "category", field_type: TSlug, required: true }],
  }
  let fm = parse_frontmatter_or_fail("+++\n" + "category = \"\"\n" + "+++\n")
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "category")
  assert_true(
    errors[0].message.contains(
      "expected a URL slug (lowercase alphanumeric and hyphens)",
    ),
  )
}

///|
test "TSlug rejects uppercase letters" {
  let schema : Schema = {
    name: "posts",
    fields: [{ name: "category", field_type: TSlug, required: true }],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "category = \"My-Post\"\n" + "+++\n",
  )
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "category")
  assert_true(
    errors[0].message.contains(
      "expected a URL slug (lowercase alphanumeric and hyphens)",
    ),
  )
}

///|
test "TSlug rejects special characters" {
  let schema : Schema = {
    name: "posts",
    fields: [{ name: "category", field_type: TSlug, required: true }],
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
    fields: [{ name: "category", field_type: TSlug, required: true }],
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
      { name: "category", field_type: TOptional(TSlug), required: false },
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
      { name: "category", field_type: TOptional(TSlug), required: false },
    ],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "category = \"tutorial\"\n" + "+++\n",
  )
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 0)
}

// ── TRef tests ────────────────────────────────────────────────────────────────

///|
test "TRef structural validation accepts valid slug string" {
  let schema : Schema = {
    name: "posts",
    fields: [{ name: "related_post", field_type: TRef(None), required: true }],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "related_post = \"my-post\"\n" + "+++\n",
  )
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 0)
}

///|
test "TRef structural validation rejects non-string values" {
  let schema : Schema = {
    name: "posts",
    fields: [{ name: "related_post", field_type: TRef(None), required: true }],
  }
  let fm = parse_frontmatter_or_fail("+++\n" + "related_post = 42\n" + "+++\n")
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "related_post")
  assert_true(errors[0].message.contains("Ref"))
}

///|
test "TRef structural validation rejects invalid slug format" {
  let schema : Schema = {
    name: "posts",
    fields: [{ name: "related_post", field_type: TRef(None), required: true }],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "related_post = \"Not A Slug\"\n" + "+++\n",
  )
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "related_post")
  assert_true(errors[0].message.contains("expected a valid slug reference"))
}

///|
test "TRef with collection constraint structural validation accepts valid slug" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "related_post", field_type: TRef(Some("blog")), required: true },
    ],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "related_post = \"my-post\"\n" + "+++\n",
  )
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 0)
}

///|
test "TOptional(TRef) absent field produces no error" {
  let schema : Schema = {
    name: "posts",
    fields: [
      {
        name: "related_post",
        field_type: TOptional(TRef(None)),
        required: false,
      },
    ],
  }
  let fm = parse_frontmatter_or_fail("+++\n+++\n")
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 0)
}

///|
test "validate_refs: slug present in page index produces no error" {
  let schema : Schema = {
    name: "posts",
    fields: [{ name: "related_post", field_type: TRef(None), required: true }],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "related_post = \"my-post\"\n" + "+++\n",
  )
  let page_index : Map[String, String] = Map::new()
  page_index.set("my-post", "blog")
  let errors = validate_refs(fm, schema, page_index)
  assert_eq(errors.length(), 0)
}

///|
test "validate_refs: slug absent from page index produces error" {
  let schema : Schema = {
    name: "posts",
    fields: [{ name: "related_post", field_type: TRef(None), required: true }],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "related_post = \"missing-post\"\n" + "+++\n",
  )
  let page_index : Map[String, String] = Map::new()
  page_index.set("other-post", "blog")
  let errors = validate_refs(fm, schema, page_index)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "related_post")
  assert_true(
    errors[0].message.contains("references unknown slug 'missing-post'"),
  )
}

///|
test "validate_refs: collection constraint satisfied produces no error" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "related_post", field_type: TRef(Some("blog")), required: true },
    ],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "related_post = \"my-post\"\n" + "+++\n",
  )
  let page_index : Map[String, String] = Map::new()
  page_index.set("my-post", "blog")
  let errors = validate_refs(fm, schema, page_index)
  assert_eq(errors.length(), 0)
}

///|
test "validate_refs: slug in wrong collection produces error" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "related_post", field_type: TRef(Some("blog")), required: true },
    ],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "related_post = \"my-page\"\n" + "+++\n",
  )
  let page_index : Map[String, String] = Map::new()
  page_index.set("my-page", "pages")
  let errors = validate_refs(fm, schema, page_index)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "related_post")
  assert_true(
    errors[0].message.contains("from collection 'pages' but expected 'blog'"),
  )
}

///|
test "validate_refs: non-TRef fields are ignored" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "title", field_type: TString, required: true },
      { name: "related_post", field_type: TRef(None), required: true },
    ],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" +
    "title = \"Hello\"\n" +
    "related_post = \"existing-slug\"\n" +
    "+++\n",
  )
  let page_index : Map[String, String] = Map::new()
  page_index.set("existing-slug", "blog")
  let errors = validate_refs(fm, schema, page_index)
  assert_eq(errors.length(), 0)
}

///|
test "validate_refs: TOptional(TRef) absent field produces no error" {
  let schema : Schema = {
    name: "posts",
    fields: [
      {
        name: "related_post",
        field_type: TOptional(TRef(None)),
        required: false,
      },
    ],
  }
  let fm = parse_frontmatter_or_fail("+++\n+++\n")
  let page_index : Map[String, String] = Map::new()
  page_index.set("some-post", "blog")
  let errors = validate_refs(fm, schema, page_index)
  assert_eq(errors.length(), 0)
}

///|
test "validate_refs: multiple TRef fields report all broken refs" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "related_post", field_type: TRef(None), required: true },
      { name: "featured_post", field_type: TRef(None), required: true },
    ],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" +
    "related_post = \"missing-a\"\n" +
    "featured_post = \"missing-b\"\n" +
    "+++\n",
  )
  let page_index : Map[String, String] = Map::new()
  let errors = validate_refs(fm, schema, page_index)
  assert_eq(errors.length(), 2)
  assert_eq(errors[0].field, "related_post")
  assert_true(errors[0].message.contains("references unknown slug 'missing-a'"))
  assert_eq(errors[1].field, "featured_post")
  assert_true(errors[1].message.contains("references unknown slug 'missing-b'"))
}

///|
test "field_type_name reports Ref for TRef(None)" {
  // Verify TRef(None) structural validation passes with a valid slug string
  let schema : Schema = {
    name: "posts",
    fields: [{ name: "related_post", field_type: TRef(None), required: true }],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "related_post = \"valid-slug\"\n" + "+++\n",
  )
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 0)
}

///|
test "field_type_name reports Ref[collection] for TRef(Some)" {
  // Verify TRef(Some("blog")) structural validation rejects non-string
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "related_post", field_type: TRef(Some("blog")), required: true },
    ],
  }
  let fm = parse_frontmatter_or_fail("+++\n" + "related_post = 42\n" + "+++\n")
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "related_post")
}

// ── TArray(TRef) cross-reference validation tests ─────────────────────────────

///|
test "validate_refs: TArray(TRef(None)) all slugs present produces no error" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "related_posts", field_type: TArray(TRef(None)), required: true },
    ],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "related_posts = [\"post-a\", \"post-b\", \"post-c\"]\n" + "+++\n",
  )
  let page_index : Map[String, String] = Map::new()
  page_index.set("post-a", "blog")
  page_index.set("post-b", "blog")
  page_index.set("post-c", "blog")
  let errors = validate_refs(fm, schema, page_index)
  assert_eq(errors.length(), 0)
}

///|
test "validate_refs: TArray(TRef(None)) one slug missing produces one error" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "related_posts", field_type: TArray(TRef(None)), required: true },
    ],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" +
    "related_posts = [\"post-a\", \"missing-post\", \"post-c\"]\n" +
    "+++\n",
  )
  let page_index : Map[String, String] = Map::new()
  page_index.set("post-a", "blog")
  page_index.set("post-c", "blog")
  let errors = validate_refs(fm, schema, page_index)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "related_posts")
  assert_true(
    errors[0].message.contains(
      "TRef: related_posts[1]: unknown slug 'missing-post'",
    ),
  )
}

///|
test "validate_refs: TArray(TRef(Some)) slug in wrong collection produces error" {
  let schema : Schema = {
    name: "posts",
    fields: [
      {
        name: "related_posts",
        field_type: TArray(TRef(Some("blog"))),
        required: true,
      },
    ],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" + "related_posts = [\"post-a\", \"wrong-page\"]\n" + "+++\n",
  )
  let page_index : Map[String, String] = Map::new()
  page_index.set("post-a", "blog")
  page_index.set("wrong-page", "pages")
  let errors = validate_refs(fm, schema, page_index)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "related_posts")
  assert_true(
    errors[0].message.contains(
      "TRef: related_posts[1]: references slug 'wrong-page' from collection 'pages' but expected 'blog'",
    ),
  )
}

///|
test "validate_refs: TOptional(TArray(TRef(None))) absent field produces no error" {
  let schema : Schema = {
    name: "posts",
    fields: [
      {
        name: "related_posts",
        field_type: TOptional(TArray(TRef(None))),
        required: false,
      },
    ],
  }
  let fm = parse_frontmatter_or_fail("+++\n+++\n")
  let page_index : Map[String, String] = Map::new()
  page_index.set("some-post", "blog")
  let errors = validate_refs(fm, schema, page_index)
  assert_eq(errors.length(), 0)
}

///|
test "validate_refs: TArray(TRef(None)) empty array produces no error" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "related_posts", field_type: TArray(TRef(None)), required: false },
    ],
  }
  let fm = parse_frontmatter_or_fail("+++\n" + "related_posts = []\n" + "+++\n")
  let page_index : Map[String, String] = Map::new()
  let errors = validate_refs(fm, schema, page_index)
  assert_eq(errors.length(), 0)
}

///|
test "validate_refs: TArray(TRef(None)) all slugs missing produces errors for each" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "related_posts", field_type: TArray(TRef(None)), required: true },
    ],
  }
  let fm = parse_frontmatter_or_fail(
    "+++\n" +
    "related_posts = [\"missing-a\", \"missing-b\", \"missing-c\"]\n" +
    "+++\n",
  )
  let page_index : Map[String, String] = Map::new()
  let errors = validate_refs(fm, schema, page_index)
  assert_eq(errors.length(), 3)
  assert_true(
    errors[0].message.contains(
      "TRef: related_posts[0]: unknown slug 'missing-a'",
    ),
  )
  assert_true(
    errors[1].message.contains(
      "TRef: related_posts[1]: unknown slug 'missing-b'",
    ),
  )
  assert_true(
    errors[2].message.contains(
      "TRef: related_posts[2]: unknown slug 'missing-c'",
    ),
  )
}

// ── TInt bounds validation tests ──────────────────────────────────────────────

///|
test "TInt(None, None) validates any integer" {
  let schema : Schema = {
    name: "posts",
    fields: [{ name: "count", field_type: TInt(None, None), required: true }],
  }
  let fm_neg = parse_frontmatter_or_fail("+++\n" + "count = -999\n" + "+++\n")
  let fm_zero = parse_frontmatter_or_fail("+++\n" + "count = 0\n" + "+++\n")
  let fm_pos = parse_frontmatter_or_fail("+++\n" + "count = 999\n" + "+++\n")
  assert_eq(validate(fm_neg, schema).length(), 0)
  assert_eq(validate(fm_zero, schema).length(), 0)
  assert_eq(validate(fm_pos, schema).length(), 0)
}

///|
test "TInt(Some(1), None) rejects 0 and accepts 1 and above" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "priority", field_type: TInt(Some(1), None), required: true },
    ],
  }
  let fm_zero = parse_frontmatter_or_fail("+++\n" + "priority = 0\n" + "+++\n")
  let errors_zero = validate(fm_zero, schema)
  assert_eq(errors_zero.length(), 1)
  assert_eq(errors_zero[0].field, "priority")
  assert_true(errors_zero[0].message.contains("expected Int in range [1, ∞)"))
  assert_true(errors_zero[0].message.contains("got: 0"))

  let fm_one = parse_frontmatter_or_fail("+++\n" + "priority = 1\n" + "+++\n")
  assert_eq(validate(fm_one, schema).length(), 0)

  let fm_large = parse_frontmatter_or_fail(
    "+++\n" + "priority = 1000\n" + "+++\n",
  )
  assert_eq(validate(fm_large, schema).length(), 0)
}

///|
test "TInt(None, Some(100)) rejects 101 and accepts 100 and below" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "score", field_type: TInt(None, Some(100)), required: true },
    ],
  }
  let fm_over = parse_frontmatter_or_fail("+++\n" + "score = 101\n" + "+++\n")
  let errors_over = validate(fm_over, schema)
  assert_eq(errors_over.length(), 1)
  assert_eq(errors_over[0].field, "score")
  assert_true(
    errors_over[0].message.contains("expected Int in range (-∞, 100]"),
  )
  assert_true(errors_over[0].message.contains("got: 101"))

  let fm_hundred = parse_frontmatter_or_fail(
    "+++\n" + "score = 100\n" + "+++\n",
  )
  assert_eq(validate(fm_hundred, schema).length(), 0)

  let fm_neg = parse_frontmatter_or_fail("+++\n" + "score = -1\n" + "+++\n")
  assert_eq(validate(fm_neg, schema).length(), 0)
}

///|
test "TInt(Some(1), Some(100)) rejects 0 and 101, accepts 50" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "percent", field_type: TInt(Some(1), Some(100)), required: true },
    ],
  }
  let fm_under = parse_frontmatter_or_fail("+++\n" + "percent = 0\n" + "+++\n")
  let errors_under = validate(fm_under, schema)
  assert_eq(errors_under.length(), 1)
  assert_eq(errors_under[0].field, "percent")
  assert_true(
    errors_under[0].message.contains("expected Int in range [1, 100]"),
  )
  assert_true(errors_under[0].message.contains("got: 0"))

  let fm_over = parse_frontmatter_or_fail("+++\n" + "percent = 101\n" + "+++\n")
  let errors_over = validate(fm_over, schema)
  assert_eq(errors_over.length(), 1)
  assert_eq(errors_over[0].field, "percent")
  assert_true(errors_over[0].message.contains("expected Int in range [1, 100]"))
  assert_true(errors_over[0].message.contains("got: 101"))

  let fm_mid = parse_frontmatter_or_fail("+++\n" + "percent = 50\n" + "+++\n")
  assert_eq(validate(fm_mid, schema).length(), 0)

  let fm_edge_low = parse_frontmatter_or_fail(
    "+++\n" + "percent = 1\n" + "+++\n",
  )
  assert_eq(validate(fm_edge_low, schema).length(), 0)

  let fm_edge_high = parse_frontmatter_or_fail(
    "+++\n" + "percent = 100\n" + "+++\n",
  )
  assert_eq(validate(fm_edge_high, schema).length(), 0)
}

///|
test "TOptional(TInt(Some(1), Some(10))) absent field produces no error" {
  let schema : Schema = {
    name: "posts",
    fields: [
      {
        name: "rating",
        field_type: TOptional(TInt(Some(1), Some(10))),
        required: false,
      },
    ],
  }
  let fm_absent = parse_frontmatter_or_fail("+++\n+++\n")
  assert_eq(validate(fm_absent, schema).length(), 0)
}

///|
test "TOptional(TInt(Some(1), Some(10))) out-of-range produces error" {
  let schema : Schema = {
    name: "posts",
    fields: [
      {
        name: "rating",
        field_type: TOptional(TInt(Some(1), Some(10))),
        required: false,
      },
    ],
  }
  let fm = parse_frontmatter_or_fail("+++\n" + "rating = 11\n" + "+++\n")
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "rating")
  assert_true(errors[0].message.contains("expected Int in range [1, 10]"))
}

///|
test "TInt bounds rejects non-integer values" {
  let schema : Schema = {
    name: "posts",
    fields: [
      { name: "count", field_type: TInt(Some(1), Some(100)), required: true },
    ],
  }
  let fm_str = parse_frontmatter_or_fail(
    "+++\n" + "count = \"hello\"\n" + "+++\n",
  )
  let errors = validate(fm_str, schema)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "count")
  assert_true(errors[0].message.contains("expected Int"))
}

// ── TDate bounds validation tests ─────────────────────────────────────────────

///|
test "TDate(None, None) accepts any valid date" {
  let schema : Schema = {
    name: "posts",
    fields: [{ name: "date", field_type: TDate(None, None), required: true }],
  }
  let fm_early = parse_frontmatter_or_fail(
    "+++\n" + "date = 2019-01-01\n" + "+++\n",
  )
  let fm_mid = parse_frontmatter_or_fail(
    "+++\n" + "date = 2025-06-15\n" + "+++\n",
  )
  let fm_late = parse_frontmatter_or_fail(
    "+++\n" + "date = 2030-12-31\n" + "+++\n",
  )
  assert_eq(validate(fm_early, schema).length(), 0)
  assert_eq(validate(fm_mid, schema).length(), 0)
  assert_eq(validate(fm_late, schema).length(), 0)
}

///|
test "TDate(Some(\"2020-01-01\"), None) rejects 2019-12-31, accepts 2020-01-02" {
  let schema : Schema = {
    name: "posts",
    fields: [
      {
        name: "date",
        field_type: TDate(Some("2020-01-01"), None),
        required: true,
      },
    ],
  }
  // Boundary: equal to after (exclusive) — rejected
  let fm_equal = parse_frontmatter_or_fail(
    "+++\n" + "date = 2020-01-01\n" + "+++\n",
  )
  let errors_eq = validate(fm_equal, schema)
  assert_eq(errors_eq.length(), 1)
  assert_eq(errors_eq[0].field, "date")
  assert_true(errors_eq[0].message.contains("expected Date after 2020-01-01"))
  assert_true(errors_eq[0].message.contains("got: 2020-01-01"))

  // Before the after bound — rejected
  let fm_before = parse_frontmatter_or_fail(
    "+++\n" + "date = 2019-12-31\n" + "+++\n",
  )
  let errors_before = validate(fm_before, schema)
  assert_eq(errors_before.length(), 1)
  assert_true(
    errors_before[0].message.contains("expected Date after 2020-01-01"),
  )
  assert_true(errors_before[0].message.contains("got: 2019-12-31"))

  // After the after bound — accepted
  let fm_after = parse_frontmatter_or_fail(
    "+++\n" + "date = 2020-01-02\n" + "+++\n",
  )
  assert_eq(validate(fm_after, schema).length(), 0)

  // Far future — accepted
  let fm_far = parse_frontmatter_or_fail(
    "+++\n" + "date = 2099-12-31\n" + "+++\n",
  )
  assert_eq(validate(fm_far, schema).length(), 0)
}

///|
test "TDate(None, Some(\"2030-01-01\")) accepts 2029-12-31, rejects 2030-01-02" {
  let schema : Schema = {
    name: "posts",
    fields: [
      {
        name: "date",
        field_type: TDate(None, Some("2030-01-01")),
        required: true,
      },
    ],
  }
  // Before the before bound — accepted
  let fm_before = parse_frontmatter_or_fail(
    "+++\n" + "date = 2029-12-31\n" + "+++\n",
  )
  assert_eq(validate(fm_before, schema).length(), 0)

  // Far past — accepted
  let fm_far = parse_frontmatter_or_fail(
    "+++\n" + "date = 2000-01-01\n" + "+++\n",
  )
  assert_eq(validate(fm_far, schema).length(), 0)

  // Boundary: equal to before (exclusive) — rejected
  let fm_equal = parse_frontmatter_or_fail(
    "+++\n" + "date = 2030-01-01\n" + "+++\n",
  )
  let errors_eq = validate(fm_equal, schema)
  assert_eq(errors_eq.length(), 1)
  assert_true(errors_eq[0].message.contains("expected Date before 2030-01-01"))
  assert_true(errors_eq[0].message.contains("got: 2030-01-01"))

  // After the before bound — rejected
  let fm_after = parse_frontmatter_or_fail(
    "+++\n" + "date = 2030-01-02\n" + "+++\n",
  )
  let errors_after = validate(fm_after, schema)
  assert_eq(errors_after.length(), 1)
  assert_true(
    errors_after[0].message.contains("expected Date before 2030-01-01"),
  )
  assert_true(errors_after[0].message.contains("got: 2030-01-02"))
}

///|
test "TDate(Some(\"2020-01-01\"), Some(\"2030-01-01\")) accepts 2025-06-15, rejects boundaries" {
  let schema : Schema = {
    name: "posts",
    fields: [
      {
        name: "date",
        field_type: TDate(Some("2020-01-01"), Some("2030-01-01")),
        required: true,
      },
    ],
  }
  // In range — accepted
  let fm_mid = parse_frontmatter_or_fail(
    "+++\n" + "date = 2025-06-15\n" + "+++\n",
  )
  assert_eq(validate(fm_mid, schema).length(), 0)

  // Just above after — accepted
  let fm_after_ok = parse_frontmatter_or_fail(
    "+++\n" + "date = 2020-01-02\n" + "+++\n",
  )
  assert_eq(validate(fm_after_ok, schema).length(), 0)

  // Just below before — accepted
  let fm_before_ok = parse_frontmatter_or_fail(
    "+++\n" + "date = 2029-12-31\n" + "+++\n",
  )
  assert_eq(validate(fm_before_ok, schema).length(), 0)

  // Equal to after (exclusive) — rejected
  let fm_lo = parse_frontmatter_or_fail(
    "+++\n" + "date = 2020-01-01\n" + "+++\n",
  )
  let errors_lo = validate(fm_lo, schema)
  assert_eq(errors_lo.length(), 1)
  assert_true(
    errors_lo[0].message.contains(
      "expected Date after 2020-01-01 and before 2030-01-01",
    ),
  )
  assert_true(errors_lo[0].message.contains("got: 2020-01-01"))

  // Equal to before (exclusive) — rejected
  let fm_hi = parse_frontmatter_or_fail(
    "+++\n" + "date = 2030-01-01\n" + "+++\n",
  )
  let errors_hi = validate(fm_hi, schema)
  assert_eq(errors_hi.length(), 1)
  assert_true(
    errors_hi[0].message.contains(
      "expected Date after 2020-01-01 and before 2030-01-01",
    ),
  )

  // Far before — rejected
  let fm_far_before = parse_frontmatter_or_fail(
    "+++\n" + "date = 2019-12-31\n" + "+++\n",
  )
  assert_eq(validate(fm_far_before, schema).length(), 1)

  // Far after — rejected
  let fm_far_after = parse_frontmatter_or_fail(
    "+++\n" + "date = 2030-01-02\n" + "+++\n",
  )
  assert_eq(validate(fm_far_after, schema).length(), 1)
}

///|
test "TOptional(TDate(Some(\"2020-01-01\"), None)) absent field produces no error" {
  let schema : Schema = {
    name: "posts",
    fields: [
      {
        name: "date",
        field_type: TOptional(TDate(Some("2020-01-01"), None)),
        required: false,
      },
    ],
  }
  let fm_absent = parse_frontmatter_or_fail("+++\n+++\n")
  assert_eq(validate(fm_absent, schema).length(), 0)
}

///|
test "TOptional(TDate(Some(\"2020-01-01\"), None)) out-of-range produces error" {
  let schema : Schema = {
    name: "posts",
    fields: [
      {
        name: "date",
        field_type: TOptional(TDate(Some("2020-01-01"), None)),
        required: false,
      },
    ],
  }
  let fm = parse_frontmatter_or_fail("+++\n" + "date = 2019-12-31\n" + "+++\n")
  let errors = validate(fm, schema)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "date")
  assert_true(errors[0].message.contains("expected Date after 2020-01-01"))
}

///|
test "TDate bounds rejects non-date values" {
  let schema : Schema = {
    name: "posts",
    fields: [
      {
        name: "date",
        field_type: TDate(Some("2020-01-01"), Some("2030-01-01")),
        required: true,
      },
    ],
  }
  let fm_str = parse_frontmatter_or_fail(
    "+++\n" + "date = \"hello\"\n" + "+++\n",
  )
  let errors = validate(fm_str, schema)
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "date")
  assert_true(errors[0].message.contains("expected Date"))
}
