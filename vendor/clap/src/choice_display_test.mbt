// Golden diagnostic text captured before the warning migration.
///|
test "choice diagnostics preserve pre-migration text" {
  let parser = @clap.Parser::new(args={
    "color": @clap.Arg::named(choices=@hashset.HashSet(["red", "blue"])),
  })
  let value = @clap.SimpleValue::new("PROG")
  try parser.parse(value, ["--color", "green"]) catch {
    err => assert_eq(err.to_string(), "InvalidArgumentValue(Invalid argument value for PROG => color, value=green, choices=@hashset.from_array([red, blue]))")
  } noraise {
    _ => fail("expected invalid choice")
  }
  let parser = @clap.Parser::new(args={
    "color": @clap.Arg::named(choices=@hashset.HashSet(["red", "blue"]), defaults=["green"]),
  })
  let value = @clap.SimpleValue::new("PROG")
  try parser.parse(value, []) catch {
    err => assert_eq(err.to_string(), "InvalidSpec(Invalid argument, name=color, default value=green not in choices=@hashset.from_array([red, blue]))")
  } noraise {
    _ => fail("expected invalid default")
  }
}
