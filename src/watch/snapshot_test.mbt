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

///|
test "normalized output exclusions preserve sibling inputs and directory membership" {
  let prefix = "_tmp_watch_excluded_"
  let mut suffix = 0
  while @fs.path_exists(prefix + suffix.to_string()) {
    suffix = suffix + 1
  }
  let root = prefix + suffix.to_string()
  @fs.create_dir(root)
  @fs.create_dir(root + "/generated-notes")
  @fs.write_string_to_file(root + "/generated-notes/keep.md", "Sibling input")
  let excluded = ["./" + root + "/unused/../generated/"]
  let before = @watch.take_snapshot([root], excluded_dirs=excluded)
  @fs.create_dir(root + "/generated")
  @fs.write_string_to_file(root + "/generated/index.html", "Output")
  let created = @watch.take_snapshot([root], excluded_dirs=excluded)
  assert_eq(@watch.diff_paths(before, created), [])
  @fs.write_string_to_file(root + "/generated/index.html", "Rewritten output")
  assert_eq(
    @watch.diff_paths(
      created,
      @watch.take_snapshot([root], excluded_dirs=excluded),
    ),
    [],
  )
  @fs.write_string_to_file(
    root + "/generated-notes/new.md",
    "New sibling input",
  )
  let sibling = @watch.take_snapshot([root], excluded_dirs=excluded)
  assert_eq(@watch.diff_paths(created, sibling), [
    root + "/generated-notes/new.md",
  ])
  @fs.remove_file(root + "/generated/index.html")
  @fs.remove_dir(root + "/generated")
  assert_eq(
    @watch.diff_paths(
      sibling,
      @watch.take_snapshot([root], excluded_dirs=excluded),
    ),
    [],
  )
  assert_true(@watch.path_contains(root, "./" + root + "/child/../generated"))
  assert_true(@watch.path_contains("./" + root + "/", root))
  let absolute_root = @path.Path(root).resolve().normalize().to_string()
  assert_true(@watch.path_contains(absolute_root, "./" + root + "/child"))
  assert_true(@watch.path_contains(root, absolute_root + "/child"))
  assert_false(
    @watch.path_contains(root + "/generated", root + "/generated-notes"),
  )
  assert_false(
    @watch.path_contains(root + "/generated", root + "/generated/../input"),
  )
}

///|
test "missing empty directory and file transitions remain observable" {
  let prefix = "_tmp_watch_types_"
  let mut suffix = 0
  while @fs.path_exists(prefix + suffix.to_string()) {
    suffix = suffix + 1
  }
  let root = prefix + suffix.to_string()
  @fs.create_dir(root)
  let path = root + "/entry"
  let missing = @watch.take_snapshot([path])
  @fs.create_dir(path)
  let directory = @watch.take_snapshot([path])
  assert_eq(@watch.diff_paths(missing, directory), [path])
  @fs.remove_dir(path)
  assert_eq(@watch.diff_paths(directory, @watch.take_snapshot([path])), [path])
  @fs.write_string_to_file(path, "File replacing directory")
  let file = @watch.take_snapshot([path])
  assert_eq(@watch.diff_paths(directory, file), [path])
  @fs.remove_file(path)
  @fs.create_dir(path)
  assert_eq(@watch.diff_paths(file, @watch.take_snapshot([path])), [path])
}
