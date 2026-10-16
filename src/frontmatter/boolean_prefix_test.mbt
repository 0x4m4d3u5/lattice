///|
test "boolean-prefixed plain strings agree in flow and block lists" {
  let expected = [
    "true-crime", "falsehood", "true story", "false positive", "trueÉ", "false🌱",
  ]
  for
    value in [
      "[true-crime, falsehood, true story, false positive, trueÉ, false🌱]", "\n  - true-crime\n  - falsehood\n  - true story\n  - false positive\n  - trueÉ\n  - false🌱",
    ] {
    let fm = match
      @frontmatter.parse("---\ntags: " + value + "\n---\nBody.\n") {
      Ok(fm) => fm
      Err(message) => abort(message)
    }
    guard fm.fields.get("tags") is Some(@frontmatter.FArray(items)) else {
      abort("plain-string tag lists must remain arrays")
    }
    assert_eq(items.length(), expected.length())
    for i in 0..<expected.length() {
      guard items[i] is @frontmatter.FStr(value) else {
        abort("expected a string tag")
      }
      assert_eq(value, expected[i])
    }
    assert_eq(fm.body, "Body.\n")
  }
}

///|
test "whole boolean scalars retain types in nested flow arrays" {
  let fm = match
    @frontmatter.parse(
      "---\nvalues: [true , false\t, [true, false], \"true\", \"false\"]\n---\n",
    ) {
    Ok(fm) => fm
    Err(message) => abort(message)
  }
  guard fm.fields.get("values") is Some(@frontmatter.FArray(items)) else {
    abort("expected an array")
  }
  assert_eq(items.length(), 5)
  for i in 0..<2 {
    guard items[i] is @frontmatter.FBool(value) else {
      abort("expected a boolean")
    }
    assert_eq(value, i == 0)
    guard items[i + 3] is @frontmatter.FStr(text) else {
      abort("quoted booleans must stay strings")
    }
    assert_eq(text, if i == 0 { "true" } else { "false" })
  }
  guard items[2] is @frontmatter.FArray(nested) else {
    abort("expected a nested array")
  }
  assert_eq(nested.length(), 2)
  for i in 0..<2 {
    guard nested[i] is @frontmatter.FBool(value) else {
      abort("expected a nested boolean")
    }
    assert_eq(value, i == 0)
  }
}
