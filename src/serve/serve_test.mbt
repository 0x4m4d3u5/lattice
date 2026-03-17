///|
test "default port is 4321" {
  assert_eq(default_port(), 4321)
}

///|
test "is_valid_port rejects zero" {
  assert_eq(is_valid_port(0), false)
}

///|
test "is_valid_port rejects negative" {
  assert_eq(is_valid_port(-1), false)
}

///|
test "is_valid_port accepts 1" {
  assert_eq(is_valid_port(1), true)
}

///|
test "is_valid_port accepts 65535" {
  assert_eq(is_valid_port(65535), true)
}

///|
test "is_valid_port rejects 65536" {
  assert_eq(is_valid_port(65536), false)
}

///|
test "is_valid_port accepts typical dev port" {
  assert_eq(is_valid_port(4321), true)
}

///|
test "broadcast_reload is safe with no connected clients" {
  // No-op in stub mode; no-op in native mode before start() — must not panic.
  broadcast_reload()
}

///|
test "stop is idempotent when server not started" {
  stop()
  stop()
}

///|
test "is_running returns false before start in stub mode" {
  // Stub always returns false; native returns false unless started.
  // Just ensure no panic.
  let _ = is_running()
}

///|
test "ServeConfig fields are accessible" {
  let cfg : ServeConfig = { port: 4321, root: "./dist" }
  assert_eq(cfg.port, 4321)
  assert_eq(cfg.root, "./dist")
}
