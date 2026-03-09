///|
/// Static asset traversal and copy logic.
///
/// Structural behavior:
/// - Missing source directory is not an error.
/// - Copy preserves binary bytes and relative paths.
/// - All failures are typed (no panics).

pub enum AssetCopyError {
  SourceReadError(String, String)
  SourceNotDirectory(String)
  DestCreateError(String, String)
  FileReadError(String, String)
  FileWriteError(String, String)
}

pub struct AssetValidation {
  errors : Array[AssetCopyError]
}

fn join_path(base : String, part : String) -> String {
  if base.length() == 0 {
    return part
  }
  if part.length() == 0 {
    return base
  }
  base + "/" + part
}

fn ensure_dir(path : String) -> Result[Unit, AssetCopyError] {
  if @fs.path_exists(path) {
    let exists_as_dir = try {
      @fs.is_dir(path)
    } catch {
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

fn copy_file(src_file : String, dest_file : String) -> Result[Unit, AssetCopyError] {
  let bytes = try {
    @fs.read_file_to_bytes(src_file)
  } catch {
    @fs.IOError(msg) => return Err(FileReadError(src_file, msg))
  }
  try {
    @fs.write_bytes_to_file(dest_file, bytes)
    Ok(())
  } catch {
    @fs.IOError(msg) => Err(FileWriteError(dest_file, msg))
  }
}

fn copy_tree(src_dir : String, dest_dir : String) -> Result[Int, AssetCopyError] {
  match ensure_dir(dest_dir) {
    Ok(_) => ()
    Err(e) => return Err(e)
  }

  let entries = try {
    @fs.read_dir(src_dir)
  } catch {
    @fs.IOError(msg) => return Err(SourceReadError(src_dir, msg))
  }

  let mut copied = 0
  let mut i = 0
  while i < entries.length() {
    let name = entries[i]
    let src_path = join_path(src_dir, name)
    let dest_path = join_path(dest_dir, name)
    let is_dir = try {
      @fs.is_dir(src_path)
    } catch {
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

fn validate_tree(path : String, errors : Array[AssetCopyError]) -> Unit {
  let entries = try {
    @fs.read_dir(path)
  } catch {
    @fs.IOError(msg) => {
      errors.push(SourceReadError(path, msg))
      return
    }
  }

  let mut i = 0
  while i < entries.length() {
    let entry_path = join_path(path, entries[i])
    let is_dir = try {
      @fs.is_dir(entry_path)
    } catch {
      @fs.IOError(msg) => {
        errors.push(SourceReadError(entry_path, msg))
        i = i + 1
        continue
      }
    }
    if is_dir {
      validate_tree(entry_path, errors)
    } else {
      let _ = try {
        @fs.read_file_to_bytes(entry_path)
      } catch {
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

pub fn error_path(err : AssetCopyError) -> String {
  match err {
    SourceReadError(path, _) => path
    SourceNotDirectory(path) => path
    DestCreateError(path, _) => path
    FileReadError(path, _) => path
    FileWriteError(path, _) => path
  }
}

pub fn format_error(err : AssetCopyError) -> String {
  match err {
    SourceReadError(path, msg) => "cannot read static assets source " + path + ": " + msg
    SourceNotDirectory(path) => "static assets path exists but is not a directory: " + path
    DestCreateError(path, msg) => "cannot create static asset directory " + path + ": " + msg
    FileReadError(path, msg) => "cannot read static asset file " + path + ": " + msg
    FileWriteError(path, msg) => "cannot write static asset file " + path + ": " + msg
  }
}

///|
/// Validate static assets readability without writing output files.
pub fn check_static(site_root : String, static_dir : String) -> AssetValidation {
  let errors : Array[AssetCopyError] = []
  let source_root = join_path(site_root, static_dir)

  if not(@fs.path_exists(source_root)) {
    return { errors, }
  }

  let is_source_dir = try {
    @fs.is_dir(source_root)
  } catch {
    @fs.IOError(msg) => {
      errors.push(SourceReadError(source_root, msg))
      return { errors, }
    }
  }
  if not(is_source_dir) {
    errors.push(SourceNotDirectory(source_root))
    return { errors, }
  }

  validate_tree(source_root, errors)
  { errors, }
}

///|
/// Copy `site_root/static_dir` to `output_dir/static_dir`.
///
/// Returns the number of files copied. Missing source directory is a no-op.
pub fn copy_static(
  site_root : String,
  output_dir : String,
  static_dir : String
) -> Result[Int, AssetCopyError] {
  let source_root = join_path(site_root, static_dir)
  if not(@fs.path_exists(source_root)) {
    return Ok(0)
  }

  let source_is_dir = try {
    @fs.is_dir(source_root)
  } catch {
    @fs.IOError(msg) => return Err(SourceReadError(source_root, msg))
  }
  if not(source_is_dir) {
    return Err(SourceNotDirectory(source_root))
  }

  let dest_root = join_path(output_dir, static_dir)
  copy_tree(source_root, dest_root)
}
