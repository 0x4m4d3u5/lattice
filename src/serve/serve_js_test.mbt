///|
// Retry a small number of ephemeral-range candidates rather than reserve a
// fixed port shared by concurrent test jobs. start() owns the successful bind.
extern "js" fn candidate_port_js() -> Int =
  #| function() { return 49152 + Math.floor(Math.random() * 16384); }

///|
test "Node serve API stops, restarts and reports running state" {
  @serve.stop()
  let initially_stopped = !@serve.is_running()
  let mut port = 0
  let mut started = false
  for _ in 0..<8 {
    port = candidate_port_js()
    if @serve.start(port, "./_tmp_serve_api_lifecycle") {
      started = true
      break
    }
  }
  let running = @serve.is_running()
  let duplicate_start = @serve.start(port, "./_tmp_serve_api_lifecycle")
  @serve.broadcast_reload()
  @serve.stop()
  let stopped = !@serve.is_running()
  @serve.stop()
  let stopped_again = !@serve.is_running()
  let restarted = @serve.start(port, "./_tmp_serve_api_lifecycle")
  let running_again = @serve.is_running()
  @serve.stop()
  let finally_stopped = !@serve.is_running()
  // Assert only after cleanup so a failure cannot leave a worker alive.
  assert_true(initially_stopped)
  assert_true(started)
  assert_true(running)
  assert_false(duplicate_start)
  assert_true(stopped)
  assert_true(stopped_again)
  assert_true(restarted)
  assert_true(running_again)
  assert_true(finally_stopped)
}
