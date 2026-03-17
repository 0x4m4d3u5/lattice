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

///|
test "config parse single [[collections]] block" {
  let src = "title = Example\n" +
    "base_url = https://example.test\n" +
    "[[collections]]\n" +
    "name = posts\n" +
    "dir = ./content/posts\n" +
    "schema = title:String,date:Date\n" +
    "template = post.html\n" +
    "page_size = 7\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.collections.length(), 1)
      let coll = cfg.collections[0]
      assert_eq(coll.name, "posts")
      assert_eq(coll.dir, "./content/posts")
      assert_eq(coll.schema, Some("title:String,date:Date"))
      assert_eq(coll.template, Some("post.html"))
      assert_eq(coll.page_size, Some(7))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "config parse multiple [[collections]] blocks" {
  let src = "title = Example\n" +
    "base_url = https://example.test\n" +
    "[[collections]]\n" +
    "name = posts\n" +
    "dir = ./content/posts\n" +
    "schema = title:String\n" +
    "[[collections]]\n" +
    "name = pages\n" +
    "dir = ./content/pages\n" +
    "schema = title:String,slug:String\n" +
    "[[collections]]\n" +
    "name = docs\n" +
    "dir = ./content/docs\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.collections.length(), 3)
      assert_eq(cfg.collections[0].name, "posts")
      assert_eq(cfg.collections[0].dir, "./content/posts")
      assert_eq(cfg.collections[1].name, "pages")
      assert_eq(cfg.collections[1].dir, "./content/pages")
      assert_eq(cfg.collections[2].name, "docs")
      assert_eq(cfg.collections[2].dir, "./content/docs")
      assert_eq(cfg.collections[2].schema, None)
      assert_eq(cfg.collections[2].page_size, None)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "config parse [[collections]] invalid page_size" {
  let src = "title = Example\n" +
    "base_url = https://example.test\n" +
    "[[collections]]\n" +
    "name = posts\n" +
    "dir = ./content/posts\n" +
    "page_size = 0\n"
  match parse(src) {
    Ok(_) => assert_true(false)
    Err(err) =>
      match err {
        InvalidValue("collections.page_size", _) => ()
        _ => assert_true(false)
      }
  }
}

///|
test "config parse [[collections]] missing name field" {
  let src = "title = Example\n" +
    "base_url = https://example.test\n" +
    "[[collections]]\n" +
    "dir = ./content/posts\n"
  match parse(src) {
    Ok(_) => assert_true(false)
    Err(err) =>
      match err {
        MissingCollectionField(_, field) => assert_eq(field, "name")
        _ => assert_true(false)
      }
  }
}

///|
test "config parse [[collections]] missing dir field" {
  let src = "title = Example\n" +
    "base_url = https://example.test\n" +
    "[[collections]]\n" +
    "name = posts\n"
  match parse(src) {
    Ok(_) => assert_true(false)
    Err(err) =>
      match err {
        MissingCollectionField("posts", field) => assert_eq(field, "dir")
        _ => assert_true(false)
      }
  }
}

///|
test "config parse backward compatibility with collections_file" {
  let src = "title = Example\n" +
    "base_url = https://example.test\n" +
    "collections_file = ./vault.collections.cfg\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.collections.length(), 0)
      assert_eq(cfg.collections_file, Some("./vault.collections.cfg"))
    }
    Err(_) => assert_true(false)
  }
}
