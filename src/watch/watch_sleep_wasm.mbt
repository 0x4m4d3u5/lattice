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
