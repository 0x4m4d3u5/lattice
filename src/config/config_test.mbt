///|
test "config parse root_page quoted string" {
  let src = "title = Example\n" +
    "base_url = https://example.test\n" +
    "root_page = \"home\"\n"
  match parse(src) {
    Ok(cfg) =>
      match cfg.root_page {
        Some(value) => assert_eq(value, "home")
        None => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}
