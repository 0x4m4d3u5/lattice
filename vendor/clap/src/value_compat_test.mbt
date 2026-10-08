///|
test "numeric argument parsing preserves signed and unsigned boundaries" {
  let value = @clap.SimpleValue::new("synthetic")
  value.args["int"] = ["-2147483648"]
  value.args["uint"] = ["4294967295"]
  value.args["int64"] = ["-9223372036854775808"]
  value.args["uint64"] = ["18446744073709551615"]
  value.args["double"] = ["3.5"]
  let signed : Int = value.get_one("int")
  let unsigned : UInt = value.get_one("uint")
  let signed64 : Int64 = value.get_one("int64")
  let unsigned64 : UInt64 = value.get_one("uint64")
  let decimal : Double = value.get_one("double")
  assert_eq(signed, -2147483648)
  assert_eq(unsigned, 4294967295U)
  assert_eq(signed64, -9223372036854775808L)
  assert_eq(unsigned64, 18446744073709551615UL)
  assert_eq(decimal, 3.5)
}

///|
test "invalid numeric arguments remain InvalidArgumentValue errors" {
  let value = @clap.SimpleValue::new("synthetic")
  value.args["overflow"] = ["2147483648"]
  value.args["negative"] = ["-1"]
  let signed : Result[Int, @clap.ParserError] = try? value.get_one("overflow")
  let unsigned : Result[UInt, @clap.ParserError] = try? value.get_one("negative")
  assert_true(signed.is_err())
  assert_true(unsigned.is_err())
  assert_true(signed.unwrap_err().to_string().contains("InvalidArgumentValue"))
  assert_true(unsigned.unwrap_err().to_string().contains("InvalidArgumentValue"))
}
