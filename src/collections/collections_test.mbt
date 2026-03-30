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

///|
test "collections parse Enum type" {
  let src = "[posts]\n" +
    "schema = status:Enum[\"draft\",\"published\",\"archived\"]\n" +
    "dir = content/posts\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.definitions.length(), 1)
      assert_eq(cfg.definitions[0].name, "posts")
      assert_eq(cfg.definitions[0].schema.fields.length(), 1)
      let field = cfg.definitions[0].schema.fields[0]
      assert_eq(field.name, "status")
      match field.field_type {
        @schema.TEnum(allowed) => {
          assert_eq(allowed.length(), 3)
          assert_eq(allowed[0], "draft")
          assert_eq(allowed[1], "published")
          assert_eq(allowed[2], "archived")
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections parse optional Enum" {
  let src = "[posts]\n" +
    "schema = status:Optional[Enum[\"draft\",\"published\"]]\n" +
    "dir = content/posts\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.definitions.length(), 1)
      let field = cfg.definitions[0].schema.fields[0]
      assert_eq(field.name, "status")
      assert_false(field.required)
      match field.field_type {
        @schema.TOptional(inner) =>
          match inner {
            @schema.TEnum(allowed) => {
              assert_eq(allowed.length(), 2)
              assert_eq(allowed[0], "draft")
              assert_eq(allowed[1], "published")
            }
            _ => assert_true(false)
          }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections parse Enum with single value" {
  let src = "[posts]\n" +
    "schema = status:Enum[\"always\"]\n" +
    "dir = content/posts\n"
  match parse(src) {
    Ok(cfg) => {
      let field = cfg.definitions[0].schema.fields[0]
      match field.field_type {
        @schema.TEnum(allowed) => {
          assert_eq(allowed.length(), 1)
          assert_eq(allowed[0], "always")
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections parse Enum with empty values" {
  let src = "[posts]\n" + "schema = status:Enum[]\n" + "dir = content/posts\n"
  match parse(src) {
    Ok(cfg) => {
      let field = cfg.definitions[0].schema.fields[0]
      match field.field_type {
        @schema.TEnum(allowed) => assert_eq(allowed.length(), 0)
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections reject Enum without opening bracket" {
  let src = "[posts]\n" +
    "schema = status:Enum\"draft\",\"published\"\n" +
    "dir = content/posts\n"
  match parse(src) {
    Ok(_) => assert_true(false)
    Err(_) => assert_true(true)
  }
}

///|
test "collections reject Enum without closing bracket" {
  let src = "[posts]\n" +
    "schema = status:Enum[\"draft\",\"published\"\n" +
    "dir = content/posts\n"
  match parse(src) {
    Ok(_) => assert_true(false)
    Err(_) => assert_true(true)
  }
}

///|
test "collections reject Enum with unquoted value" {
  let src = "[posts]\n" +
    "schema = status:Enum[draft,published]\n" +
    "dir = content/posts\n"
  match parse(src) {
    Ok(_) => assert_true(false)
    Err(_) => assert_true(true)
  }
}

///|
test "collections parse SchemaString with Enum" {
  match parse_schema_string("test", "status:Enum[\"a\",\"b\"],title:String") {
    Ok(schema) => {
      assert_eq(schema.name, "test")
      assert_eq(schema.fields.length(), 2)
      match schema.fields[0].field_type {
        @schema.TEnum(allowed) => {
          assert_eq(allowed.length(), 2)
          assert_eq(allowed[0], "a")
          assert_eq(allowed[1], "b")
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections TEnum roundtrips through parser" {
  let src = "[posts]\n" +
    "schema = status:Enum[\"draft\",\"published\",\"archived\"]\n" +
    "dir = content/posts\n"
  match parse(src) {
    Ok(cfg) => {
      let field = cfg.definitions[0].schema.fields[0]
      match field.field_type {
        @schema.TEnum(allowed) => {
          // Parser correctly parsed the Enum values
          assert_eq(allowed.length(), 3)
          assert_eq(allowed[0], "draft")
          assert_eq(allowed[1], "published")
          assert_eq(allowed[2], "archived")
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections parse Date type unbounded" {
  let src = "[posts]\n" + "schema = date:Date\n" + "dir = content/posts\n"
  match parse(src) {
    Ok(cfg) => {
      let field = cfg.definitions[0].schema.fields[0]
      assert_eq(field.name, "date")
      match field.field_type {
        @schema.TDate(None, None) => assert_true(true)
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections parse Date(after=2020-01-01)" {
  let src = "[posts]\n" +
    "schema = date:Date(after=2020-01-01)\n" +
    "dir = content/posts\n"
  match parse(src) {
    Ok(cfg) => {
      let field = cfg.definitions[0].schema.fields[0]
      assert_eq(field.name, "date")
      match field.field_type {
        @schema.TDate(Some(after), None) => assert_eq(after, "2020-01-01")
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections parse Date(before=2030-01-01)" {
  let src = "[posts]\n" +
    "schema = date:Date(before=2030-01-01)\n" +
    "dir = content/posts\n"
  match parse(src) {
    Ok(cfg) => {
      let field = cfg.definitions[0].schema.fields[0]
      assert_eq(field.name, "date")
      match field.field_type {
        @schema.TDate(None, Some(before)) => assert_eq(before, "2030-01-01")
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections parse Date(after=2020-01-01,before=2030-01-01)" {
  let src = "[posts]\n" +
    "schema = date:Date(after=2020-01-01,before=2030-01-01)\n" +
    "dir = content/posts\n"
  match parse(src) {
    Ok(cfg) => {
      let field = cfg.definitions[0].schema.fields[0]
      assert_eq(field.name, "date")
      match field.field_type {
        @schema.TDate(Some(after), Some(before)) => {
          assert_eq(after, "2020-01-01")
          assert_eq(before, "2030-01-01")
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections parse Date bounds order-independent" {
  let src = "[posts]\n" +
    "schema = date:Date(before=2030-01-01,after=2020-01-01)\n" +
    "dir = content/posts\n"
  match parse(src) {
    Ok(cfg) => {
      let field = cfg.definitions[0].schema.fields[0]
      match field.field_type {
        @schema.TDate(Some(after), Some(before)) => {
          assert_eq(after, "2020-01-01")
          assert_eq(before, "2030-01-01")
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections reject Date with unknown bound key" {
  let src = "[posts]\n" +
    "schema = date:Date(since=2020-01-01)\n" +
    "dir = content/posts\n"
  match parse(src) {
    Ok(_) => assert_true(false)
    Err(_) => assert_true(true)
  }
}
