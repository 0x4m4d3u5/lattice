///|
/// Stub implementations for WASM targets.
/// Node and native have separate socket adapters. These stubs satisfy the
/// type-checker for standalone WASM without a host socket integration.

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
