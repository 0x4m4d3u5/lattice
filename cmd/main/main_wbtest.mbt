///|
test "explain_error_code returns explanation for E001" {
  let result = explain_error_code("E001")
  assert_true(result is Some(_))
  let text = result.unwrap()
  assert_true(text.contains("E001"))
  assert_true(text.contains("MissingRequiredFrontmatter"))
  assert_true(text.length() > 50)
}

///|
test "explain_error_code returns explanation for E002" {
  let result = explain_error_code("E002")
  assert_true(result is Some(_))
  let text = result.unwrap()
  assert_true(text.contains("E002"))
  assert_true(text.contains("SchemaError"))
}

///|
test "explain_error_code returns explanation for E003" {
  let result = explain_error_code("E003")
  assert_true(result is Some(_))
  let text = result.unwrap()
  assert_true(text.contains("E003"))
  assert_true(text.contains("FrontmatterError"))
}

///|
test "explain_error_code returns explanation for E004" {
  let result = explain_error_code("E004")
  assert_true(result is Some(_))
  let text = result.unwrap()
  assert_true(text.contains("E004"))
  assert_true(text.contains("BrokenWikilink"))
}

///|
test "explain_error_code returns explanation for E005" {
  let result = explain_error_code("E005")
  assert_true(result is Some(_))
  let text = result.unwrap()
  assert_true(text.contains("E005"))
  assert_true(text.contains("DanglingTagReference"))
}

///|
test "explain_error_code returns explanation for E006" {
  let result = explain_error_code("E006")
  assert_true(result is Some(_))
  let text = result.unwrap()
  assert_true(text.contains("E006"))
  assert_true(text.contains("TemplateSlotError"))
}

///|
test "explain_error_code returns explanation for E007" {
  let result = explain_error_code("E007")
  assert_true(result is Some(_))
  let text = result.unwrap()
  assert_true(text.contains("E007"))
  assert_true(text.contains("DataError"))
}

///|
test "explain_error_code returns explanation for E008" {
  let result = explain_error_code("E008")
  assert_true(result is Some(_))
  let text = result.unwrap()
  assert_true(text.contains("E008"))
  assert_true(text.contains("ShortcodeError"))
}

///|
test "explain_error_code returns explanation for E009" {
  let result = explain_error_code("E009")
  assert_true(result is Some(_))
  let text = result.unwrap()
  assert_true(text.contains("E009"))
  assert_true(text.contains("CollectionsError"))
}

///|
test "explain_error_code returns explanation for E010" {
  let result = explain_error_code("E010")
  assert_true(result is Some(_))
  let text = result.unwrap()
  assert_true(text.contains("E010"))
  assert_true(text.contains("DuplicateSlug"))
}

///|
test "explain_error_code returns explanation for E011" {
  let result = explain_error_code("E011")
  assert_true(result is Some(_))
  let text = result.unwrap()
  assert_true(text.contains("E011"))
  assert_true(text.contains("IOError"))
}

///|
test "explain_error_code returns None for unknown code E999" {
  let result = explain_error_code("E999")
  assert_true(result == None)
}

///|
test "explain_error_code returns None for empty string" {
  let result = explain_error_code("")
  assert_true(result == None)
}

///|
test "explain_error_code is case-insensitive for codes" {
  let lower = explain_error_code("e004")
  let upper = explain_error_code("E004")
  assert_true(lower is Some(_))
  assert_true(upper is Some(_))
  assert_true(lower == upper)
}

///|
test "explain_error_code accepts enum name (case-insensitive)" {
  let lower = explain_error_code("broken_wikilink")
  let upper = explain_error_code("BrokenWikilink")
  let code = explain_error_code("E004")
  assert_true(lower is Some(_))
  assert_true(upper is Some(_))
  assert_true(lower == code)
  assert_true(upper == code)
}

///|
test "list_error_codes mentions all 13 codes" {
  let listing = list_error_codes()
  assert_true(listing.contains("E001"))
  assert_true(listing.contains("E002"))
  assert_true(listing.contains("E003"))
  assert_true(listing.contains("E004"))
  assert_true(listing.contains("E005"))
  assert_true(listing.contains("E006"))
  assert_true(listing.contains("E007"))
  assert_true(listing.contains("E008"))
  assert_true(listing.contains("E009"))
  assert_true(listing.contains("E010"))
  assert_true(listing.contains("E011"))
  assert_true(listing.contains("E012"))
  assert_true(listing.contains("E013"))
  assert_true(listing.contains("MissingRequiredFrontmatter"))
  assert_true(listing.contains("SchemaError"))
  assert_true(listing.contains("FrontmatterError"))
  assert_true(listing.contains("BrokenWikilink"))
  assert_true(listing.contains("DanglingTagReference"))
  assert_true(listing.contains("TemplateSlotError"))
  assert_true(listing.contains("DataError"))
  assert_true(listing.contains("ShortcodeError"))
  assert_true(listing.contains("CollectionsError"))
  assert_true(listing.contains("DuplicateSlug"))
  assert_true(listing.contains("IOError"))
  assert_true(listing.contains("lattice explain"))
}

///|
test "list_error_codes includes one-line summary for each code" {
  let listing = list_error_codes()
  assert_true(listing.contains("required frontmatter field is absent"))
  assert_true(listing.contains("frontmatter value fails a schema constraint"))
  assert_true(
    listing.contains("frontmatter block is not valid TOML-like syntax"),
  )
  assert_true(listing.contains("[[target]] resolves to no page in the index"))
  assert_true(listing.contains("DataError"))
  assert_true(listing.contains("CollectionsError"))
  assert_true(listing.contains("DuplicateSlug"))
  assert_true(listing.contains("IOError"))
  assert_true(listing.contains("lattice explain"))
}

///|
test "explain and list include opt-in image alt policy E012" {
  assert_true(list_error_codes().contains("E012  MissingImageAlt"))
  for code in ["E012", "missing_image_alt"] {
    guard explain_error_code(code) is Some(text) else { abort("missing policy explanation") }
    assert_true(text.contains("require_image_alt=true"))
    assert_true(text.contains("alt=\"\""))
  }
}

///|
test "explain and list include site configuration errors" {
  assert_true(list_error_codes().contains("E013  ConfigError"))
  for code in ["E013", "config_error"] {
    let explanation = explain_error_code(code).unwrap()
    assert_true(explanation.contains("site configuration"))
    assert_true(explanation.contains("I/O error"))
  }
}
