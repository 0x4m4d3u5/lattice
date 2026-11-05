///|
test "complete ranges shift before edits and invalidate overlapping edits" {
  let ranges = [(0, 2, 5), (1, 5, 8), (2, -1, -1)]
  shift_passages(ranges, 0, 2, 4)
  assert_eq(ranges, [(0, 4, 7), (1, 7, 10), (2, -1, -1)])
  // Insertion at the start shifts, at the end leaves the earlier range intact.
  shift_passages(ranges, 7, 7, 2)
  assert_eq(ranges, [(0, 4, 7), (1, 9, 12), (2, -1, -1)])
  shift_passages(ranges, 5, 6, 0)
  assert_eq(ranges, [(0, -1, -1), (1, 8, 11), (2, -1, -1)])
  shift_passages(ranges, 8, 11, 3)
  assert_eq(ranges, [(0, -1, -1), (1, -1, -1), (2, -1, -1)])
}

///|
test "literal replacements track each edit without rediscovering origin by text" {
  let ranges = [(0, 1, 4), (1, 5, 8), (2, 9, 12)]
  assert_eq(
    replace_passages("XabcXabcXabc", "X", "🌱", ranges),
    "🌱abc🌱abc🌱abc",
  )
  assert_eq(ranges, [(0, 2, 5), (1, 7, 10), (2, 12, 15)])
  let inside = [(0, 0, 5), (1, 5, 8)]
  assert_eq(replace_passages("abXcdEND", "X", "", inside), "abcdEND")
  assert_eq(inside, [(0, -1, -1), (1, 4, 7)])
}
