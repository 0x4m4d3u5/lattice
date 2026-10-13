///|
test "table cells retain escaped pipes in text code and emphasis" {
  // Literal output follows the GFM table example, independent of the parser.
  let body = "| f\\|oo |\n| --- |\n| b `\\|` az |\n| b **\\|** im |"
  assert_eq(
    @markdown.render(body, Map([])),
    "<table>\n<thead>\n<tr>\n<th>f|oo</th>\n</tr>\n</thead>\n<tbody>\n" +
    "<tr>\n<td>b <code>|</code> az</td>\n</tr>\n" +
    "<tr>\n<td>b <strong>|</strong> im</td>\n</tr>\n</tbody>\n</table>\n",
  )
}

///|
test "escaped final pipes remain cell content without outer pipes" {
  assert_eq(
    @markdown.render("Name | Value\n--- | ---\nA | final\\|", Map([])),
    "<table>\n<thead>\n<tr>\n<th>Name</th>\n<th>Value</th>\n</tr>\n</thead>\n<tbody>\n" +
    "<tr>\n<td>A</td>\n<td>final|</td>\n</tr>\n</tbody>\n</table>\n",
  )
}

///|
test "escaped wikilink alias pipes survive table splitting" {
  let body = "| Note | Detail |\n| --- | --- |\n| [[beta\\|Beta page]] | Kept detail |"
  let wl : Map[String, String] = Map([("beta", "/posts/beta/")])
  assert_eq(
    @markdown.render(body, wl),
    "<table>\n<thead>\n<tr>\n<th>Note</th>\n<th>Detail</th>\n</tr>\n</thead>\n<tbody>\n" +
    "<tr>\n<td><a href=\"/posts/beta/\">Beta page</a></td>\n<td>Kept detail</td>\n</tr>\n" +
    "</tbody>\n</table>\n",
  )
  assert_eq(@markdown.extract_wikilink_targets(body), [
    ("beta", Some("Beta page")),
  ])
}

///|
test "table splitting preserves other escapes and ordinary code spans" {
  let html = @markdown.render(
    "| Left | Right |\n| --- | --- |\n| \\*literal\\* | **bold** |",
    Map([]),
  )
  assert_true(
    html.contains("<td>*literal*</td>\n<td><strong>bold</strong></td>"),
  )
  // A table-specific pipe escape must not alter ordinary code spans.
  assert_eq(@markdown.render("`a\\|b`", Map([])), "<p><code>a\\|b</code></p>\n")
}

///|
test "table backslash runs match cmark-gfm text code and final-pipe cells" {
  // Literal expectations from cmark-gfm 0.29.0.gfm.13 with -e table.
  // One through four backslashes: every pipe stays inside its original cell.
  let cases : Array[(String, String)] = [
    ("a\\|b | kept", "<td>a|b</td>\n<td>kept</td>"),
    ("`a\\|b` | kept", "<td><code>a|b</code></td>\n<td>kept</td>"),
    ("kept | a\\|", "<td>kept</td>\n<td>a|</td>"),
    ("a\\\\|b | kept", "<td>a|b</td>\n<td>kept</td>"),
    ("`a\\\\|b` | kept", "<td><code>a\\|b</code></td>\n<td>kept</td>"),
    ("kept | a\\\\|", "<td>kept</td>\n<td>a|</td>"),
    ("a\\\\\\|b | kept", "<td>a\\|b</td>\n<td>kept</td>"),
    ("`a\\\\\\|b` | kept", "<td><code>a\\\\|b</code></td>\n<td>kept</td>"),
    ("kept | a\\\\\\|", "<td>kept</td>\n<td>a\\|</td>"),
    ("a\\\\\\\\|b | kept", "<td>a\\|b</td>\n<td>kept</td>"),
    ("`a\\\\\\\\|b` | kept", "<td><code>a\\\\\\|b</code></td>\n<td>kept</td>"),
    ("kept | a\\\\\\\\|", "<td>kept</td>\n<td>a\\|</td>"),
  ]
  for pair in cases {
    let (row, cells) = pair
    assert_eq(
      @markdown.render("| Left | Right |\n| --- | --- |\n" + row, Map([])),
      "<table>\n<thead>\n<tr>\n<th>Left</th>\n<th>Right</th>\n</tr>\n</thead>\n" +
      "<tbody>\n<tr>\n" +
      cells +
      "\n</tr>\n</tbody>\n</table>\n",
    )
  }
}
