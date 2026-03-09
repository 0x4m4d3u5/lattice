///|
test "collections parse data schemas" {
  let src =
    "[posts]\n" +
    "schema = title:String\n" +
    "dir = content/posts\n\n" +
    "[data.nav]\n" +
    "required = title,subtitle\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.data_schema_list.length(), 1)
      assert_eq(cfg.data_schema_list[0].name, "nav")
      assert_eq(cfg.data_schema_list[0].required_keys.length(), 2)
    }
    Err(_) => assert_true(false)
  }
}
