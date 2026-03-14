///|
fn hash_bytes_watch(bytes : Bytes) -> Int64 {
  let mut hash = 1469598103934665603L
  let mut i = 0
  while i < bytes.length() {
    hash = hash ^ bytes[i].to_int().to_int64()
    hash = hash * 1099511628211L
    i = i + 1
  }
  hash
}

///|
fn mtime_millis_internal(path : String) -> Int64 {
  if not(@fs.path_exists(path)) {
    return -1L
  }
  let is_dir = @fs.is_dir(path) catch { @fs.IOError(_) => return -1L }
  if is_dir {
    return 0L
  }
  let bytes = @fs.read_file_to_bytes(path) catch {
    @fs.IOError(_) => return -1L
  }
  hash_bytes_watch(bytes)
}

///|
pub fn sleep_ms(ms : Int) -> Unit {
  if ms <= 0 {
    return
  }
  let start = @env.now()
  let duration = ms.to_uint64()
  while @env.now() - start < duration {
    ()
  }
}

///|
pub fn install_sigint_handler() -> Unit {
  ()
}

///|
pub fn interrupted() -> Bool {
  false
}

///|
pub fn clear_interrupt() -> Unit {
  ()
}

///|
pub fn current_unix_second() -> Int64 {
  (@env.now() / 1000UL).reinterpret_as_int64()
}
