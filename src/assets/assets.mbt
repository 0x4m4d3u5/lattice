///|
/// Static asset traversal and copy logic.
///
/// Structural behavior:
/// - Missing source directory is not an error.
/// - Copy preserves binary bytes and relative paths.
/// - All failures are typed (no panics).
#derive(Eq, Debug)
pub(all) enum AssetCopyError {
  SourceReadError(String, String)
  SourceNotDirectory(String)
  DestCreateError(String, String)
  FileReadError(String, String)
  FileWriteError(String, String)
}

///|
pub impl Show for AssetCopyError with fn output(self, logger) {
  match self {
    SourceReadError(v0, v1) => {
      logger.write_string("SourceReadError(")
      logger.write_object(v0)
      logger.write_string(", ")
      logger.write_object(v1)
      logger.write_string(")")
    }
    SourceNotDirectory(v0) => {
      logger.write_string("SourceNotDirectory(")
      logger.write_object(v0)
      logger.write_string(")")
    }
    DestCreateError(v0, v1) => {
      logger.write_string("DestCreateError(")
      logger.write_object(v0)
      logger.write_string(", ")
      logger.write_object(v1)
      logger.write_string(")")
    }
    FileReadError(v0, v1) => {
      logger.write_string("FileReadError(")
      logger.write_object(v0)
      logger.write_string(", ")
      logger.write_object(v1)
      logger.write_string(")")
    }
    FileWriteError(v0, v1) => {
      logger.write_string("FileWriteError(")
      logger.write_object(v0)
      logger.write_string(", ")
      logger.write_object(v1)
      logger.write_string(")")
    }
  }
}

///|
#derive(Eq)
pub struct AssetValidation {
  errors : Array[AssetCopyError]
}

///|
/// A static file captured in memory, with its path relative to the static root.
#derive(Eq)
pub(all) struct StaticAsset {
  relative_path : String
  bytes : Bytes
}

///|
fn read_tree(
  source_root : String,
  relative_dir : String,
  assets : Array[StaticAsset],
  directories : Array[String],
) -> Result[Unit, AssetCopyError] {
  let src_dir = @strutil.join_path(source_root, relative_dir)
  let entries = @fs.read_dir(src_dir) catch {
    @fs.IOError(msg) => return Err(SourceReadError(src_dir, msg))
  }
  directories.push(relative_dir)
  for name in entries {
    let relative_path = @strutil.join_path(relative_dir, name)
    let src_path = @strutil.join_path(source_root, relative_path)
    let is_dir = @fs.is_dir(src_path) catch {
      @fs.IOError(msg) => return Err(SourceReadError(src_path, msg))
    }
    if is_dir {
      match read_tree(source_root, relative_path, assets, directories) {
        Ok(_) => ()
        Err(e) => return Err(e)
      }
    } else {
      let bytes = @fs.read_file_to_bytes(src_path) catch {
        @fs.IOError(msg) => return Err(FileReadError(src_path, msg))
      }
      assets.push({ relative_path, bytes })
    }
  }
  Ok(())
}

///|
fn ensure_dir(path : String) -> Result[Unit, AssetCopyError] {
  if @fs.path_exists(path) {
    let exists_as_dir = @fs.is_dir(path) catch {
      @fs.IOError(msg) => return Err(SourceReadError(path, msg))
    }
    if exists_as_dir {
      Ok(())
    } else {
      Err(DestCreateError(path, "path exists and is not a directory"))
    }
  } else {
    try {
      @fs.create_dir(path)
      Ok(())
    } catch {
      @fs.IOError(msg) => Err(DestCreateError(path, msg))
    }
  }
}

///|
fn copy_file(
  src_file : String,
  dest_file : String,
) -> Result[Unit, AssetCopyError] {
  let bytes = @fs.read_file_to_bytes(src_file) catch {
    @fs.IOError(msg) => return Err(FileReadError(src_file, msg))
  }
  try {
    @fs.write_bytes_to_file(dest_file, bytes)
    Ok(())
  } catch {
    @fs.IOError(msg) => Err(FileWriteError(dest_file, msg))
  }
}

///|
fn copy_tree(
  src_dir : String,
  dest_dir : String,
) -> Result[Int, AssetCopyError] {
  match ensure_dir(dest_dir) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }

  let entries = @fs.read_dir(src_dir) catch {
    @fs.IOError(msg) => return Err(SourceReadError(src_dir, msg))
  }

  let mut copied = 0
  let mut i = 0
  while i < entries.length() {
    let name = entries[i]
    let src_path = @strutil.join_path(src_dir, name)
    let dest_path = @strutil.join_path(dest_dir, name)
    let is_dir = @fs.is_dir(src_path) catch {
      @fs.IOError(msg) => return Err(SourceReadError(src_path, msg))
    }
    if is_dir {
      match copy_tree(src_path, dest_path) {
        Ok(n) => copied = copied + n
        Err(e) => return Err(e)
      }
    } else {
      match copy_file(src_path, dest_path) {
        Ok(_) => copied = copied + 1
        Err(e) => return Err(e)
      }
    }
    i = i + 1
  }
  Ok(copied)
}

