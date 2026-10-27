///|
/// Prepared output is kept separate from filesystem mutation. This is a
/// validation/generation boundary, not a crash-safe filesystem transaction.
priv enum OutputContents {
  Text(String)
  OptionalText(String)
  Binary(Bytes)
}

///|
priv struct OutputPlan {
  root : String
  directories : Array[String]
  requested_directories : Array[String]
  directory_index : Map[String, Bool]
  files : Array[(String, OutputContents)]
}

///|
fn output_path_key(path : String) -> String {
  // Use the filesystem library's path normalization rather than parsing paths.
  @path.Path::join(@path.Path(path), @path.Path(".")).to_string()
}

///|
fn OutputPlan::new(root : String) -> OutputPlan {
  {
    root: output_path_key(root),
    directories: [],
    requested_directories: [],
    directory_index: Map([]),
    files: [],
  }
}

///|
fn OutputPlan::contained_path(
  self : OutputPlan,
  path : String,
  allow_root : Bool,
) -> String raise @fs.IOError {
  let key = output_path_key(path)
  let relative = @path.Path(key)
    .relative(base=@path.Path(self.root))
    .to_string()
  if (!allow_root && (relative == "" || relative == ".")) ||
    relative == ".." ||
    relative.has_prefix("../") ||
    relative.has_prefix("..\\") ||
    @path.Path(relative).is_absolute() {
    raise @fs.IOError("output path escapes output directory: " + path)
  }
  key
}

///|
fn OutputPlan::add_directory(self : OutputPlan, key : String) -> Unit {
  if self.directory_index.contains(key) {
    return
  }
  let parent = @path.Path(key).dirname().to_string()
  if parent != key {
    self.add_directory(parent)
  }
  self.directory_index.set(key, true)
  self.directories.push(key)
}

///|
fn OutputPlan::ensure_dir(
  self : OutputPlan,
  path : String,
) -> Unit raise @fs.IOError {
  let key = self.contained_path(path, true)
  self.requested_directories.push(key)
  self.add_directory(key)
}

///|
fn OutputPlan::ensure_parent_dirs(
  self : OutputPlan,
  path : String,
) -> Unit raise @fs.IOError {
  self.add_directory(
    self.contained_path(@path.Path(path).dirname().to_string(), true),
  )
}

///|
fn OutputPlan::file_path(
  self : OutputPlan,
  path : String,
) -> String raise @fs.IOError {
  let key = self.contained_path(path, false)
  self.ensure_parent_dirs(key)
  key
}

///|
fn OutputPlan::write_text(
  self : OutputPlan,
  path : String,
  content : String,
) -> Unit raise @fs.IOError {
  self.files.push((self.file_path(path), Text(content)))
}

///|
fn OutputPlan::write_optional_text(
  self : OutputPlan,
  path : String,
  content : String,
) -> Unit raise @fs.IOError {
  self.files.push((self.file_path(path), OptionalText(content)))
}

///|
fn OutputPlan::write_bytes(
  self : OutputPlan,
  path : String,
  content : Bytes,
) -> Unit raise @fs.IOError {
  self.files.push((self.file_path(path), Binary(content)))
}

///|
fn OutputPlan::prune_files(self : OutputPlan, dropped : Map[Int, Bool]) -> Unit {
  let retained = self.files.iter2().iter().filter_map(fn(pair) {
    let (index, file) = pair
    if dropped.contains(index) { None } else { Some(file) }
  }).to_array()
  self.files.clear()
  for file in retained {
    self.files.push(file)
  }
  // Preserve explicit requests (including empty static directories), but derive
  // file parents again so removed reservations cannot conflict with final files.
  self.directories.clear()
  self.directory_index.clear()
  for path in self.requested_directories {
    self.add_directory(path)
  }
  for (path, _) in self.files {
    self.add_directory(@path.Path(path).dirname().to_string())
  }
}

