///|
test "truncate counts complete Unicode scalar values" {
  // Literal expectations also match Array.from(value).slice(0, limit) in JS.
  for (value, limit, expected) in [
    ("🌱x", "1", "🌱..."),
    ("🌱", "1", "🌱"),
    ("é🌱X", "2", "é🌱..."),
    ("🌱🌿", "2", "🌱🌿"),
    ("🌱x", "0", "..."),
    ("plain", "3", "pla..."),
    ("", "0", ""),
  ] {
    let tpl = match @template.parse_template("{{page.title | truncate " + limit + "}}") {
      Ok(tpl) => tpl
      Err(_) => abort("invalid truncate template")
    }
    let html = match @template.render_template(tpl, Map([]), Map([("title", value)])) {
      Ok(html) => html
      Err(_) => abort("truncate rendering failed")
    }
    assert_eq(html, expected)
  }
}
