///|
fn count_messages_with_prefix(messages : Array[String], prefix : String) -> Int {
  let mut count = 0
  let mut i = 0
  while i < messages.length() {
    if messages[i].has_prefix(prefix) {
      count = count + 1
    }
    i = i + 1
  }
  count
}

///|
test "build result messages contain progress header" {
  let root = "./_tmp_builder_messages_header"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)
  assert_true(
    write_file_test(
      posts_root + "/alpha.md",
      "---\ntitle: Alpha\ndate: 2026-01-01\n---\nBody.\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body>{{content}}</body></html>\n",
    ),
  )
  let site_cfg = "title = MsgTest\nbase_url = https://example.test\ntemplates_dir = " +
    templates_root +
    "\ndata_dir = " +
    data_root +
    "\ncollections_file = " +
    root +
    "/collections.cfg\noutput_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))
  assert_true(
    write_file_test(
      root + "/collections.cfg",
      "[posts]\nschema = title:String,date:Date\ndir = " + posts_root + "\n",
    ),
  )
  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: Some(root + "/collections.cfg"),
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)
  // messages array must be non-empty and contain the build header
  assert_true(result.messages.length() > 0)
  assert_eq(count_messages_with_prefix(result.messages, "[lattice] building"), 1)
  // exactly one [build] progress entry — one post was built
  assert_eq(count_messages_with_prefix(result.messages, "[build]"), 1)
  // no [skip] entries on a forced full rebuild
  assert_eq(count_messages_with_prefix(result.messages, "[skip]"), 0)
}

///|
test "incremental build skips each page exactly once — no doubled [skip] messages" {
  let root = "./_tmp_builder_incremental_skip_dedup"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)
  assert_true(
    write_file_test(
      posts_root + "/post-one.md",
      "---\ntitle: Post One\ndate: 2026-02-01\n---\nFirst.\n",
    ),
  )
  assert_true(
    write_file_test(
      posts_root + "/post-two.md",
      "---\ntitle: Post Two\ndate: 2026-02-02\n---\nSecond.\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body>{{content}}</body></html>\n",
    ),
  )
  let site_cfg = "title = IncrTest\nbase_url = https://example.test\ntemplates_dir = " +
    templates_root +
    "\ndata_dir = " +
    data_root +
    "\ncollections_file = " +
    root +
    "/collections.cfg\noutput_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))
  assert_true(
    write_file_test(
      root + "/collections.cfg",
      "[posts]\nschema = title:String,date:Date\ndir = " + posts_root + "\n",
    ),
  )
  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let build_config : @builder.BuildConfig = {
    content_dir: content_root,
    output_dir: output_root,
    config_path: root + "/site.cfg",
    site,
    collections_path: Some(root + "/collections.cfg"),
    force_rebuild: true,
    include_drafts: false,
  }
  // First build: full rebuild — both posts get [build] messages
  let result1 = @builder.build(build_config, @cache.empty(output_root))
  assert_eq(result1.errors, 0)
  assert_eq(count_messages_with_prefix(result1.messages, "[build]"), 2)
  assert_eq(count_messages_with_prefix(result1.messages, "[skip]"), 0)

  // Second build: incremental — load the cache written by the first build
  let cache2 = match @cache.load(output_root) {
    Ok(c) => c
    Err(_) => @cache.empty(output_root)
  }
  let incr_config : @builder.BuildConfig = {
    content_dir: content_root,
    output_dir: output_root,
    config_path: root + "/site.cfg",
    site,
    collections_path: Some(root + "/collections.cfg"),
    force_rebuild: false,
    include_drafts: false,
  }
  let result2 = @builder.build(incr_config, cache2)
  assert_eq(result2.errors, 0)
  // Regression test for commit 11c246a: each page must appear exactly once
  // in the [skip] stream, not twice.
  assert_eq(count_messages_with_prefix(result2.messages, "[skip]"), 2)
  assert_eq(count_messages_with_prefix(result2.messages, "[build]"), 0)
  assert_eq(result2.unchanged_pages, 2)
  assert_eq(result2.rebuilt_pages, 0)
}
