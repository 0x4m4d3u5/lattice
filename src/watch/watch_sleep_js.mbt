///|
// The pinned core/env has no sleep helper. Node permits Atomics.wait on its
// main thread, matching this CLI's synchronous polling loop without busy work.
// The private buffer is never shared, so only the timeout can wake this wait.
extern "js" fn sleep_ms_js(ms : Int) -> Unit =
  #| function(ms) {
  #|   Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
  #| }

///|
pub fn sleep_ms(ms : Int) -> Unit {
  if ms <= 0 {
    return
  }
  sleep_ms_js(ms)
}
