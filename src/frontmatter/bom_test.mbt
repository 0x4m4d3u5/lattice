///|
test "leading BOM is ignored by automatic and explicit frontmatter parsers" {
  // Document normalization independently checked with Python utf-8-sig.
  for
    (delimiter, header) in [
      ("---", "title: Garden\ndate: 2026-01-02"),
      ("+++", "title = \"Garden\"\ndate = 2026-01-02"),
    ] {
    for ending in ["\n", "\r\n"] {
      let body = "Body \ufeff literal." + ending
      let source = "\ufeff" +
        delimiter +
        ending +
        header.replace_all(old="\n", new=ending) +
        ending +
        delimiter +
        ending +
        body
      let explicit = if delimiter == "---" {
        @frontmatter.parse_yaml(source)
      } else {
        @frontmatter.parse_toml(source)
      }
      for result in [@frontmatter.parse(source), explicit] {
        let fm = match result {
          Ok(fm) => fm
          Err(message) => abort(message)
        }
        assert_true(fm.fields.get("title") is Some(@frontmatter.FStr("Garden")))
        assert_true(
          fm.fields.get("date") is Some(@frontmatter.FDate("2026-01-02")),
        )
        assert_eq(fm.body, body)
      }
    }
  }
  match @frontmatter.parse("\n\ufeff---\ntitle: Garden\n---\n") {
    Err(_) => ()
    Ok(_) => abort("only a marker at the start of the document is ignored")
  }
}