///|
fn validate_tree(path : String, errors : Array[AssetCopyError]) -> Unit {
  let entries = @fs.read_dir(path) catch {
    @fs.IOError(msg) => {
      errors.push(SourceReadError(path, msg))
      return
    }
  }

  let mut i = 0
  while i < entries.length() {
    let entry_path = @strutil.join_path(path, entries[i])
    let is_dir = @fs.is_dir(entry_path) catch {
      @fs.IOError(msg) => {
        errors.push(SourceReadError(entry_path, msg))
        i = i + 1
        continue
      }
    }
    if is_dir {
      validate_tree(entry_path, errors)
    } else {
      let _ = @fs.read_file_to_bytes(entry_path) catch {
        @fs.IOError(msg) => {
          errors.push(FileReadError(entry_path, msg))
          i = i + 1
          continue
        }
      }
    }
    i = i + 1
  }
}

///|
pub fn error_path(err : AssetCopyError) -> String {
  match err {
    SourceReadError(path, _) => path
    SourceNotDirectory(path) => path
    DestCreateError(path, _) => path
    FileReadError(path, _) => path
    FileWriteError(path, _) => path
  }
}

///|
pub fn format_error(err : AssetCopyError) -> String {
  match err {
    SourceReadError(path, msg) =>
      "cannot read static assets source " + path + ": " + msg
    SourceNotDirectory(path) =>
      "static assets path exists but is not a directory: " + path
    DestCreateError(path, msg) =>
      "cannot create static asset directory " + path + ": " + msg
    FileReadError(path, msg) =>
      "cannot read static asset file " + path + ": " + msg
    FileWriteError(path, msg) =>
      "cannot write static asset file " + path + ": " + msg
  }
}

///|
/// Validate static assets readability without writing output files.
pub fn check_static(site_root : String, static_dir : String) -> AssetValidation {
  let errors : Array[AssetCopyError] = []
  let source_root = @strutil.join_path(site_root, static_dir)

  if !@fs.path_exists(source_root) {
    return { errors, }
  }

  let is_source_dir = @fs.is_dir(source_root) catch {
    @fs.IOError(msg) => {
      errors.push(SourceReadError(source_root, msg))
      return { errors, }
    }
  }
  if !is_source_dir {
    errors.push(SourceNotDirectory(source_root))
    return { errors, }
  }

  validate_tree(source_root, errors)
  { errors, }
}

///|
/// Snapshot `site_root/static_dir` without writing any files or directories.
///
/// Paths are relative to the static root. Missing source is an empty snapshot.
/// On success, append all source directories to `directories`, including ""
/// for the static root, so callers can preserve empty directories on publish.
pub fn read_static(
  site_root : String,
  static_dir : String,
  directories? : Array[String] = [],
) -> Result[Array[StaticAsset], AssetCopyError] {
  let source_root = @strutil.join_path(site_root, static_dir)
  if !@fs.path_exists(source_root) {
    return Ok([])
  }
  let source_is_dir = @fs.is_dir(source_root) catch {
    @fs.IOError(msg) => return Err(SourceReadError(source_root, msg))
  }
  if !source_is_dir {
    return Err(SourceNotDirectory(source_root))
  }
  let assets : Array[StaticAsset] = []
  let snapshot_directories : Array[String] = []
  match read_tree(source_root, "", assets, snapshot_directories) {
    Ok(_) => {
      directories.append(snapshot_directories)
      Ok(assets)
    }
    Err(e) => Err(e)
  }
}

///|
/// Copy `site_root/static_dir` to `output_dir/static_dir`.
///
/// Returns the number of files copied. Missing source directory is a no-op.
pub fn copy_static(
  site_root : String,
  output_dir : String,
  static_dir : String,
) -> Result[Int, AssetCopyError] {
  let source_root = @strutil.join_path(site_root, static_dir)
  if !@fs.path_exists(source_root) {
    return Ok(0)
  }

  let source_is_dir = @fs.is_dir(source_root) catch {
    @fs.IOError(msg) => return Err(SourceReadError(source_root, msg))
  }
  if !source_is_dir {
    return Err(SourceNotDirectory(source_root))
  }

  let dest_root = @strutil.join_path(output_dir, static_dir)
  copy_tree(source_root, dest_root)
}

///|
pub impl Show for AssetValidation with fn output(self, logger) {
  logger.write_string("{errors: ")
  logger.write_iter(self.errors.iter())
  logger.write_string("}")
}

