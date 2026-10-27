///|
fn staged_publication_supported() -> Bool {
  false
}

///|
fn stage_output(_path : String, _bytes : Bytes) -> String raise @fs.IOError {
  raise @fs.IOError("staged publication is unavailable on this backend")
}

///|
fn replace_output(_staged : String, _target : String) -> Unit raise @fs.IOError {
  raise @fs.IOError("staged publication is unavailable on this backend")
}

///|
fn discard_output(_staged : String) -> String {
  ""
}
