///|
fn array_diagnostic_errors(
  source : String,
  field_type : @schema.FieldType,
) -> Array[@schema.ValidationError] {
  let schema : @schema.Schema = {
    name: "notes",
    fields: [{ name: "items", field_type, required: true, }],
  }
  @schema.validate(@frontmatter.parse(source).unwrap(), schema)
}

///|
test "array diagnostic identifies first invalid enum item and retains root field" {
  for
    source in [
      "---\nitems: [guide, guid, other]\n---\n", "+++\nitems = [\"guide\", \"guid\", \"other\"]\n+++\n",
    ] {
    let errors = array_diagnostic_errors(
      source,
      TArray(TEnum(["guide", "note"])),
    )
    assert_eq(errors.length(), 1)
    assert_eq(errors[0].field, "items")
    assert_eq(
      errors[0].message,
      "expected Array[Enum[\"guide\",\"note\"]] but got incompatible value; item 2: expected one of Enum[\"guide\",\"note\"], got \"guid\"",
    )
  }
}

///|
test "array diagnostics reuse scalar constraint messages" {
  let cases : Array[(String, @schema.FieldType, String)] = [
    ("[2, 0]", TInt(Some(1), Some(5)), "expected Int in range [1, 5], got: 0"),
    (
      "[2.0, 0.0]",
      TFloat(Some(1.0), Some(5.0)),
      "expected Float in range [1, 5], got: 0",
    ),
    (
      "[okay, x]",
      TString(Some(2), None),
      "expected String with minlen=2, got length 1: \"x\"",
    ),
    (
      "[good, Bad]",
      TSlug,
      "expected a URL slug (lowercase alphanumeric and hyphens), got: \"Bad\"",
    ),
    (
      "[2026-01-02, 2025-01-01]",
      TDate(Some("2026-01-01"), None),
      "expected Date after 2026-01-01, got: 2025-01-01",
    ),
    ("[true, 2]", TBool, "expected Bool but got incompatible value"),
  ]
  for (raw, field_type, detail) in cases {
    let errors = array_diagnostic_errors(
      "---\nitems: " + raw + "\n---\n",
      TArray(field_type),
    )
    assert_eq(errors.length(), 1)
    assert_eq(
      errors[0].message,
      "expected " +
      @schema.field_type_name(TArray(field_type)) +
      " but got incompatible value; item 2: " +
      detail,
    )
  }
}

///|
test "nested array diagnostics retain each one based item position through optionals" {
  let field_type : @schema.FieldType = TOptional(
    TArray(TOptional(TArray(TOptional(TInt(Some(1), None))))),
  )
  let errors = array_diagnostic_errors(
    "---\nitems: [[1], [2, 0], [0]]\n---\n", field_type,
  )
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].field, "items")
  assert_eq(
    errors[0].message,
    "expected Array[Optional[Array[Optional[Int(min=1)]]]] but got incompatible value; item 2: expected Array[Optional[Int(min=1)]] but got incompatible value; item 2: expected Int in range [1, ∞), got: 0",
  )
}

///|
test "array diagnostics distinguish wrong containers from invalid elements" {
  let errors = array_diagnostic_errors(
    "---\nitems: nope\n---\n",
    TArray(TInt(None, None)),
  )
  assert_eq(errors.length(), 1)
  assert_eq(errors[0].message, "expected Array[Int] but got incompatible value")
  let nested = array_diagnostic_errors(
    "---\nitems: [[1], nope]\n---\n",
    TArray(TArray(TInt(None, None))),
  )
  assert_eq(nested.length(), 1)
  assert_eq(
    nested[0].message,
    "expected Array[Array[Int]] but got incompatible value; item 2: expected Array[Int] but got incompatible value",
  )
}

///|
test "valid empty and optional nested arrays keep acceptance" {
  for raw in ["[]", "[[]]", "[[1], [], [2, 3]]"] {
    assert_eq(
      array_diagnostic_errors(
        "---\nitems: " + raw + "\n---\n",
        TArray(TOptional(TArray(TInt(Some(1), None)))),
      ).length(),
      0,
    )
  }
}

///|
test "repeated optional item wrappers expose constraints without changing scalar diagnostics" {
  let optional : @schema.FieldType = TOptional(TOptional(TInt(Some(1), None)))
  let items = array_diagnostic_errors(
    "---\nitems: [1, 0]\n---\n",
    TArray(optional),
  )
  assert_eq(items.length(), 1)
  assert_eq(
    items[0].message,
    "expected Array[Optional[Optional[Int(min=1)]]] but got incompatible value; item 2: expected Int in range [1, ∞), got: 0",
  )
  let scalar = array_diagnostic_errors("---\nitems: 0\n---\n", optional)
  assert_eq(scalar.length(), 1)
  assert_eq(
    scalar[0].message,
    "expected Optional[Int(min=1)] but got incompatible value",
  )
}
