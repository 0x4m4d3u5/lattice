///|
fn ensure_dir_test(path : String) -> Unit {
  if not(@fs.path_exists(path)) {
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

  let schemas : Map[String, DataSchema] = Map::new()
  schemas.set("nav", new_schema("nav", ["title", "count"]))

  match load_from_dir(root, schemas) {
    Ok(store) => {
      match resolve_string(store, "nav", ["title"]) {
        Ok(v) => assert_eq(v, "Lattice")
        Err(_) => assert_true(false)
      }
      match resolve_string(store, "nav", ["count"]) {
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
  let schemas : Map[String, DataSchema] = Map::new()
  schemas.set("site", new_schema("site", ["hero.title"]))
  match load_from_dir(root, schemas) {
    Ok(store) =>
      match resolve_string(store, "site", ["hero", "title"]) {
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
  let schemas : Map[String, DataSchema] = Map::new()
  schemas.set("nav", new_schema("nav", ["title", "links"]))
  match load_from_dir(root, schemas) {
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
  let schemas : Map[String, DataSchema] = Map::new()
  match load_from_dir("./_tmp_data_does_not_exist", schemas) {
    Ok(_) => assert_true(false)
    Err(FileNotFound(path)) => assert_eq(path, "./_tmp_data_does_not_exist")
    Err(_) => assert_true(false)
  }
}
