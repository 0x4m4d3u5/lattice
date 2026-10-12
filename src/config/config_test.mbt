///|
test "config parse root_page quoted string" {
  let src = "title = Example\n" +
    "base_url = https://example.test\n" +
    "root_page = \"home\"\n"
  match @config.parse(src) {
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
  match @config.parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.collections.length(), 1)
      let coll = cfg.collections[0]
      assert_eq(coll.name, "posts")
      assert_eq(coll.dir, "./content/posts")
      assert_true(coll.schema == Some("title:String,date:Date"))
      assert_true(coll.template == Some("post.html"))
      assert_true(coll.page_size == Some(7))
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
  match @config.parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.collections.length(), 3)
      assert_eq(cfg.collections[0].name, "posts")
      assert_eq(cfg.collections[0].dir, "./content/posts")
      assert_eq(cfg.collections[1].name, "pages")
      assert_eq(cfg.collections[1].dir, "./content/pages")
      assert_eq(cfg.collections[2].name, "docs")
      assert_eq(cfg.collections[2].dir, "./content/docs")
      assert_true(cfg.collections[2].schema == None)
      assert_true(cfg.collections[2].page_size == None)
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
  match @config.parse(src) {
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
  match @config.parse(src) {
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
  match @config.parse(src) {
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
  match @config.parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.collections.length(), 0)
      assert_true(cfg.collections_file == Some("./vault.collections.cfg"))
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
  match @config.parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.collections.length(), 2)
      assert_true(
        cfg.collections[0].description ==
        Some("Blog posts about interesting things."),
      )
      assert_true(cfg.collections[1].description == None)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "config parse standalone_dir" {
  let src = "title = Example\n" +
    "base_url = https://example.test\n" +
    "standalone_dir = content/standalone\n"
  match @config.parse(src) {
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
  match @config.parse(src) {
    Ok(cfg) => assert_true(cfg.standalone_dir == None)
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
  match @config.parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.collections.length(), 1)
      assert_true(cfg.collections[0].sort_order == Some("title:asc"))
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
  match @config.parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.collections.length(), 2)
      assert_true(cfg.collections[0].description == Some("My posts"))
      assert_true(cfg.collections[0].sort_order == Some("date:asc"))
      assert_true(cfg.collections[1].description == None)
      assert_true(cfg.collections[1].sort_order == None)
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
  match @config.parse(src) {
    Ok(cfg) => assert_true(cfg.collections[0].sort_order == None)
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
  match @config.parse(src) {
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
  match @config.parse(src) {
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
  match @config.parse(src) {
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
  match @config.parse(src) {
    Ok(cfg) => assert_eq(cfg.data_entries.length(), 0)
    Err(_) => assert_true(false)
  }
}

///|
test "config MissingRequiredField when title absent" {
  let src = "base_url = https://example.test\n"
  match @config.parse(src) {
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
  match @config.parse(src) {
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
  match @config.parse(src) {
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
  match @config.parse(src) {
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
  match @config.parse(src) {
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
  match @config.parse(src) {
    Ok(cfg) => assert_true(cfg.output_dir == Some("dist"))
    Err(_) => assert_true(false)
  }
}

///|
test "config parses description and og_image" {
  let src = "title = Example\n" +
    "base_url = https://example.test\n" +
    "description = A test site\n" +
    "og_image = https://example.test/card.png\n"
  match @config.parse(src) {
    Ok(cfg) => {
      assert_true(cfg.description == Some("A test site"))
      assert_true(cfg.og_image == Some("https://example.test/card.png"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "config parses templates_dir and static_dir" {
  let src = "title = Example\n" +
    "base_url = https://example.test\n" +
    "templates_dir = templates\n" +
    "static_dir = public\n"
  match @config.parse(src) {
    Ok(cfg) => {
      assert_true(cfg.templates_dir == Some("templates"))
      assert_true(cfg.static_dir == Some("public"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "config parses page_size and feed_limit" {
  let src = "title = Example\n" +
    "base_url = https://example.test\n" +
    "page_size = 10\n" +
    "feed_limit = 20\n"
  match @config.parse(src) {
    Ok(cfg) => {
      assert_true(cfg.page_size == Some(10))
      assert_true(cfg.feed_limit == Some(20))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "config parses robots_txt and archive_pages booleans" {
  let src = "title = Example\n" +
    "base_url = https://example.test\n" +
    "robots_txt = true\n" +
    "archive_pages = false\n"
  match @config.parse(src) {
    Ok(cfg) => {
      assert_true(cfg.robots_txt == Some(true))
      assert_true(cfg.archive_pages == Some(false))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "config parses site_feed_enabled boolean" {
  let src = "title = Example\n" +
    "base_url = https://example.test\n" +
    "site_feed_enabled = yes\n"
  match @config.parse(src) {
    Ok(cfg) => assert_true(cfg.site_feed_enabled == Some(true))
    Err(_) => assert_true(false)
  }
}

///|
test "config InvalidValue for bad robots_txt value" {
  let src = "title = Example\n" +
    "base_url = https://example.test\n" +
    "robots_txt = maybe\n"
  match @config.parse(src) {
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
  let src = "title = Example\n" +
    "base_url = https://example.test\n" +
    "feed_limit = abc\n"
  match @config.parse(src) {
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
  let src = "title = Example\n" +
    "base_url = https://example.test\n" +
    "unknown_key = some_value\n" +
    "another_unknown = 42\n"
  match @config.parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.title, "Example")
      assert_eq(cfg.base_url, "https://example.test")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "config comment lines are ignored" {
  let src = "# This is a comment\n" +
    "title = Example\n" +
    "# Another comment\n" +
    "base_url = https://example.test\n"
  match @config.parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.title, "Example")
      assert_eq(cfg.base_url, "https://example.test")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "config parses search_index_file and content_index_file" {
  let src = "title = Example\n" +
    "base_url = https://example.test\n" +
    "search_index_file = search.json\n" +
    "content_index_file = content.json\n"
  match @config.parse(src) {
    Ok(cfg) => {
      assert_true(cfg.search_index_file == Some("search.json"))
      assert_true(cfg.content_index_file == Some("content.json"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "config parses data_dir and tags_field" {
  let src = "title = Example\n" +
    "base_url = https://example.test\n" +
    "data_dir = _data\n" +
    "tags_field = categories\n"
  match @config.parse(src) {
    Ok(cfg) => {
      assert_true(cfg.data_dir == Some("_data"))
      assert_true(cfg.tags_field == Some("categories"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "config rejects overflowing positive integer settings" {
  for value in ["2147483648", "4294967297", "999999999999999999999999999999"] {
    for field in ["page_size", "feed_limit"] {
      match
        @config.parse(
          "title = Test\nbase_url = https://example.test\n" +
          field +
          " = " +
          value +
          "\n",
        ) {
        Err(InvalidValue(name, _)) => assert_eq(name, field)
        _ => assert_true(false)
      }
    }
    match
      @config.parse(
        "[[collections]]\nname = posts\ndir = content/posts\npage_size = " +
        value +
        "\n",
      ) {
      Err(InvalidValue(name, _)) => assert_eq(name, "collections.page_size")
      _ => assert_true(false)
    }
  }
}

///|
test "config preserves maximum positive integer settings" {
  match
    @config.parse(
      "title = Test\nbase_url = https://example.test\npage_size = 0002147483647\nfeed_limit = 2147483647\n[[collections]]\nname = posts\ndir = content/posts\npage_size = 2147483647\n",
    ) {
    Ok(config) => {
      assert_eq(config.page_size, Some(2147483647))
      assert_eq(config.feed_limit, Some(2147483647))
      assert_eq(config.collections[0].page_size, Some(2147483647))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "require_image_alt rejects invalid boolean policy values" {
  match @config.parse("title=Site\nbase_url=/\nrequire_image_alt=perhaps\n") {
    Err(@config.InvalidValue(key, _)) => assert_eq(key, "require_image_alt")
    _ => abort("invalid editorial policy value was accepted")
  }
}

///|
test "require_image_alt defaults off and uses existing boolean grammar" {
  let omitted = match @config.parse("title=Site\nbase_url=/\n") {
    Ok(site) => site
    _ => abort("invalid fixture")
  }
  assert_eq(omitted.require_image_alt, None)
  for (text, expected) in [
    ("true", true), ("yes", true), ("1", true), ("on", true),
    ("false", false), ("no", false), ("0", false), ("off", false),
  ] {
    match @config.parse("title=Site\nbase_url=/\nrequire_image_alt=" + text + "\n") {
      Ok(site) => assert_eq(site.require_image_alt, Some(expected))
      _ => abort("valid policy boolean rejected")
    }
  }
}