///|
pub impl Show for StaticAsset with fn output(self, logger) {
  logger.write_string("{relative_path: ")
  logger.write_object(self.relative_path)
  logger.write_string(", bytes: ")
  logger.write_object(self.bytes)
  logger.write_string("}")
}

///|
pub extend AssetCopyError with @debug.Debug::{to_repr}

///|
pub extend AssetCopyError with Eq::{not_equal, equal}

///|
pub extend AssetCopyError with Show::{to_string, output}

///|
pub extend AssetValidation with Eq::{not_equal, equal}

///|
pub extend AssetValidation with Show::{to_string, output}

///|
pub extend StaticAsset with Eq::{not_equal, equal}

///|
pub extend StaticAsset with Show::{to_string, output}

///|
/// Selected bytes and withheld file names, relative to the configured static root.
/// Withheld files are inventoried without opening their contents.
pub struct StaticSelection {
  assets : Array[StaticAsset]
  withheld_paths : Array[String]
}

///|
fn inventory_static_tree(
  source_root : String,
  relative_dir : String,
  files : Array[String],
) -> Result[Unit, AssetCopyError] {
  let path = @strutil.join_path(source_root, relative_dir)
  let entries = @fs.read_dir(path) catch {
    @fs.IOError(msg) => return Err(SourceReadError(path, msg))
  }
  for name in entries {
    let relative_path = @strutil.join_path(relative_dir, name)
    let source = @strutil.join_path(source_root, relative_path)
    let is_dir = @fs.is_dir(source) catch {
      @fs.IOError(msg) => return Err(SourceReadError(source, msg))
    }
    if is_dir {
      match inventory_static_tree(source_root, relative_path, files) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
    } else {
      files.push(relative_path)
    }
  }
  Ok(())
}

///|
/// None retains legacy copy-all semantics (including empty directories).
/// Some([]) withholds every file. Some(paths) reads only exact named files and
/// records only their parent directories, never unrelated empty directories.
/// Named missing paths and directories fail before any file bytes are read.
///
/// Like read_static, this assumes a stable, trusted source tree. The portable
/// x/fs API follows symlinks and has no lstat/realpath; this is an authoring
/// policy, not a sandbox against symlinks or concurrent filesystem mutation.
pub fn read_static_selected(
  site_root : String,
  static_dir : String,
  allowlist : Array[String]?,
  directories? : Array[String] = [],
) -> Result[StaticSelection, AssetCopyError] {
  let paths = match allowlist {
    None => return match read_static(site_root, static_dir, directories~) {
      Ok(assets) => Ok({ assets, withheld_paths: [] })
      Err(e) => Err(e)
    }
    Some(paths) => paths
  }
  let source_root = @strutil.join_path(site_root, static_dir)
  match @config.validate_static_allowlist(paths) {
    Err(@config.InvalidValue(_, msg)) => return Err(SourceReadError(source_root, msg))
    Err(_) => return Err(SourceReadError(source_root, "invalid static_allowlist"))
    Ok(_) => ()
  }
  if !@fs.path_exists(source_root) {
    if paths.is_empty() {
      return Ok({ assets: [], withheld_paths: [] })
    }
    return Err(FileReadError(@strutil.join_path(source_root, paths[0]), "allowlisted static file does not exist"))
  }
  let is_dir = @fs.is_dir(source_root) catch {
    @fs.IOError(msg) => return Err(SourceReadError(source_root, msg))
  }
  if !is_dir {
    return Err(SourceNotDirectory(source_root))
  }
  // Validate the entire selection before opening any selected file.
  let selected : Map[String, Bool] = Map([])
  for relative_path in paths {
    let source = @strutil.join_path(source_root, relative_path)
    if !@fs.path_exists(source) {
      return Err(FileReadError(source, "allowlisted static file does not exist"))
    }
    let is_file = @fs.is_file(source) catch {
      @fs.IOError(msg) => return Err(FileReadError(source, msg))
    }
    if !is_file {
      return Err(FileReadError(source, "allowlisted static path is not a regular file"))
    }
    selected[relative_path] = true
  }
  let files : Array[String] = []
  match inventory_static_tree(source_root, "", files) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  files.sort()
  let withheld_paths = files.filter(fn(path) { !selected.contains(path) })
  let assets : Array[StaticAsset] = []
  let selected_directories : Array[String] = []
  for relative_path in paths {
    let source = @strutil.join_path(source_root, relative_path)
    let bytes = @fs.read_file_to_bytes(source) catch {
      @fs.IOError(msg) => return Err(FileReadError(source, msg))
    }
    assets.push({ relative_path, bytes })
    let parts = relative_path.split("/").collect()
    let mut parent = ""
    for i = 0; i < parts.length(); i = i + 1 {
      if !selected_directories.contains(parent) {
        selected_directories.push(parent)
      }
      parent = @strutil.join_path(parent, parts[i].to_owned())
    }
  }
  directories.append(selected_directories)
  Ok({ assets, withheld_paths })
}
