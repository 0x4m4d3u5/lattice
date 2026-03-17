///|
/// Start the HTTP dev server on the given port, serving files from root.
/// Returns true on success, false if the port is already in use or root is invalid.
#borrow(root)
extern "C" fn serve_start_ffi(port : Int, root : Bytes) -> Int = "lattice_serve_start"

///|
/// Push a Server-Sent Event reload signal to all connected browser clients.
extern "C" fn serve_broadcast_reload_ffi() -> Unit = "lattice_serve_broadcast_reload"

///|
/// Stop the HTTP dev server and release resources.
extern "C" fn serve_stop_ffi() -> Unit = "lattice_serve_stop"

///|
/// Returns true if the server is currently running.
extern "C" fn serve_is_running_ffi() -> Int = "lattice_serve_is_running"

///|
fn string_to_utf8_serve(s : String) -> Bytes {
  let res : Array[Byte] = []
  let len = s.length()
  let mut i = 0
  while i < len {
    let mut c = s.code_unit_at(i).to_int()
    if c >= 0xD800 && c <= 0xDBFF {
      c = c - 0xD800
      i = i + 1
      let low = s.code_unit_at(i).to_int() - 0xDC00
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
  res.push((0).to_byte())
  Bytes::from_array(res)
}

///|
pub fn start(port : Int, root : String) -> Bool {
  serve_start_ffi(port, string_to_utf8_serve(root)) != 0
}

///|
pub fn broadcast_reload() -> Unit {
  serve_broadcast_reload_ffi()
}

///|
pub fn stop() -> Unit {
  serve_stop_ffi()
}

///|
pub fn is_running() -> Bool {
  serve_is_running_ffi() != 0
}
