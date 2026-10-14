///|
test "quoted filter arguments preserve escaped quotes and structural pipes" {
  // Expectations use independently JSON-decoded literals followed by uppercase.
  let cases : Array[(String, String)] = [
    ("{{page.optional | default \"Read \\\"A|B\\\"\" | upper}}", "READ \"A|B\""),
    ("{{page.optional | default \"a\\\\\\\"|b\" | upper}}", "A\\\"|B"),
    ("{{page.optional | default \"C:\\\\\" | upper}}", "C:\\"),
    ("{{page.optional | default \"left|right\" | upper}}", "LEFT|RIGHT"),
  ]
  for pair in cases {
    let (source, expected) = pair
    let tpl = match @template.parse_template(source) {
      Ok(tpl) => tpl
      Err(_) => abort("valid escaped fallback failed to parse")
    }
    let html = match @template.render_template(tpl, Map([]), Map([])) {
      Ok(html) => html
      Err(_) => abort("render failed")
    }
    assert_eq(html, expected)
  }
}
