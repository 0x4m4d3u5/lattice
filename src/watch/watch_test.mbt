// diff_paths: merge-comparison of two sorted SnapshotEntry arrays

///|
test "diff_paths both empty" {
  let prev : Array[@watch.SnapshotEntry] = []
  let curr : Array[@watch.SnapshotEntry] = []
  assert_eq(@watch.diff_paths(prev, curr), [])
}

///|
test "diff_paths identical single entry" {
  let entry : @watch.SnapshotEntry = { path: "a.md", stamp: 42L }
  assert_eq(@watch.diff_paths([entry], [entry]), [])
}

///|
test "diff_paths identical multiple entries" {
  let prev : Array[@watch.SnapshotEntry] = [
    { path: "a.md", stamp: 1L },
    { path: "b.md", stamp: 2L },
    { path: "c.md", stamp: 3L },
  ]
  assert_eq(@watch.diff_paths(prev, prev), [])
}

///|
test "diff_paths stamp changed" {
  let prev : Array[@watch.SnapshotEntry] = [{ path: "a.md", stamp: 1L }]
  let curr : Array[@watch.SnapshotEntry] = [{ path: "a.md", stamp: 2L }]
  assert_eq(@watch.diff_paths(prev, curr), ["a.md"])
}

///|
test "diff_paths file added" {
  let prev : Array[@watch.SnapshotEntry] = [{ path: "a.md", stamp: 1L }]
  let curr : Array[@watch.SnapshotEntry] = [
    { path: "a.md", stamp: 1L },
    { path: "b.md", stamp: 5L },
  ]
  assert_eq(@watch.diff_paths(prev, curr), ["b.md"])
}

///|
test "diff_paths file removed" {
  let prev : Array[@watch.SnapshotEntry] = [
    { path: "a.md", stamp: 1L },
    { path: "b.md", stamp: 2L },
  ]
  let curr : Array[@watch.SnapshotEntry] = [{ path: "a.md", stamp: 1L }]
  assert_eq(@watch.diff_paths(prev, curr), ["b.md"])
}

///|
test "diff_paths prev longer trailing" {
  let prev : Array[@watch.SnapshotEntry] = [
    { path: "a.md", stamp: 1L },
    { path: "b.md", stamp: 2L },
    { path: "c.md", stamp: 3L },
  ]
  let curr : Array[@watch.SnapshotEntry] = [{ path: "a.md", stamp: 1L }]
  assert_eq(@watch.diff_paths(prev, curr), ["b.md", "c.md"])
}

///|
test "diff_paths curr longer trailing" {
  let prev : Array[@watch.SnapshotEntry] = [{ path: "a.md", stamp: 1L }]
  let curr : Array[@watch.SnapshotEntry] = [
    { path: "a.md", stamp: 1L },
    { path: "b.md", stamp: 10L },
    { path: "c.md", stamp: 20L },
  ]
  assert_eq(@watch.diff_paths(prev, curr), ["b.md", "c.md"])
}

///|
test "diff_paths mixed add remove modify" {
  // prev: a(stamp=1), b(stamp=2), d(stamp=4)
  // curr: a(stamp=99), c(stamp=3), d(stamp=4)
  // a: stamp changed → changed; b: removed → changed; c: added → changed; d: unchanged
  let prev : Array[@watch.SnapshotEntry] = [
    { path: "a", stamp: 1L },
    { path: "b", stamp: 2L },
    { path: "d", stamp: 4L },
  ]
  let curr : Array[@watch.SnapshotEntry] = [
    { path: "a", stamp: 99L },
    { path: "c", stamp: 3L },
    { path: "d", stamp: 4L },
  ]
  assert_eq(@watch.diff_paths(prev, curr), ["a", "b", "c"])
}

///|
test "diff_paths prev empty curr nonempty" {
  let prev : Array[@watch.SnapshotEntry] = []
  let curr : Array[@watch.SnapshotEntry] = [
    { path: "new.md", stamp: 7L },
    { path: "other.md", stamp: 8L },
  ]
  assert_eq(@watch.diff_paths(prev, curr), ["new.md", "other.md"])
}

///|
test "diff_paths prev nonempty curr empty" {
  let prev : Array[@watch.SnapshotEntry] = [{ path: "solo.md", stamp: 3L }]
  let curr : Array[@watch.SnapshotEntry] = []
  assert_eq(@watch.diff_paths(prev, curr), ["solo.md"])
}

