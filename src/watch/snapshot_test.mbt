///|
test "shallow sources and overlapping dependencies produce ordered unique snapshots" {
  let prefix = "_tmp_watch_sources_"
  let mut suffix = 0
  while @fs.path_exists(prefix + suffix.to_string()) {
    suffix = suffix + 1
  }
  let root = prefix + suffix.to_string()
  @fs.create_dir(root)
  @fs.create_dir(root + "/nested")
  @fs.write_string_to_file(root + "/a.MD", "Root Markdown")
  @fs.write_string_to_file(root + "/ignore.txt", "Not a source")
  @fs.write_string_to_file(root + "/nested/file.md", "Nested source")
  let shallow = @watch.take_snapshot(
    [],
    source_dirs=[root, root + "/missing"],
  )
  assert_eq(shallow.map(entry => entry.path), [root + "/a.MD"])
  let combined = @watch.take_snapshot(
    [root + "/nested", root, root + "/a.MD"],
    source_dirs=[root, root],
  )
  // String comparison is shortlex in the pinned core, as used by diff_paths.
  assert_eq(
    combined.map(entry => entry.path),
    [
      root,
      root + "/a.MD",
      root + "/nested",
      root + "/ignore.txt",
      root + "/nested/file.md",
    ],
  )
  @fs.write_string_to_file(root + "/b.md", "New source")
  let added = @watch.take_snapshot([], source_dirs=[root])
  assert_eq(@watch.diff_paths(shallow, added), [root + "/b.md"])
  @fs.remove_file(root + "/a.MD")
  let removed = @watch.take_snapshot([], source_dirs=[root])
  assert_eq(@watch.diff_paths(added, removed), [root + "/a.MD"])
}
