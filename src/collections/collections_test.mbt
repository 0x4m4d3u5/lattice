///|
test "collections parse data schemas" {
  let src = "[posts]\n" +
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

///|
test "collections parse optional template override" {
  let src = "[posts]\n" +
    "schema = title:String\n" +
    "dir = content/posts\n" +
    "template = templates/post.html\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.definitions.length(), 1)
      match cfg.definitions[0].template {
        Some(path) => assert_eq(path, "templates/post.html")
        None => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}
