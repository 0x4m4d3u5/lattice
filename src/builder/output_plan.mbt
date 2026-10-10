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
    directory_index: Map::new(),
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
  self.add_directory(self.contained_path(path, true))
}

///|
fn OutputPlan::ensure_parent_dirs(
  self : OutputPlan,
  path : String,
) -> Unit raise @fs.IOError {
  self.ensure_dir(@path.Path(path).dirname().to_string())
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
  for dir in self.directories {
    if !@fs.path_exists(dir) {
      @fs.create_dir(dir)
    }
  }
  // Preserve ordered same-file writes (for example warning-only redirects).
  // Cache and manifest are appended last by the builder.
  for file in self.files {
    match file.1 {
      Text(content) => @fs.write_string_to_file(file.0, content)
      OptionalText(content) =>
        try {
          @fs.write_string_to_file(file.0, content)
          messages.push("[lattice] wrote " + file.0)
        } catch {
          @fs.IOError(msg) =>
            diagnostics.push(
              build_warning(
                Some(file.0),
                None,
                None,
                "could not write optional output: " + msg,
              ),
            )
        }
      Binary(content) => @fs.write_bytes_to_file(file.0, content)
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
