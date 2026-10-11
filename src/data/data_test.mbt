///|
fn ensure_dir_test(path : String) -> Unit {
  if !@fs.path_exists(path) {
    @fs.create_dir(path) catch {
      @fs.IOError(_) => ()
    }
  }
}

///|
fn write_file_test(path : String, content : String) -> Bool {
  try {
    @fs.write_string_to_file(path, content)
    true
  } catch {
    @fs.IOError(_) => false
  }
}

///|
fn reset_dir(path : String) -> Unit {
  ensure_dir_test(path)
  let files = @fs.read_dir(path) catch { @fs.IOError(_) => [] }
  let mut i = 0
  while i < files.length() {
    @fs.remove_file(path + "/" + files[i]) catch {
      @fs.IOError(_) => ()
    }
    i = i + 1
  }
}

///|
test "data load and resolve" {
  let root = "./_tmp_data_basic"
  reset_dir(root)
  assert_true(
    write_file_test(root + "/nav.toml", "title = \"Lattice\"\ncount = 3\n"),
  )

  let schemas : Map[String, @data.DataSchema] = Map([])
  schemas.set("nav", @data.new_schema("nav", ["title", "count"]))

  match @data.load_from_dir(root, schemas) {
    Ok(store) => {
      match @data.resolve_string(store, "nav", ["title"]) {
        Ok(v) => assert_eq(v, "Lattice")
        Err(_) => assert_true(false)
      }
      match @data.resolve_string(store, "nav", ["count"]) {
        Ok(v) => assert_eq(v, "3")
        Err(_) => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "data nested keys" {
  let root = "./_tmp_data_nested"
  reset_dir(root)
  assert_true(
    write_file_test(root + "/site.toml", "hero.title = \"Welcome\"\n"),
  )
  let schemas : Map[String, @data.DataSchema] = Map([])
  schemas.set("site", @data.new_schema("site", ["hero.title"]))
  match @data.load_from_dir(root, schemas) {
    Ok(store) =>
      match @data.resolve_string(store, "site", ["hero", "title"]) {
        Ok(v) => assert_eq(v, "Welcome")
        Err(_) => assert_true(false)
      }
    Err(_) => assert_true(false)
  }
}

///|
test "data required key missing" {
  let root = "./_tmp_data_required"
  reset_dir(root)
  assert_true(write_file_test(root + "/nav.toml", "title = \"Only\"\n"))
  let schemas : Map[String, @data.DataSchema] = Map([])
  schemas.set("nav", @data.new_schema("nav", ["title", "links"]))
  match @data.load_from_dir(root, schemas) {
    Ok(_) => assert_true(false)
    Err(ValidationError(file, key, msg)) => {
      assert_eq(file, "nav")
      assert_eq(key, "links")
      assert_eq(msg, "required key missing")
    }
    Err(_) => assert_true(false)
  }
}

///|
test "data unknown dir" {
  let schemas : Map[String, @data.DataSchema] = Map([])
  match @data.load_from_dir("./_tmp_data_does_not_exist", schemas) {
    Ok(_) => assert_true(false)
    Err(FileNotFound(path)) => assert_eq(path, "./_tmp_data_does_not_exist")
    Err(_) => assert_true(false)
  }
}

// ── format_error ─────────────────────────────────────────────────────────────

///|
test "format_error FileNotFound" {
  assert_eq(
    @data.format_error(FileNotFound("/data")),
    "data directory not found: /data",
  )
}

///|
test "format_error ParseError" {
  assert_eq(
    @data.format_error(ParseError("/data/nav.toml", 3, "expected key=value")),
    "/data/nav.toml:3: expected key=value",
  )
}

///|
test "format_error ValidationError with key" {
  assert_eq(
    @data.format_error(ValidationError("nav", "links", "required key missing")),
    "data.nav.links: required key missing",
  )
}

///|
test "format_error ValidationError empty key" {
  assert_eq(
    @data.format_error(ValidationError("nav", "", "data file not found")),
    "data.nav: data file not found",
  )
}

///|
test "format_error IOError" {
  assert_eq(
    @data.format_error(IOError("/data/nav.toml", "permission denied")),
    "data I/O error /data/nav.toml: permission denied",
  )
}

// ── value_to_string ───────────────────────────────────────────────────────────

///|
test "value_to_string FInt" {
  assert_eq(@data.value_to_string(@frontmatter.FInt(42)), "42")
}

///|
test "value_to_string FBool true" {
  assert_eq(@data.value_to_string(@frontmatter.FBool(true)), "true")
}

///|
test "value_to_string FBool false" {
  assert_eq(@data.value_to_string(@frontmatter.FBool(false)), "false")
}

///|
test "value_to_string FArray" {
  assert_eq(
    @data.value_to_string(
      @frontmatter.FArray([
        @frontmatter.FStr("a"),
        @frontmatter.FStr("b"),
        @frontmatter.FStr("c"),
      ]),
    ),
    "a, b, c",
  )
}

///|
test "value_to_string FMap renders placeholder" {
  let map : Map[String, @frontmatter.FrontmatterValue] = Map([])
  map.set("key", @frontmatter.FStr("val"))
  assert_eq(@data.value_to_string(@frontmatter.FMap(map)), "[object]")
}

// ── empty_store + get_file ────────────────────────────────────────────────────

///|
test "empty_store has no files" {
  let store = @data.empty_store()
  assert_true(@data.get_file(store, "nav") is None)
}

///|
test "get_file returns Some for existing file" {
  let store = @data.new_store([
    @data.new_string_file("nav", [("title", "Lattice")]),
  ])
  assert_true(@data.get_file(store, "nav") is Some(_))
  assert_true(@data.get_file(store, "missing") is None)
}

// ── resolve error paths ───────────────────────────────────────────────────────

///|
test "resolve returns error for missing file" {
  let store = @data.empty_store()
  match @data.resolve(store, "nav", ["title"]) {
    Err(ValidationError(file, key, msg)) => {
      assert_eq(file, "nav")
      assert_eq(key, "")
      assert_eq(msg, "data file not found")
    }
    _ => assert_true(false)
  }
}

///|
test "resolve returns error for missing key" {
  let store = @data.new_store([
    @data.new_string_file("nav", [("title", "Lattice")]),
  ])
  match @data.resolve(store, "nav", ["missing"]) {
    Err(ValidationError(file, key, msg)) => {
      assert_eq(file, "nav")
      assert_eq(key, "missing")
      assert_eq(msg, "key not found")
    }
    _ => assert_true(false)
  }
}

// ── non-string data types via load_from_dir ───────────────────────────────────

///|
test "data boolean and integer values parse correctly" {
  let root = "./_tmp_data_types"
  reset_dir(root)
  assert_true(write_file_test(root + "/cfg.toml", "active = true\ncount = 7\n"))
  let schemas : Map[String, @data.DataSchema] = Map([])
  match @data.load_from_dir(root, schemas) {
    Ok(store) => {
      match @data.resolve_string(store, "cfg", ["active"]) {
        Ok(v) => assert_eq(v, "true")
        Err(_) => assert_true(false)
      }
      match @data.resolve_string(store, "cfg", ["count"]) {
        Ok(v) => assert_eq(v, "7")
        Err(_) => assert_true(false)
      }
    }
    Err(_) => assert_true(false)
  }
}

///|
test "data parse error on malformed assignment" {
  let root = "./_tmp_data_parse_err"
  reset_dir(root)
  assert_true(write_file_test(root + "/bad.toml", "= missing key\n"))
  let schemas : Map[String, @data.DataSchema] = Map([])
  match @data.load_from_dir(root, schemas) {
    Ok(_) => assert_true(false)
    Err(ParseError(path, line, _)) => {
      assert_true(path.contains("bad.toml"))
      assert_eq(line, 1)
    }
    Err(_) => assert_true(false)
  }
}
