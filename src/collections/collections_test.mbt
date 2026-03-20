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

///|
test "collections parse sort date desc" {
  let src = "[posts]\n" +
    "schema = title:String\n" +
    "dir = content/posts\n" +
    "sort = date:desc\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.definitions.length(), 1)
      match cfg.definitions[0].sort_order {
        @collections.DateDesc => assert_true(true)
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections parse sort date asc" {
  let src = "[posts]\n" +
    "schema = title:String\n" +
    "dir = content/posts\n" +
    "sort = date:asc\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.definitions.length(), 1)
      match cfg.definitions[0].sort_order {
        @collections.DateAsc => assert_true(true)
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections parse sort title asc" {
  let src = "[posts]\n" +
    "schema = title:String\n" +
    "dir = content/posts\n" +
    "sort = title:asc\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.definitions.length(), 1)
      match cfg.definitions[0].sort_order {
        @collections.TitleAsc => assert_true(true)
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections parse sort title desc" {
  let src = "[posts]\n" +
    "schema = title:String\n" +
    "dir = content/posts\n" +
    "sort = title:desc\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.definitions.length(), 1)
      match cfg.definitions[0].sort_order {
        @collections.TitleDesc => assert_true(true)
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections default sort order when not specified" {
  let src = "[posts]\n" + "schema = title:String\n" + "dir = content/posts\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.definitions.length(), 1)
      match cfg.definitions[0].sort_order {
        @collections.DateDesc => assert_true(true)
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections parse invalid sort value" {
  let src = "[posts]\n" +
    "schema = title:String\n" +
    "dir = content/posts\n" +
    "sort = invalid:order\n"
  match parse(src) {
    Ok(_) => assert_true(false)
    Err(@collections.InvalidLine(line, _)) => assert_eq(line, 4)
    Err(_) => assert_true(false)
  }
}
