///|
test "authored revision dates are optional calendar days and never inferred" {
  for
    (fields, errors) in [
      ("", 0),
      ("updated: 2026-02-03\n", 0),
      ("date: 2026-02-03\nupdated: 2026-02-03\n", 0),
      ("date: 2026-02-03\nupdated: 2026-02-02\n", 1),
      ("updated: 2026-02-30\n", 1),
      ("updated: 42\n", 1),
      ("updated: true\n", 1),
      ("updated: 2026-02-03T12:00:00Z\n", 1),
      ("date: yesterday\nupdated: 2026-02-03\n", 1),
    ] {
    let fm = @frontmatter.parse("---\ntitle: Note\n" + fields + "---\nBody").unwrap()
    assert_eq(updated_date_errors(fm).length(), errors)
  }
  assert_eq(reader_metadata_html(None, None, [], 0), "")
  let same = reader_metadata_html(Some("2026-02-03"), Some("2026-02-03"), [], 0)
  assert_true(same.contains("Published"))
  assert_false(same.contains("Updated"))
}

///|
test "backlink shortcut resolves a unique emitted target or disappears" {
  let marker = "<section class=\"backlinks\" data-lattice-backlinks>List</section>"
  let header = reader_metadata_html(None, None, [], 2)
  let html = bind_backlink_shortcut(
    header + "<div id=\"lattice-backlinks\"></div>" + marker,
    2,
  )
  assert_true(html.contains("href=\"#lattice-backlinks-2\">Backlinks (2)"))
  assert_true(html.contains("id=\"lattice-backlinks-2\""))
  assert_eq(bind_backlink_shortcut(header, 2), "")
  assert_false(
    bind_backlink_shortcut(header + marker + marker, 2).contains("href=\"#"),
  )
}

///|
test "backlink destinations must be active HTML elements" {
  let marker = "<section class=\"backlinks\" data-lattice-backlinks>List</section>"
  let header = reader_metadata_html(None, None, [], 2)
  for
    inactive in [
      "<!-- " + marker + " -->",
      "<template>" + marker + "</template>",
      "<script>const html = '" + marker + "';</script>",
    ] {
    assert_false(
      bind_backlink_shortcut(header + inactive, 2).contains("href=\"#"),
    )
    let with_active = bind_backlink_shortcut(header + inactive + marker, 2)
    assert_true(with_active.contains("href=\"#lattice-backlinks\""))
    assert_true(
      with_active.contains("id=\"lattice-backlinks\" tabindex=\"-1\""),
    )
  }
}
