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
  if !@fs.path_exists(path) {
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

///|
/// Return current wall-clock time in milliseconds since Unix epoch.
/// Used for build timing and performance measurement.
pub fn current_millis() -> Int64 {
  @env.now().reinterpret_as_int64()
}

///|
/// Return today's date as YYYY-MM-DD using the system clock (UTC).
/// Uses Howard Hinnant's civil_from_days algorithm applied to current_unix_second().
pub fn today_ymd() -> String {
  let secs = current_unix_second()
  let days = (secs / 86400L).to_int()
  unix_days_to_ymd(days)
}

///|
/// Convert days-since-Unix-epoch (1970-01-01) to YYYY-MM-DD using
/// Howard Hinnant's civil_from_days algorithm.
fn unix_days_to_ymd(days : Int) -> String {
  let z = days + 719468
  let era = if z >= 0 { z / 146097 } else { (z - 146096) / 146097 }
  let doe = z - era * 146097
  let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
  let y = yoe + era * 400
  let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
  let mp = (5 * doy + 2) / 153
  let d = doy - (153 * mp + 2) / 5 + 1
  let m = if mp < 10 { mp + 3 } else { mp - 9 }
  let year = if m <= 2 { y + 1 } else { y }
  pad4_ymd(year) + "-" + pad2_ymd(m) + "-" + pad2_ymd(d)
}

///|
fn pad2_ymd(n : Int) -> String {
  if n < 10 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

///|
fn pad4_ymd(n : Int) -> String {
  let s = n.to_string()
  if s.length() >= 4 {
    s
  } else {
    let buf = StringBuilder::new()
    let mut i = s.length()
    while i < 4 {
      buf.write_char('0')
      i = i + 1
    }
    buf.write_string(s)
    buf.to_string()
  }
}
