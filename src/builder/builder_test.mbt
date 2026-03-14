///|
fn ensure_dir_test(path : String) -> Unit {
  if not(@fs.path_exists(path)) {
    @fs.create_dir(path) catch {
      @fs.IOError(_) => ()
    }
  }
}

///|
fn write_file_test(path : String, content : String) -> Bool {
  try {
    @fs.write_string_to_file(path, content)
    true
  } catch {
    @fs.IOError(_) => false
  }
}

///|
test "collection index lookup alias uses numeric prefix directory basename" {
  let collection : @collections.CollectionDef = {
    name: "projects",
    schema: { name: "projects", fields: [] },
    content_dir: "/vault/10 - Projects",
    template: None,
  }
  match @builder.collection_index_lookup_alias(collection) {
    Some(lookup_key) => assert_eq(lookup_key, "10---projects")
    None => assert_true(false)
  }
}

///|
test "collection index lookup alias skips matching directory names" {
  let collection : @collections.CollectionDef = {
    name: "posts",
    schema: { name: "posts", fields: [] },
    content_dir: "/vault/posts",
    template: None,
  }
  match @builder.collection_index_lookup_alias(collection) {
    Some(_) => assert_true(false)
    None => ()
  }
}

///|
test "collection index lookup alias skips basename that normalizes to collection name" {
  let collection : @collections.CollectionDef = {
    name: "posts",
    schema: { name: "posts", fields: [] },
    content_dir: "/vault/Posts",
    template: None,
  }
  match @builder.collection_index_lookup_alias(collection) {
    Some(_) => assert_true(false)
    None => ()
  }
}

///|
test "build uses per-collection page template override" {
  let root = "./_tmp_builder_collection_template"
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
      posts_root + "/hello.md",
      "---\n" +
      "title: Hello\n" +
      "date: 2026-03-11\n" +
      "---\n\n" +
      "Hello override\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body>default {{content}}</body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/post.html",
      "<html><body>override {{content}}</body></html>\n",
    ),
  )
  let site_cfg = "title = Test\n" +
    "base_url = /\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "collections_file = " +
    root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))
  assert_true(
    write_file_test(
      root + "/collections.cfg",
      "[posts]\n" +
      "schema = title:String,date:Date\n" +
      "dir = " +
      posts_root +
      "\n" +
      "template = " +
      templates_root +
      "/post.html\n",
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

  let output = @fs.read_file_to_string(output_root + "/posts/hello/index.html") catch {
    @fs.IOError(_) => ""
  }
  assert_true(output.contains("override"))
  assert_true(not(output.contains("default")))
}
