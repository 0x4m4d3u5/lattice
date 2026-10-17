///|
test "explicit positive numbers retain YAML and TOML scalar types" {
  // Independent expectations: PyYAML 6.0.3 and Python tomllib.
  for
    source in [
      "---\ncount: +42\nzero: +0\nmaximum: +2147483647\nweight: +1.5\nvalues: [+42, +1.5]\n---\n",
      "+++\ncount = +42\nzero = +0\nmaximum = +2147483647\nweight = +1.5\nvalues = [+42, +1.5]\n+++\n",
      "---\ncount: +42\nzero: +0\nmaximum: +2147483647\nweight: +1.5\nvalues:\n  - +42\n  - +1.5\n---\n",
    ] {
    let fm = match @frontmatter.parse(source) {
      Ok(fm) => fm
      Err(message) => abort(message)
    }
    assert_true(fm.fields.get("count") is Some(@frontmatter.FInt(42)))
    assert_true(fm.fields.get("zero") is Some(@frontmatter.FInt(0)))
    assert_true(fm.fields.get("maximum") is Some(@frontmatter.FInt(2147483647)))
    assert_true(fm.fields.get("weight") is Some(@frontmatter.FFloat(1.5)))
    guard fm.fields.get("values") is Some(@frontmatter.FArray(items)) else {
      abort("expected typed array")
    }
    assert_eq(items.length(), 2)
    assert_true(items[0] is @frontmatter.FInt(42))
    assert_true(items[1] is @frontmatter.FFloat(1.5))
  }
}

///|
test "positive numeric parsing preserves string fallbacks and comma errors" {
  for
    word in [
      "+", "+-42", "++42", "+ 42", "+42 notes", "+1.5 release", "+2147483648",
    ] {
    let fm = match @frontmatter.parse("---\nvalue: " + word + "\n---\n") {
      Ok(fm) => fm
      Err(message) => abort(message)
    }
    guard fm.fields.get("value") is Some(@frontmatter.FStr(value)) else {
      abort("expected string fallback")
    }
    assert_eq(value, word)
  }
  for source in ["---\nvalue: \"+42\"\n---\n", "+++\nvalue = \"+42\"\n+++\n"] {
    let fm = match @frontmatter.parse(source) {
      Ok(fm) => fm
      Err(message) => abort(message)
    }
    assert_true(fm.fields.get("value") is Some(@frontmatter.FStr("+42")))
  }
  match @frontmatter.parse("+++\nvalues = [+1 +2]\n+++\n") {
    Err(message) => assert_true(message.contains("expected ',' or ']'"))
    Ok(_) => abort("missing TOML commas must still fail")
  }
}

///|
test "signs and dots without digits remain strings in YAML and TOML" {
  for word in ["+.", "-.", ".", "+", "-", "++.", "+-.", "-+."] {
    for source in ["---\nvalue: " + word + "\n---\n", "+++\nvalue = " + word + "\n+++\n"] {
      let fm = match @frontmatter.parse(source) {
        Ok(fm) => fm
        Err(message) => abort(message)
      }
      guard fm.fields.get("value") is Some(@frontmatter.FStr(value)) else {
        abort("a float must contain a digit")
      }
      assert_eq(value, word)
    }
  }
}

///|
test "signed decimals retain existing optional integer and fraction digits" {
  // Preserve the existing decimal grammar, including its permissive TOML mode.
  for (word, expected) in [("+0.", 0.0), ("+.5", 0.5), ("-0.", 0.0), ("-.5", -0.5)] {
    for source in ["---\nvalue: " + word + "\n---\n", "+++\nvalue = " + word + "\n+++\n"] {
      let fm = match @frontmatter.parse(source) {
        Ok(fm) => fm
        Err(message) => abort(message)
      }
      guard fm.fields.get("value") is Some(@frontmatter.FFloat(value)) else {
        abort("expected supported decimal")
      }
      assert_eq(value, expected)
    }
  }
}
