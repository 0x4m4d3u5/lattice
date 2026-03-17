///|
/// Stub implementations for non-native targets (JS, WASM).
/// The dev server requires OS-level sockets, so it is only available
/// when compiled to native. These stubs satisfy the type-checker.

///|
pub fn start(_port : Int, _root : String) -> Bool {
  false
}

///|
pub fn broadcast_reload() -> Unit {
  ()
}

///|
pub fn stop() -> Unit {
  ()
}

///|
pub fn is_running() -> Bool {
  false
}
