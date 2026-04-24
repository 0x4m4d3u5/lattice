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

///|
test "config parse [[collections]] with description" {
  let src = "title = Example\n" +
    "base_url = https://example.test\n" +
    "[[collections]]\n" +
    "name = posts\n" +
    "dir = ./content/posts\n" +
    "schema = title:String\n" +
    "description = \"Blog posts about interesting things.\"\n" +
    "[[collections]]\n" +
    "name = pages\n" +
    "dir = ./content/pages\n" +
    "schema = title:String\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.collections.length(), 2)
      assert_eq(
        cfg.collections[0].description,
        Some("Blog posts about interesting things."),
      )
      assert_eq(cfg.collections[1].description, None)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "config parse standalone_dir" {
  let src = "title = Example\n" +
    "base_url = https://example.test\n" +
    "standalone_dir = content/standalone\n"
  match parse(src) {
    Ok(cfg) =>
      match cfg.standalone_dir {
        Some(value) => assert_eq(value, "content/standalone")
        None => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "config standalone_dir defaults to None when omitted" {
  let src = "title = Example\n" + "base_url = https://example.test\n"
  match parse(src) {
    Ok(cfg) => assert_eq(cfg.standalone_dir, None)
    Err(_) => assert_true(false)
  }
}

///|
test "config parse [[collections]] with sort_order" {
  let src = "title = Example\n" +
    "base_url = https://example.test\n" +
    "[[collections]]\n" +
    "name = posts\n" +
    "dir = ./content/posts\n" +
    "schema = title:String\n" +
    "sort = title:asc\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.collections.length(), 1)
      assert_eq(cfg.collections[0].sort_order, Some("title:asc"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "config parse [[collections]] with description and sort_order" {
  let src = "title = Example\n" +
    "base_url = https://example.test\n" +
    "[[collections]]\n" +
    "name = posts\n" +
    "dir = ./content/posts\n" +
    "schema = title:String\n" +
    "description = \"My posts\"\n" +
    "sort = date:asc\n" +
    "[[collections]]\n" +
    "name = pages\n" +
    "dir = ./content/pages\n" +
    "schema = title:String\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.collections.length(), 2)
      assert_eq(cfg.collections[0].description, Some("My posts"))
      assert_eq(cfg.collections[0].sort_order, Some("date:asc"))
      assert_eq(cfg.collections[1].description, None)
      assert_eq(cfg.collections[1].sort_order, None)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "config sort_order defaults to None when not specified" {
  let src = "title = Example\n" +
    "base_url = https://example.test\n" +
    "[[collections]]\n" +
    "name = posts\n" +
    "dir = ./content/posts\n" +
    "schema = title:String\n"
  match parse(src) {
    Ok(cfg) => assert_eq(cfg.collections[0].sort_order, None)
    Err(_) => assert_true(false)
  }
}

///|
test "config [[data]] block parsed into data_entries" {
  let src = "title = Example\n" +
    "base_url = https://example.test\n" +
    "[[data]]\n" +
    "name = nav\n" +
    "required = title,links\n" +
    "[[data]]\n" +
    "name = authors\n" +
    "required = team_lead\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.data_entries.length(), 2)
      assert_eq(cfg.data_entries[0].name, "nav")
      assert_eq(cfg.data_entries[0].required, "title,links")
      assert_eq(cfg.data_entries[1].name, "authors")
      assert_eq(cfg.data_entries[1].required, "team_lead")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "config [[data]] with empty required is valid" {
  let src = "title = Example\n" +
    "base_url = https://example.test\n" +
    "[[data]]\n" +
    "name = settings\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.data_entries.length(), 1)
      assert_eq(cfg.data_entries[0].name, "settings")
      assert_eq(cfg.data_entries[0].required, "")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "config [[data]] and [[collections]] can coexist" {
  let src = "title = Example\n" +
    "base_url = https://example.test\n" +
    "[[collections]]\n" +
    "name = posts\n" +
    "dir = ./content/posts\n" +
    "[[data]]\n" +
    "name = nav\n" +
    "required = links\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.collections.length(), 1)
      assert_eq(cfg.collections[0].name, "posts")
      assert_eq(cfg.data_entries.length(), 1)
      assert_eq(cfg.data_entries[0].name, "nav")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "config data_entries is empty when no [[data]] blocks present" {
  let src = "title = Example\n" + "base_url = https://example.test\n"
  match parse(src) {
    Ok(cfg) => assert_eq(cfg.data_entries.length(), 0)
    Err(_) => assert_true(false)
  }
}

///|
test "config MissingRequiredField when title absent" {
  let src = "base_url = https://example.test\n"
  match parse(src) {
    Ok(_) => assert_true(false)
    Err(err) =>
      match err {
        MissingRequiredField(field) => assert_eq(field, "title")
        _ => assert_true(false)
      }
  }
}

///|
test "config MissingRequiredField when base_url absent" {
  let src = "title = Example\n"
  match parse(src) {
    Ok(_) => assert_true(false)
    Err(err) =>
      match err {
        MissingRequiredField(field) => assert_eq(field, "base_url")
        _ => assert_true(false)
      }
  }
}

///|
test "config InvalidValue for empty title" {
  let src = "title = \nbase_url = https://example.test\n"
  match parse(src) {
    Ok(_) => assert_true(false)
    Err(err) =>
      match err {
        InvalidValue(field, _) => assert_eq(field, "title")
        _ => assert_true(false)
      }
  }
}

///|
test "config InvalidValue for empty base_url" {
  let src = "title = Example\nbase_url = \n"
  match parse(src) {
    Ok(_) => assert_true(false)
    Err(err) =>
      match err {
        InvalidValue(field, _) => assert_eq(field, "base_url")
        _ => assert_true(false)
      }
  }
}

///|
test "config InvalidLine for line without equals sign" {
  let src = "title = Example\nbase_url = https://example.test\nnoequals\n"
  match parse(src) {
    Ok(_) => assert_true(false)
    Err(err) =>
      match err {
        InvalidLine(line_no, _) => assert_eq(line_no, 3)
        _ => assert_true(false)
      }
  }
}

///|
test "config parses output_dir" {
  let src = "title = Example\nbase_url = https://example.test\noutput_dir = dist\n"
  match parse(src) {
    Ok(cfg) => assert_eq(cfg.output_dir, Some("dist"))
    Err(_) => assert_true(false)
  }
}

///|
test "config parses description and og_image" {
  let src =
    "title = Example\n" +
    "base_url = https://example.test\n" +
    "description = A test site\n" +
    "og_image = https://example.test/card.png\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.description, Some("A test site"))
      assert_eq(cfg.og_image, Some("https://example.test/card.png"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "config parses templates_dir and static_dir" {
  let src =
    "title = Example\n" +
    "base_url = https://example.test\n" +
    "templates_dir = templates\n" +
    "static_dir = public\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.templates_dir, Some("templates"))
      assert_eq(cfg.static_dir, Some("public"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "config parses page_size and feed_limit" {
  let src =
    "title = Example\n" +
    "base_url = https://example.test\n" +
    "page_size = 10\n" +
    "feed_limit = 20\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.page_size, Some(10))
      assert_eq(cfg.feed_limit, Some(20))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "config parses robots_txt and archive_pages booleans" {
  let src =
    "title = Example\n" +
    "base_url = https://example.test\n" +
    "robots_txt = true\n" +
    "archive_pages = false\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.robots_txt, Some(true))
      assert_eq(cfg.archive_pages, Some(false))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "config parses site_feed_enabled boolean" {
  let src =
    "title = Example\n" +
    "base_url = https://example.test\n" +
    "site_feed_enabled = yes\n"
  match parse(src) {
    Ok(cfg) => assert_eq(cfg.site_feed_enabled, Some(true))
    Err(_) => assert_true(false)
  }
}

///|
test "config InvalidValue for bad robots_txt value" {
  let src =
    "title = Example\n" +
    "base_url = https://example.test\n" +
    "robots_txt = maybe\n"
  match parse(src) {
    Ok(_) => assert_true(false)
    Err(err) =>
      match err {
        InvalidValue(field, _) => assert_eq(field, "robots_txt")
        _ => assert_true(false)
      }
  }
}

///|
test "config InvalidValue for bad feed_limit value" {
  let src =
    "title = Example\n" +
    "base_url = https://example.test\n" +
    "feed_limit = abc\n"
  match parse(src) {
    Ok(_) => assert_true(false)
    Err(err) =>
      match err {
        InvalidValue(field, _) => assert_eq(field, "feed_limit")
        _ => assert_true(false)
      }
  }
}

///|
test "config unknown top-level keys are ignored" {
  let src =
    "title = Example\n" +
    "base_url = https://example.test\n" +
    "unknown_key = some_value\n" +
    "another_unknown = 42\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.title, "Example")
      assert_eq(cfg.base_url, "https://example.test")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "config comment lines are ignored" {
  let src =
    "# This is a comment\n" +
    "title = Example\n" +
    "# Another comment\n" +
    "base_url = https://example.test\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.title, "Example")
      assert_eq(cfg.base_url, "https://example.test")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "config parses search_index_file and content_index_file" {
  let src =
    "title = Example\n" +
    "base_url = https://example.test\n" +
    "search_index_file = search.json\n" +
    "content_index_file = content.json\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.search_index_file, Some("search.json"))
      assert_eq(cfg.content_index_file, Some("content.json"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "config parses data_dir and tags_field" {
  let src =
    "title = Example\n" +
    "base_url = https://example.test\n" +
    "data_dir = _data\n" +
    "tags_field = categories\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.data_dir, Some("_data"))
      assert_eq(cfg.tags_field, Some("categories"))
    }
    Err(_) => assert_true(false)
  }
}
