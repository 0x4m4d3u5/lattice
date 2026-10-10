///|
fn setup_dir(path : String) -> Unit {
  if !@fs.path_exists(path) {
    @fs.create_dir(path) catch {
      @fs.IOError(_) => ()
    }
  }
}

///|
fn write_file(path : String, content : String) -> Unit {
  @fs.write_string_to_file(path, content) catch {
    @fs.IOError(_) => ()
  }
}

// ── error_path ────────────────────────────────────────────────────────────────

///|
test "error_path returns path from SourceReadError" {
  assert_eq(error_path(SourceReadError("/a/b", "msg")), "/a/b")
}

///|
test "error_path returns path from SourceNotDirectory" {
  assert_eq(error_path(SourceNotDirectory("/a/b")), "/a/b")
}

///|
test "error_path returns path from DestCreateError" {
  assert_eq(error_path(DestCreateError("/out/b", "msg")), "/out/b")
}

///|
test "error_path returns path from FileReadError" {
  assert_eq(error_path(FileReadError("/f.png", "msg")), "/f.png")
}

///|
test "error_path returns path from FileWriteError" {
  assert_eq(error_path(FileWriteError("/f.png", "msg")), "/f.png")
}

// ── format_error ─────────────────────────────────────────────────────────────

///|
test "format_error SourceReadError includes path and reason" {
  assert_eq(
    format_error(SourceReadError("/static", "permission denied")),
    "cannot read static assets source /static: permission denied",
  )
}

///|
test "format_error SourceNotDirectory includes path" {
  assert_eq(
    format_error(SourceNotDirectory("/static")),
    "static assets path exists but is not a directory: /static",
  )
}

///|
test "format_error DestCreateError includes path and reason" {
  assert_eq(
    format_error(DestCreateError("/out/static", "disk full")),
    "cannot create static asset directory /out/static: disk full",
  )
}

///|
test "format_error FileReadError includes path and reason" {
  assert_eq(
    format_error(FileReadError("/static/img.png", "read error")),
    "cannot read static asset file /static/img.png: read error",
  )
}

///|
test "format_error FileWriteError includes path and reason" {
  assert_eq(
    format_error(FileWriteError("/out/img.png", "write error")),
    "cannot write static asset file /out/img.png: write error",
  )
}

// ── copy_static ───────────────────────────────────────────────────────────────

///|
test "copy_static is a no-op when site root does not exist" {
  assert_eq(
    copy_static(
      "_tmp_assets_missing_9x7z", "_tmp_assets_missing_out_9x7z", "static",
    ),
    Ok(0),
  )
}

///|
test "copy_static returns SourceNotDirectory when static path is a regular file" {
  let site = "_tmp_assets_copy_notdir"
  setup_dir(site)
  write_file(@strutil.join_path(site, "static"), "not a directory")
  let result = copy_static(site, site + "_out", "static")
  match result {
    Err(SourceNotDirectory(_)) => ()
    _ => assert_true(false)
  }
}

///|
test "copy_static copies a flat directory of files" {
  let site = "_tmp_assets_copy_flat"
  let out = "_tmp_assets_copy_flat_out"
  setup_dir(site)
  setup_dir(out)
  let src = @strutil.join_path(site, "static")
  setup_dir(src)
  write_file(@strutil.join_path(src, "style.css"), "body { margin: 0; }")
  let result = copy_static(site, out, "static")
  assert_eq(result, Ok(1))
  assert_eq(
    @fs.path_exists(
      @strutil.join_path(@strutil.join_path(out, "static"), "style.css"),
    ),
    true,
  )
}

///|
test "copy_static copies nested directory tree and returns total file count" {
  let site = "_tmp_assets_copy_tree"
  let out = "_tmp_assets_copy_tree_out"
  setup_dir(site)
  setup_dir(out)
  let src = @strutil.join_path(site, "static")
  let subdir = @strutil.join_path(src, "images")
  setup_dir(src)
  setup_dir(subdir)
  write_file(@strutil.join_path(src, "main.css"), ".a{}")
  write_file(@strutil.join_path(subdir, "logo.svg"), "<svg/>")
  let result = copy_static(site, out, "static")
  assert_eq(result, Ok(2))
}

