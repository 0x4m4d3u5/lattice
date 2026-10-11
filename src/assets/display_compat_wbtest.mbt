///|
test "asset validation display preserves errors and order" {
  let validation = AssetValidation::{errors: [SourceReadError("first", "bad"), FileWriteError("second", "no") ]}
  assert_eq(Show::to_string(validation), "{errors: [SourceReadError(first, bad), FileWriteError(second, no)]}")
  assert_eq(Show::to_string(AssetValidation::{errors: []}), "{errors: []}")
}
