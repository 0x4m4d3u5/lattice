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

///|
test "collections parse Float type unbounded" {
  let src = "[posts]\n" + "schema = rating:Float\n" + "dir = content/posts\n"
  match parse(src) {
    Ok(cfg) => {
      let field = cfg.definitions[0].schema.fields[0]
      assert_eq(field.name, "rating")
      match field.field_type {
        @schema.TFloat(None, None) => assert_true(true)
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections parse Float(min=0.0,max=5.0)" {
  let src = "[posts]\n" +
    "schema = rating:Float(min=0.0,max=5.0)\n" +
    "dir = content/posts\n"
  match parse(src) {
    Ok(cfg) => {
      let field = cfg.definitions[0].schema.fields[0]
      assert_eq(field.name, "rating")
      match field.field_type {
        @schema.TFloat(Some(min), Some(max)) => {
          assert_true((min - 0.0).abs() < 0.0001)
          assert_true((max - 5.0).abs() < 0.0001)
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections parse Float(min=-1.5)" {
  let src = "[posts]\n" +
    "schema = temp:Float(min=-1.5)\n" +
    "dir = content/posts\n"
  match parse(src) {
    Ok(cfg) => {
      let field = cfg.definitions[0].schema.fields[0]
      assert_eq(field.name, "temp")
      match field.field_type {
        @schema.TFloat(Some(min), None) =>
          assert_true((min - -1.5).abs() < 0.0001)
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections parse Float(max=10.0)" {
  let src = "[posts]\n" +
    "schema = score:Float(max=10.0)\n" +
    "dir = content/posts\n"
  match parse(src) {
    Ok(cfg) => {
      let field = cfg.definitions[0].schema.fields[0]
      assert_eq(field.name, "score")
      match field.field_type {
        @schema.TFloat(None, Some(max)) =>
          assert_true((max - 10.0).abs() < 0.0001)
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections parse Float bounds order-independent" {
  let src = "[posts]\n" +
    "schema = rating:Float(max=5.0,min=0.0)\n" +
    "dir = content/posts\n"
  match parse(src) {
    Ok(cfg) => {
      let field = cfg.definitions[0].schema.fields[0]
      match field.field_type {
        @schema.TFloat(Some(min), Some(max)) => {
          assert_true((min - 0.0).abs() < 0.0001)
          assert_true((max - 5.0).abs() < 0.0001)
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections parse sort weight" {
  let src = "[posts]\n" +
    "schema = title:String\n" +
    "dir = content/posts\n" +
    "sort = weight\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.definitions.length(), 1)
      match cfg.definitions[0].sort_order {
        @collections.Weight => assert_true(true)
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections parse description field" {
  let src = "[posts]\n" +
    "schema = title:String\n" +
    "dir = content/posts\n" +
    "description = \"My blog posts\"\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.definitions.length(), 1)
      assert_eq(cfg.definitions[0].description, Some("My blog posts"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections description defaults to None when not specified" {
  let src = "[posts]\n" + "schema = title:String\n" + "dir = content/posts\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.definitions.length(), 1)
      assert_eq(cfg.definitions[0].description, None)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections parse description and sort together" {
  let src = "[posts]\n" +
    "schema = title:String\n" +
    "dir = content/posts\n" +
    "description = All my posts\n" +
    "sort = title:asc\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.definitions.length(), 1)
      assert_eq(cfg.definitions[0].description, Some("All my posts"))
      match cfg.definitions[0].sort_order {
        @collections.TitleAsc => assert_true(true)
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections parse description across multiple sections" {
  let src = "[posts]\n" +
    "schema = title:String\n" +
    "dir = content/posts\n" +
    "description = Blog\n\n" +
    "[pages]\n" +
    "schema = title:String\n" +
    "dir = content/pages\n" +
    "description = Static pages\n"
  match parse(src) {
    Ok(cfg) => {
      assert_eq(cfg.definitions.length(), 2)
      assert_eq(cfg.definitions[0].description, Some("Blog"))
      assert_eq(cfg.definitions[1].description, Some("Static pages"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections parse_sort_order pub function" {
  assert_true(parse_sort_order("date:desc") is Some(DateDesc))
  assert_true(parse_sort_order("date:asc") is Some(DateAsc))
  assert_true(parse_sort_order("title:asc") is Some(TitleAsc))
  assert_true(parse_sort_order("title:desc") is Some(TitleDesc))
  assert_true(parse_sort_order("weight") is Some(Weight))
  assert_true(parse_sort_order("nonsense") is None)
}
// ── TDateTime collection parser tests ────────────────────────────────────────

///|
test "collections parse DateTime type unbounded" {
  let src = "[events]\n" +
    "schema = starts_at:DateTime\n" +
    "dir = content/events\n"
  match parse(src) {
    Ok(cfg) => {
      let field = cfg.definitions[0].schema.fields[0]
      assert_eq(field.name, "starts_at")
      match field.field_type {
        @schema.TDateTime(None, None) => assert_true(true)
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections parse DateTime(after=2026-01-01T00:00:00Z)" {
  let src = "[events]\n" +
    "schema = starts_at:DateTime(after=2026-01-01T00:00:00Z)\n" +
    "dir = content/events\n"
  match parse(src) {
    Ok(cfg) => {
      let field = cfg.definitions[0].schema.fields[0]
      assert_eq(field.name, "starts_at")
      match field.field_type {
        @schema.TDateTime(Some(after), None) =>
          assert_eq(after, "2026-01-01T00:00:00Z")
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections parse DateTime(before=2027-01-01T00:00:00Z)" {
  let src = "[events]\n" +
    "schema = starts_at:DateTime(before=2027-01-01T00:00:00Z)\n" +
    "dir = content/events\n"
  match parse(src) {
    Ok(cfg) => {
      let field = cfg.definitions[0].schema.fields[0]
      assert_eq(field.name, "starts_at")
      match field.field_type {
        @schema.TDateTime(None, Some(before)) =>
          assert_eq(before, "2027-01-01T00:00:00Z")
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections parse DateTime(after=...,before=...)" {
  let src = "[events]\n" +
    "schema = starts_at:DateTime(after=2026-01-01T00:00:00Z,before=2027-01-01T00:00:00Z)\n" +
    "dir = content/events\n"
  match parse(src) {
    Ok(cfg) => {
      let field = cfg.definitions[0].schema.fields[0]
      match field.field_type {
        @schema.TDateTime(Some(after), Some(before)) => {
          assert_eq(after, "2026-01-01T00:00:00Z")
          assert_eq(before, "2027-01-01T00:00:00Z")
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections parse DateTime bounds order-independent" {
  let src = "[events]\n" +
    "schema = starts_at:DateTime(before=2027-01-01T00:00:00Z,after=2026-01-01T00:00:00Z)\n" +
    "dir = content/events\n"
  match parse(src) {
    Ok(cfg) => {
      let field = cfg.definitions[0].schema.fields[0]
      match field.field_type {
        @schema.TDateTime(Some(after), Some(before)) => {
          assert_eq(after, "2026-01-01T00:00:00Z")
          assert_eq(before, "2027-01-01T00:00:00Z")
        }
        _ => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "collections reject DateTime with unknown bound key" {
  let src = "[events]\n" +
    "schema = starts_at:DateTime(since=2026-01-01T00:00:00Z)\n" +
    "dir = content/events\n"
  match parse(src) {
    Ok(_) => assert_true(false)
    Err(_) => assert_true(true)
  }
}

// ── Error path tests ────────────────────────────────────────────────────────

///|
test "collections error: empty input returns EmptyConfig" {
  match parse("") {
    Err(@collections.EmptyConfig) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "collections error: comment-only input returns EmptyConfig" {
  match parse("# just a comment") {
    Err(@collections.EmptyConfig) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "collections error: whitespace-only input returns EmptyConfig" {
  match parse("   \n\n   ") {
    Err(@collections.EmptyConfig) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "collections error: assignment outside section" {
  let src = "schema = title:String\n"
  match parse(src) {
    Err(@collections.InvalidLine(line, msg)) => {
      assert_eq(line, 1)
      assert_eq(msg, "assignment outside section")
    }
    _ => assert_true(false)
  }
}

///|
test "collections error: key=value line before any section" {
  let src = "dir = content/posts\n[posts]\nschema = title:String\ndir = content/posts\n"
  match parse(src) {
    Err(@collections.InvalidLine(line, msg)) => {
      assert_eq(line, 1)
      assert_eq(msg, "assignment outside section")
    }
    _ => assert_true(false)
  }
}

///|
test "collections error: line without equals sign" {
  let src = "[posts]\nbadline\n"
  match parse(src) {
    Err(@collections.InvalidLine(line, msg)) => {
      assert_eq(line, 2)
      assert_eq(msg, "expected key=value")
    }
    _ => assert_true(false)
  }
}

///|
test "collections error: equals at start of line" {
  let src = "[posts]\n=value\n"
  match parse(src) {
    Err(@collections.InvalidLine(line, msg)) => {
      assert_eq(line, 2)
      assert_eq(msg, "expected key=value")
    }
    _ => assert_true(false)
  }
}

///|
test "collections error: equals at end of line" {
  let src = "[posts]\nschema=\n"
  match parse(src) {
    Err(@collections.InvalidLine(line, msg)) => {
      assert_eq(line, 2)
      assert_eq(msg, "expected key=value")
    }
    _ => assert_true(false)
  }
}

///|
test "collections error: page_size non-numeric" {
  let src = "[posts]\nschema = title:String\ndir = content/posts\npage_size = abc\n"
  match parse(src) {
    Err(@collections.InvalidLine(line, msg)) => {
      assert_eq(line, 4)
      assert_eq(msg, "page_size must be a positive integer")
    }
    _ => assert_true(false)
  }
}

///|
test "collections error: page_size negative" {
  let src = "[posts]\nschema = title:String\ndir = content/posts\npage_size = -5\n"
  match parse(src) {
    Err(@collections.InvalidLine(line, msg)) => {
      assert_eq(line, 4)
      assert_eq(msg, "page_size must be a positive integer")
    }
    _ => assert_true(false)
  }
}

///|
test "collections error: page_size zero" {
  let src = "[posts]\nschema = title:String\ndir = content/posts\npage_size = 0\n"
  match parse(src) {
    Err(@collections.InvalidLine(line, msg)) => {
      assert_eq(line, 4)
      assert_eq(msg, "page_size must be a positive integer")
    }
    _ => assert_true(false)
  }
}

///|
test "collections error: unknown key in collection section" {
  let src = "[posts]\nfoo = bar\n"
  match parse(src) {
    Err(@collections.InvalidLine(line, msg)) => {
      assert_eq(line, 2)
      assert_eq(msg, "unknown key in section 'posts': foo")
    }
    _ => assert_true(false)
  }
}

///|
test "collections error: unknown key in data section" {
  let src = "[data.nav]\nfoo = bar\n"
  match parse(src) {
    Err(@collections.InvalidLine(line, msg)) => {
      assert_eq(line, 2)
      assert_eq(msg, "unknown key in section 'data.nav': foo")
    }
    _ => assert_true(false)
  }
}

///|
test "collections error: duplicate collection name" {
  let src =
    "[posts]\nschema = title:String\ndir = content/posts\n\n" +
    "[posts]\nschema = title:String\ndir = content/posts2\n"
  match parse(src) {
    Err(@collections.DuplicateCollection(name)) => assert_eq(name, "posts")
    _ => assert_true(false)
  }
}

///|
test "collections error: duplicate data schema name" {
  let src =
    "[posts]\nschema = title:String\ndir = content/posts\n\n" +
    "[data.nav]\nrequired = title\n\n" +
    "[data.nav]\nrequired = subtitle\n"
  match parse(src) {
    Err(@collections.DuplicateDataSchema(name)) => assert_eq(name, "nav")
    _ => assert_true(false)
  }
}

///|
test "collections error: missing required field in data section" {
  let src =
    "[posts]\nschema = title:String\ndir = content/posts\n\n" +
    "[data.nav]\n"
  match parse(src) {
    Err(@collections.MissingRequiredField(section, field)) => {
      assert_eq(section, "data.nav")
      assert_eq(field, "required")
    }
    _ => assert_true(false)
  }
}

///|
test "collections error: missing schema in collection" {
  let src = "[posts]\ndir = content/posts\n"
  match parse(src) {
    Err(@collections.MissingRequiredField(name, field)) => {
      assert_eq(name, "posts")
      assert_eq(field, "schema")
    }
    _ => assert_true(false)
  }
}

///|
test "collections error: missing dir in collection" {
  let src = "[posts]\nschema = title:String\n"
  match parse(src) {
    Err(@collections.MissingRequiredField(name, field)) => {
      assert_eq(name, "posts")
      assert_eq(field, "dir")
    }
    _ => assert_true(false)
  }
}

///|
test "collections error: section header too short (single bracket)" {
  let src = "[\n"
  match parse(src) {
    Err(@collections.InvalidLine(line, msg)) => {
      assert_eq(line, 1)
      assert_eq(msg, "invalid section header")
    }
    _ => assert_true(false)
  }
}

///|
test "collections error: section header missing closing bracket" {
  let src = "[posts\nschema = title:String\n"
  match parse(src) {
    Err(@collections.InvalidLine(line, msg)) => {
      assert_eq(line, 1)
      assert_eq(msg, "invalid section header")
    }
    _ => assert_true(false)
  }
}

///|
test "collections error: empty section header" {
  let src = "[  ]\nschema = title:String\n"
  match parse(src) {
    Err(@collections.InvalidLine(line, msg)) => {
      assert_eq(line, 1)
      assert_eq(msg, "empty section header")
    }
    _ => assert_true(false)
  }
}

///|
test "collections error: invalid data schema name (empty after data.)" {
  let src = "[data.]\nrequired = title\n"
  match parse(src) {
    Err(@collections.InvalidLine(line, msg)) => {
      assert_eq(line, 1)
      assert_eq(msg, "invalid data schema name")
    }
    _ => assert_true(false)
  }
}

///|
test "collections error: invalid data schema name (numeric)" {
  let src = "[data.123]\nrequired = title\n"
  match parse(src) {
    Err(@collections.InvalidLine(line, msg)) => {
      assert_eq(line, 1)
      assert_eq(msg, "invalid data schema name")
    }
    _ => assert_true(false)
  }
}

///|
test "collections error: invalid collection name (starts with digit)" {
  let src = "[123]\nschema = title:String\n"
  match parse(src) {
    Err(@collections.InvalidLine(line, msg)) => {
      assert_eq(line, 1)
      assert_eq(msg, "invalid collection name")
    }
    _ => assert_true(false)
  }
}

///|
test "collections error: invalid collection name (special chars)" {
  let src = "[hello-world!]\nschema = title:String\n"
  match parse(src) {
    Err(@collections.InvalidLine(line, msg)) => {
      assert_eq(line, 1)
      assert_eq(msg, "invalid collection name")
    }
    _ => assert_true(false)
  }
}

///|
test "collections error: unterminated quoted string value" {
  let src = "[posts]\nschema = \"unterminated\n"
  match parse(src) {
    Err(@collections.InvalidLine(line, msg)) => {
      assert_eq(line, 2)
      assert_eq(msg, "unterminated quoted string")
    }
    _ => assert_true(false)
  }
}

///|
test "collections error: unterminated quoted string (just opening quote)" {
  let src = "[posts]\nschema = \"\n"
  match parse(src) {
    Err(@collections.InvalidLine(line, msg)) => {
      assert_eq(line, 2)
      assert_eq(msg, "unterminated quoted string")
    }
    _ => assert_true(false)
  }
}

///|
test "collections error: invalid sort value" {
  let src = "[posts]\nschema = title:String\ndir = content/posts\nsort = invalid:order\n"
  match parse(src) {
    Err(@collections.InvalidLine(line, msg)) => {
      assert_eq(line, 4)
      assert_true(msg.contains("invalid sort value"))
    }
    _ => assert_true(false)
  }
}

///|
test "collections error: invalid schema field declaration (no colon)" {
  let src = "[posts]\nschema = titleString\ndir = content/posts\n"
  match parse(src) {
    Err(@collections.InvalidSchema(name, msg)) => {
      assert_eq(name, "posts")
      assert_true(msg.contains("invalid field declaration"))
    }
    _ => assert_true(false)
  }
}

///|
test "collections error: invalid schema field name" {
  let src = "[posts]\nschema = 123:String\ndir = content/posts\n"
  match parse(src) {
    Err(@collections.InvalidSchema(name, msg)) => {
      assert_eq(name, "posts")
      assert_true(msg.contains("invalid field name"))
    }
    _ => assert_true(false)
  }
}

///|
test "collections error: empty schema (no fields)" {
  let src = "[posts]\nschema = \ndir = content/posts\n"
  match parse(src) {
    Err(@collections.InvalidLine(line, msg)) => {
      // schema = with empty value triggers "expected key=value" since value after = is empty after trim
      assert_eq(line, 2)
      assert_eq(msg, "expected key=value")
    }
    _ => assert_true(false)
  }
}

///|
test "collections error: unknown field type in schema" {
  let src = "[posts]\nschema = title:UnknownType\ndir = content/posts\n"
  match parse(src) {
    Err(@collections.InvalidSchema(name, msg)) => {
      assert_eq(name, "posts")
      assert_true(msg.contains("unknown field type"))
    }
    _ => assert_true(false)
  }
}
