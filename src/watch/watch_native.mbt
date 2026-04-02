///|
#borrow(path)
extern "C" fn watch_mtime_millis_ffi(path : Bytes) -> Int64 = "lattice_watch_mtime_millis"

///|
extern "C" fn watch_sleep_ms_ffi(ms : Int) -> Unit = "lattice_watch_sleep_ms"

///|
extern "C" fn watch_install_sigint_handler_ffi() -> Unit = "lattice_watch_install_sigint_handler"

///|
extern "C" fn watch_interrupted_ffi() -> Int = "lattice_watch_interrupted"

///|
extern "C" fn watch_clear_interrupt_ffi() -> Unit = "lattice_watch_clear_interrupt"

///|
extern "C" fn watch_current_unix_second_ffi() -> Int64 = "lattice_watch_current_unix_second"

///|
extern "C" fn watch_current_millis_ffi() -> Int64 = "lattice_watch_current_millis"

///|
fn string_to_utf8_bytes_watch(str : String, is_filename : Bool) -> Bytes {
  let res : Array[Byte] = []
  let len = str.length()
  let mut i = 0
  while i < len {
    let mut c = str.code_unit_at(i).to_int()
    if c >= 0xD800 && c <= 0xDBFF {
      c = c - 0xD800
      i = i + 1
      let low = str.code_unit_at(i).to_int() - 0xDC00
      c = (c << 10) + low + 0x10000
    }
    if c < 0x80 {
      res.push(c.to_byte())
    } else if c < 0x800 {
      res.push((0xC0 + (c >> 6)).to_byte())
      res.push((0x80 + (c & 0x3F)).to_byte())
    } else if c < 0x10000 {
      res.push((0xE0 + (c >> 12)).to_byte())
      res.push((0x80 + ((c >> 6) & 0x3F)).to_byte())
      res.push((0x80 + (c & 0x3F)).to_byte())
    } else {
      res.push((0xF0 + (c >> 18)).to_byte())
      res.push((0x80 + ((c >> 12) & 0x3F)).to_byte())
      res.push((0x80 + ((c >> 6) & 0x3F)).to_byte())
      res.push((0x80 + (c & 0x3F)).to_byte())
    }
    i = i + 1
  }
  if is_filename {
    res.push((0).to_byte())
  }
  Bytes::from_array(res)
}

///|
fn mtime_millis_internal(path : String) -> Int64 {
  watch_mtime_millis_ffi(string_to_utf8_bytes_watch(path, true))
}

///|
pub fn sleep_ms(ms : Int) -> Unit {
  watch_sleep_ms_ffi(ms)
}

///|
pub fn install_sigint_handler() -> Unit {
  watch_install_sigint_handler_ffi()
}

///|
pub fn interrupted() -> Bool {
  watch_interrupted_ffi() != 0
}

///|
pub fn clear_interrupt() -> Unit {
  watch_clear_interrupt_ffi()
}

///|
pub fn current_unix_second() -> Int64 {
  watch_current_unix_second_ffi()
}

///|
/// Return current wall-clock time in milliseconds since Unix epoch.
/// Used for build timing and performance measurement.
pub fn current_millis() -> Int64 {
  watch_current_millis_ffi()
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
