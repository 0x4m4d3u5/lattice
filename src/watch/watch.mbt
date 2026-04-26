///|
pub(all) struct SnapshotEntry {
  path : String
  stamp : Int64
}

///|
pub(all) suberror WatchError {
  IOError(String)
}

///|
fn file_mtime_millis(path : String) -> Int64 {
  mtime_millis_internal(path)
}

///|
pub fn file_stamp(path : String) -> Int64 {
  file_mtime_millis(path)
}

///|
fn collect_snapshot_entries(
  path : String,
  entries : Array[SnapshotEntry],
) -> Unit raise WatchError {
  entries.push({ path, stamp: file_mtime_millis(path) })
  if !@fs.path_exists(path) {
    return
  }
  let is_dir = @fs.is_dir(path) catch {
    @fs.IOError(msg) => raise IOError("cannot stat " + path + ": " + msg)
  }
  if !is_dir {
    return
  }
  let children = @fs.read_dir(path) catch {
    @fs.IOError(msg) =>
      raise IOError("cannot read directory " + path + ": " + msg)
  }
  children.sort()
  let mut i = 0
  while i < children.length() {
    collect_snapshot_entries(path + "/" + children[i], entries)
    i = i + 1
  }
}

///|
pub fn take_snapshot(
  paths : Array[String],
) -> Array[SnapshotEntry] raise WatchError {
  let roots : Array[String] = []
  let mut i = 0
  while i < paths.length() {
    roots.push(paths[i])
    i = i + 1
  }
  roots.sort()
  let deduped : Array[String] = []
  i = 0
  while i < roots.length() {
    if i == 0 || roots[i] != roots[i - 1] {
      deduped.push(roots[i])
    }
    i = i + 1
  }
  let entries : Array[SnapshotEntry] = []
  i = 0
  while i < deduped.length() {
    collect_snapshot_entries(deduped[i], entries)
    i = i + 1
  }
  entries
}

///|
/// Convert days-since-Unix-epoch (1970-01-01) to YYYY-MM-DD using
/// Howard Hinnant's civil_from_days algorithm.
pub fn unix_days_to_ymd(days : Int) -> String {
  let z = days + 719468
  let era = if z >= 0 { z / 146097 } else { (z - 146096) / 146097 }
  let doe = z - era * 146097
  let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
  let y = yoe + era * 400
  let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
  let mp = (5 * doy + 2) / 153
  let d = doy - (153 * mp + 2) / 5 + 1
  let m = if mp < 10 { mp + 3 } else { mp - 9 }
  let year = if m <= 2 { y + 1 } else { y }
  ymd_pad4(year) + "-" + ymd_pad2(m) + "-" + ymd_pad2(d)
}

///|
pub fn ymd_pad2(n : Int) -> String {
  if n < 10 {
    "0" + n.to_string()
  } else {
    n.to_string()
  }
}

///|
pub fn ymd_pad4(n : Int) -> String {
  let s = n.to_string()
  if s.length() >= 4 {
    s
  } else {
    let buf = StringBuilder::new()
    let mut i = s.length()
    while i < 4 {
      buf.write_char('0')
      i = i + 1
    }
    buf.write_string(s)
    buf.to_string()
  }
}

///|
pub fn diff_paths(
  previous : Array[SnapshotEntry],
  current : Array[SnapshotEntry],
) -> Array[String] {
  let changed : Array[String] = []
  let mut i = 0
  let mut j = 0
  while i < previous.length() && j < current.length() {
    let left = previous[i]
    let right = current[j]
    if left.path == right.path {
      if left.stamp != right.stamp {
        changed.push(right.path)
      }
      i = i + 1
      j = j + 1
    } else if left.path < right.path {
      changed.push(left.path)
      i = i + 1
    } else {
      changed.push(right.path)
      j = j + 1
    }
  }
  while i < previous.length() {
    changed.push(previous[i].path)
    i = i + 1
  }
  while j < current.length() {
    changed.push(current[j].path)
    j = j + 1
  }
  changed
}
