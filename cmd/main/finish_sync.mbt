///|
// Preserve the synchronous CLI exit behavior on non-JavaScript targets.
fn finish_once(code : Int32) -> Unit {
  @sys.exit(code)
}