// ── check_static ─────────────────────────────────────────────────────────────

///|
test "check_static returns no errors when source directory does not exist" {
  let v = check_static("_tmp_assets_check_missing_9x7z", "static")
  assert_eq(v.errors.length(), 0)
}

///|
test "check_static returns SourceNotDirectory when static path is a regular file" {
  let site = "_tmp_assets_check_notdir"
  setup_dir(site)
  write_file(@strutil.join_path(site, "static"), "not a directory")
  let v = check_static(site, "static")
  assert_eq(v.errors.length(), 1)
  match v.errors[0] {
    SourceNotDirectory(_) => ()
    _ => assert_true(false)
  }
}

///|
test "check_static returns no errors for a readable static directory" {
  let site = "_tmp_assets_check_ok"
  setup_dir(site)
  let src = @strutil.join_path(site, "static")
  setup_dir(src)
  write_file(@strutil.join_path(src, "style.css"), "body {}")
  let v = check_static(site, "static")
  assert_eq(v.errors.length(), 0)
}

///|
test "read_static preserves binary bytes in an independent snapshot" {
  let site = "_tmp_assets_read_binary"
  let src = @strutil.join_path(site, "static")
  let file = @strutil.join_path(src, "image.bin")
  setup_dir(site)
  setup_dir(src)
  let bytes = Bytes::from_array([0, 127, 128, 255, 10])
  @fs.write_bytes_to_file(file, bytes) catch {
    @fs.IOError(_) => assert_true(false)
  }
  let result = read_static(site, "static")
  write_file(file, "changed after snapshot")
  match result {
    Ok(assets) => {
      assert_eq(assets.length(), 1)
      assert_eq(assets[0].relative_path, "image.bin")
      assert_eq(assets[0].bytes, bytes)
    }
    Err(_) => assert_true(false)
  }
}

///|
test "read_static keeps nested paths relative to the configured static root" {
  let site = "_tmp_assets_read_tree"
  let src = @strutil.join_path(site, "public")
  let images = @strutil.join_path(src, "images")
  let icons = @strutil.join_path(images, "icons")
  setup_dir(site)
  setup_dir(src)
  setup_dir(images)
  setup_dir(icons)
  write_file(@strutil.join_path(src, "main.css"), "a")
  write_file(@strutil.join_path(icons, "logo.svg"), "b")
  match read_static(site, "public") {
    Ok(assets) => {
      assert_eq(assets.length(), 2)
      let paths = assets.map(fn(asset) { asset.relative_path })
      assert_true(paths.contains("main.css"))
      assert_true(paths.contains("images/icons/logo.svg"))
    }
    Err(_) => assert_true(false)
  }
}

///|
test "read_static leaves missing source paths absent" {
  let site = "_tmp_assets_read_missing_9x7z"
  let directories : Array[String] = []
  assert_true(!@fs.path_exists(site))
  match read_static(site, "static", directories~) {
    Ok(assets) => assert_eq(assets.length(), 0)
    Err(_) => assert_true(false)
  }
  assert_eq(directories.length(), 0)
  assert_true(!@fs.path_exists(site))
}

///|
test "read_static returns SourceNotDirectory for a regular file" {
  let site = "_tmp_assets_read_notdir"
  let path = @strutil.join_path(site, "static")
  setup_dir(site)
  write_file(path, "not a directory")
  match read_static(site, "static") {
    Err(SourceNotDirectory(actual)) => assert_eq(actual, path)
    _ => assert_true(false)
  }
}

///|
test "read_static records the static root and empty nested directories" {
  let site = "_tmp_assets_read_empty"
  let src = @strutil.join_path(site, "static")
  let empty_dir = @strutil.join_path(src, "empty")
  setup_dir(site)
  setup_dir(src)
  setup_dir(empty_dir)
  setup_dir(@strutil.join_path(empty_dir, "nested"))
  let directories : Array[String] = []
  match read_static(site, "static", directories~) {
    Ok(assets) => assert_eq(assets.length(), 0)
    Err(_) => assert_true(false)
  }
  assert_eq(directories, ["", "empty", "empty/nested"])
}