///|
test "diff_paths no false positives on zero stamp" {
  // stamp=0 is a valid unchanged stamp; should not be flagged
  let prev : Array[@watch.SnapshotEntry] = [{ path: "dir/", stamp: 0L }]
  let curr : Array[@watch.SnapshotEntry] = [{ path: "dir/", stamp: 0L }]
  assert_eq(@watch.diff_paths(prev, curr), [])
}

// unix_days_to_ymd: Howard Hinnant civil_from_days algorithm
// Days counted from Unix epoch (1970-01-01 = day 0).

///|
test "unix_days_to_ymd epoch" {
  assert_eq(@watch.unix_days_to_ymd(0), "1970-01-01")
}

///|
test "unix_days_to_ymd day before epoch" {
  // Day -1 = 1969-12-31
  assert_eq(@watch.unix_days_to_ymd(-1), "1969-12-31")
}

///|
test "unix_days_to_ymd last day of 1970" {
  // 1970 has 365 days; day 0 = Jan 1, day 364 = Dec 31
  assert_eq(@watch.unix_days_to_ymd(364), "1970-12-31")
}

///|
test "unix_days_to_ymd first day of 1971" {
  // 1970 is not a leap year; day 365 = 1971-01-01
  assert_eq(@watch.unix_days_to_ymd(365), "1971-01-01")
}

///|
test "unix_days_to_ymd first day of 1972" {
  // 1970(365d) + 1971(365d) = 730 days; day 730 = 1972-01-01
  assert_eq(@watch.unix_days_to_ymd(730), "1972-01-01")
}

///|
test "unix_days_to_ymd leap day 1972" {
  // day 730 = 1972-01-01; Jan(31) → day 761 = 1972-02-01; +28 → day 789 = 1972-02-29
  assert_eq(@watch.unix_days_to_ymd(789), "1972-02-29")
}

///|
test "unix_days_to_ymd year 2000 january first" {
  // 1970-1999: 30 years, 7 leap years (1972,76,80,84,88,92,96) = 23×365 + 7×366 = 10957
  assert_eq(@watch.unix_days_to_ymd(10957), "2000-01-01")
}

///|
test "unix_days_to_ymd year 2000 is a leap year" {
  // 2000 divisible by 400 → leap; Feb 29: day 10957+31+28 = 11016
  assert_eq(@watch.unix_days_to_ymd(11016), "2000-02-29")
}

///|
test "unix_days_to_ymd today 2026-04-26" {
  // 1970-2025: 56 years, 14 leap years (1972..2024 every 4) = 42×365 + 14×366 = 20454
  // 2026-01-01 = day 20454; Jan(31)+Feb(28)+Mar(31) = 90 → Apr 1 = day 20544; +25 → day 20569
  assert_eq(@watch.unix_days_to_ymd(20569), "2026-04-26")
}

///|
test "unix_days_to_ymd march first non-leap 1973" {
  // 1972-01-01 = day 730; 1972 leap (366d) → 1973-01-01 = day 1096
  // Jan(31) → day 1127; Feb(28) → 1973-03-01 = day 1155
  assert_eq(@watch.unix_days_to_ymd(1155), "1973-03-01")
}

// ymd_pad2: zero-pads to 2 digits

///|
test "ymd_pad2 zero" {
  assert_eq(@watch.ymd_pad2(0), "00")
}

///|
test "ymd_pad2 single digit" {
  assert_eq(@watch.ymd_pad2(1), "01")
}

///|
test "ymd_pad2 nine" {
  assert_eq(@watch.ymd_pad2(9), "09")
}

///|
test "ymd_pad2 boundary ten" {
  assert_eq(@watch.ymd_pad2(10), "10")
}

///|
test "ymd_pad2 double digit" {
  assert_eq(@watch.ymd_pad2(12), "12")
}

// ymd_pad4: zero-pads to 4 digits

///|
test "ymd_pad4 four digits no padding" {
  assert_eq(@watch.ymd_pad4(2026), "2026")
}

///|
test "ymd_pad4 three digits" {
  assert_eq(@watch.ymd_pad4(999), "0999")
}

///|
test "ymd_pad4 two digits" {
  assert_eq(@watch.ymd_pad4(42), "0042")
}

///|
test "ymd_pad4 one digit" {
  assert_eq(@watch.ymd_pad4(1), "0001")
}

///|
test "ymd_pad4 five digits no truncation" {
  assert_eq(@watch.ymd_pad4(12345), "12345")
}
