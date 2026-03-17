///|
/// lattice dev server — HTTP file serving + SSE live-reload.
///
/// Architecture:
///   A background thread listens for HTTP connections on a configurable port.
///   Static files are served from the output directory. When an HTML file is
///   served, a small <script> tag is injected that opens a Server-Sent Events
///   connection to `/__lattice_reload`. When `broadcast_reload` is called from
///   the main (watch) thread after a rebuild, an SSE event is pushed to every
///   connected browser tab, triggering `location.reload()`.
///
/// The native implementation lives in serve_native.c (pthreads + POSIX sockets).
/// serve_stub.mbt provides no-op fallbacks for JS/WASM targets.

///|
pub(all) struct ServeConfig {
  port : Int
  root : String
}

///|
pub fn default_port() -> Int {
  4321
}

///|
/// Validate that port is in the usable range 1..65535.
pub fn is_valid_port(port : Int) -> Bool {
  port >= 1 && port <= 65535
}