///|
fn OutputPlan::preflight(self : OutputPlan) -> Unit raise @fs.IOError {
  // Check the entire plan before mkdir or the first write. In particular, a
  // late cache/manifest or nested index conflict must not replace earlier HTML.
  for dir in self.directories {
    if @fs.path_exists(dir) && !@fs.is_dir(dir) {
      raise @fs.IOError("output directory is an existing file: " + dir)
    }
  }
  for file in self.files {
    let path = file.0
    if self.directory_index.contains(path) {
      raise @fs.IOError("output path is both a file and a directory: " + path)
    }
    let optional = match file.1 {
      OptionalText(_) => true
      _ => false
    }
    if !optional && @fs.path_exists(path) && !@fs.is_file(path) {
      raise @fs.IOError("output file is not a regular file: " + path)
    }
  }
}

///|
fn OutputPlan::publish(
  self : OutputPlan,
  diagnostics : Array[@diagnostic.Diagnostic],
  messages : Array[String],
) -> Unit raise @fs.IOError {
  self.preflight()
  if !staged_publication_supported() {
    raise @fs.IOError(
      "staged publication requires the supported Node/JavaScript CLI; this backend has no tested replacement adapter",
    )
  }
  for dir in self.directories {
    if !@fs.path_exists(dir) {
      @fs.create_dir(dir)
    }
  }
  let staged : Array[(String, String, Bool)] = []
  try {
    // Stage all required bytes before replacing even the first destination.
    for (path, content) in self.files {
      let (bytes, optional) = match content {
        Text(text) => (@utf8.encode(text), false)
        OptionalText(text) => (@utf8.encode(text), true)
        Binary(bytes) => (bytes, false)
      }
      staged.push((stage_output(path, bytes), path, optional)) catch {
        @fs.IOError(msg) =>
          if optional {
            diagnostics.push(
              build_warning(
                Some(path),
                None,
                None,
                "could not write optional output: " + msg,
              ),
            )
          } else {
            raise @fs.IOError(msg)
          }
      }
    }
    // Retain ordered overwrites, with cache and manifest last. A rename failure
    // can leave earlier complete replacements; there is no directory transaction.
    for (temporary, path, optional) in staged {
      try {
        replace_output(temporary, path)
        if optional {
          messages.push("[lattice] wrote " + path)
        }
      } catch {
        @fs.IOError(msg) =>
          if optional {
            diagnostics.push(
              build_warning(
                Some(path),
                None,
                None,
                "could not write optional output: " + msg,
              ),
            )
          } else {
            raise @fs.IOError(msg)
          }
      }
    }
  } catch {
    @fs.IOError(msg) => {
      for (temporary, _, _) in staged {
        let cleanup = discard_output(temporary)
        if cleanup != "" {
          diagnostics.push(build_warning(Some(temporary), None, None, cleanup))
        }
      }
      raise @fs.IOError(msg)
    }
  }
  for (temporary, _, _) in staged {
    let cleanup = discard_output(temporary)
    if cleanup != "" {
      diagnostics.push(build_warning(Some(temporary), None, None, cleanup))
    }
  }
}

///|
fn plan_static_assets(
  config : BuildConfig,
  output : OutputPlan,
) -> Result[Int, @assets.AssetCopyError] {
  let static_dir = static_dir_name(config.site)
  let directories : Array[String] = []
  let assets = match
    @assets.read_static(config.content_dir, static_dir, directories~) {
    Ok(assets) => assets
    Err(err) => return Err(err)
  }
  let destination = @strutil.join_path(config.output_dir, static_dir)
  for directory in directories {
    let path = @strutil.join_path(destination, directory)
    output.ensure_dir(path) catch {
      @fs.IOError(msg) => return Err(@assets.DestCreateError(path, msg))
    }
  }
  for asset in assets {
    let path = @strutil.join_path(destination, asset.relative_path)
    output.write_bytes(path, asset.bytes) catch {
      @fs.IOError(msg) => return Err(@assets.FileWriteError(path, msg))
    }
  }
  Ok(assets.length())
}
