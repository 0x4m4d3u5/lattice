///|
test "optional frontmatter uses explicit typed boolean configuration" {
  assert_eq(
    @config.parse("title=Site\nbase_url=/\n").unwrap().allow_missing_frontmatter,
    None,
  )
  for
    (text, expected) in [
      ("true", true),
      ("yes", true),
      ("1", true),
      ("on", true),
      ("false", false),
      ("no", false),
      ("0", false),
      ("off", false),
    ] {
    assert_eq(
      @config.parse(
        "title=Site\nbase_url=/\nallow_missing_frontmatter=" + text + "\n",
      ).unwrap().allow_missing_frontmatter,
      Some(expected),
    )
  }
  assert_true(
    @config.parse("title=Site\nbase_url=/\nallow_missing_frontmatter=maybe\n")
    is Err(@config.InvalidValue("allow_missing_frontmatter", _)),
  )
}
