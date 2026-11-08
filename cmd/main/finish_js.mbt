///|
// One-shot commands return after setting their status. Node must finish pending
// stdout/stderr writes before exiting; process.exit truncates asynchronous pipes.
// Do not use this for fatal watcher exits with a live server worker.
extern "js" fn finish_once(code : Int32) -> Unit =
  #| function(code) {
  #|   process.exitCode = code;
  #| }
