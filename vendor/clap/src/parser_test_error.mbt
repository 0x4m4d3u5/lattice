///|
test "named argument length exceeded" {
  let parser = Parser::new(args={
    "arg1": Arg::named(short='a', nargs=Fixed(2), help="Argument 1"),
  })
  let value = SimpleValue::new(parser.prog)
  try parser.parse(value, ["--arg1", "v1", "v2", "v3"]) catch {
    err => assert_true(err.to_string().contains("TooManyArgs"))
  } noraise {
    _ => fail("expected too many arguments to raise")
  }
}

///|
test "flag argument duplicated" {
  let parser = Parser::new(args={
    "arg1": Arg::flag(short='a', help="Argument 1"),
  })
  let value = SimpleValue::new(parser.prog)
  try parser.parse(value, ["--arg1", "--arg1"]) catch {
    err =>
      assert_true(
        err.to_string().contains("Invalid flag argument length: 2 > 1"),
      )
  } noraise {
    _ => fail("expected duplicate flag to raise")
  }
}
