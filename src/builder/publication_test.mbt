///|
/// Record directories as well as bytes, including hidden cache/manifest files.
/// A failed build must not even leave newly prepared, empty directories behind.
priv struct PublicationSnapshotEntry {
  path : String
  bytes : Bytes?
} derive(Eq, Debug)

///|
fn publication_snapshot_walk(
  root : String,
  relative : String,
  entries : Array[PublicationSnapshotEntry],
) -> Unit raise @fs.IOError {
  let path = if relative == "" { root } else { root + "/" + relative }
  if @fs.is_dir(path) {
    entries.push({ path: relative, bytes: None, })
    let children = @fs.read_dir(path).to_owned()
    children.sort()
    for child in children {
      let next = if relative == "" { child } else { relative + "/" + child }
      publication_snapshot_walk(root, next, entries)
    }
  } else {
    entries.push({ path: relative, bytes: Some(@fs.read_file_to_bytes(path)), })
  }
}

///|
fn publication_snapshot(
  root : String,
) -> Array[PublicationSnapshotEntry] raise @fs.IOError {
  let entries : Array[PublicationSnapshotEntry] = []
  publication_snapshot_walk(root, "", entries)
  entries
}

///|
/// Never reuse a previous run's fixture or remove anything outside this test.
fn publication_fresh_root(name : String) -> String raise @fs.IOError {
  let prefix = "./_tmp_builder_publication_" + name + "_"
  let mut suffix = 0
  while @fs.path_exists(prefix + suffix.to_string()) {
    suffix = suffix + 1
  }
  let root = prefix + suffix.to_string()
  @fs.create_dir(root)
  root
}

///|
fn publication_fixture(name : String) -> @builder.BuildConfig raise {
  let root = publication_fresh_root(name)
  let content = root + "/content"
  for
    path in [
      content,
      content + "/posts",
      content + "/standalone",
      content + "/data",
      content + "/static",
      content + "/static/images",
      root + "/templates",
    ] {
    @fs.create_dir(path)
  }
  @fs.write_string_to_file(
    content + "/posts/alpha.md",
    "---\ntitle: Alpha\ndate: 2026-01-02\n---\nOriginal alpha.\n",
  )
  @fs.write_string_to_file(
    content + "/posts/beta.md",
    "---\ntitle: Beta\ndate: 2026-02-03\n---\nOriginal beta.\n",
  )
  @fs.write_string_to_file(
    content + "/index.md",
    "---\ntitle: Home\n---\nOriginal home.\n",
  )
  @fs.write_string_to_file(
    content + "/standalone/about.md",
    "---\ntitle: About\n---\nOriginal about.\n",
  )
  @fs.write_string_to_file(
    content + "/404.md",
    "---\ntitle: Not Found\n---\nOriginal not found.\n",
  )
  @fs.write_bytes_to_file(
    content + "/static/images/pixel.bin",
    Bytes::from_array([0, 128, 255, 13, 10]),
  )
  @fs.write_string_to_file(
    root + "/templates/page.html",
    "<html><head><title>{{title}}</title></head><body>{{content}}</body></html>\n",
  )
  @fs.write_string_to_file(
    root + "/templates/archive.html",
    "<html><body><h1>{{title}}</h1>{{content}}</body></html>\n",
  )
  @fs.write_string_to_file(
    root + "/collections.cfg",
    "[posts]\nschema = title:String,date:Date\ndir = " + content + "/posts\n",
  )
  let site_cfg = "title = Publication Test\nbase_url = https://example.test\n" +
    "templates_dir = " +
    root +
    "/templates\n" +
    "data_dir = " +
    content +
    "/data\n" +
    "collections_file = " +
    root +
    "/collections.cfg\n" +
    "output_dir = " +
    root +
    "/dist\narchive_pages = true\n"
  @fs.write_string_to_file(root + "/site.cfg", site_cfg)
  let site = match @config.parse(site_cfg) {
    Ok(site) => site
    Err(_) => abort("publication fixture has invalid site configuration")
  }
  {
    content_dir: content,
    output_dir: root + "/dist",
    config_path: root + "/site.cfg",
    site,
    collections_path: Some(root + "/collections.cfg"),
    force_rebuild: true,
    include_drafts: false,
  }
}

///|
fn publication_incremental(
  config : @builder.BuildConfig,
) -> @builder.BuildConfig {
  {
    content_dir: config.content_dir,
    output_dir: config.output_dir,
    config_path: config.config_path,
    site: config.site,
    collections_path: config.collections_path,
    force_rebuild: false,
    include_drafts: config.include_drafts,
  }
}

///|
fn publication_load_cache(config : @builder.BuildConfig) -> @cache.CacheStore {
  match @cache.load(config.output_dir) {
    Ok(cache) => cache
    Err(_) => abort("publication fixture cache could not be loaded")
  }
}

///|
fn publication_seed_success(config : @builder.BuildConfig) -> Unit raise {
  assert_true(!@fs.path_exists(config.output_dir))
  let result = @builder.build(config, @cache.empty(config.output_dir))
  assert_eq(result.errors, 0)
  for
    relative in [
      "index.html", "about/index.html", "posts/alpha/index.html", "posts/beta/index.html",
      "posts/2026/01/index.html", "posts/archive/index.html", "404.html", "static/images/pixel.bin",
      ".lattice-cache", ".lattice-manifest.json",
    ] {
    assert_true(@fs.path_exists(config.output_dir + "/" + relative))
  }
  assert_eq(
    @fs.read_file_to_bytes(config.output_dir + "/static/images/pixel.bin"),
    Bytes::from_array([0, 128, 255, 13, 10]),
  )
  // Unmanaged files and empty directories are part of the preserved tree too.
  @fs.create_dir(config.output_dir + "/keep-empty")
  @fs.write_bytes_to_file(
    config.output_dir + "/keep.bin",
    Bytes::from_array([255, 0, 254]),
  )
}

///|
fn publication_change_valid_inputs(
  config : @builder.BuildConfig,
) -> Unit raise @fs.IOError {
  let content = config.content_dir
  @fs.write_string_to_file(
    content + "/posts/alpha.md",
    "---\ntitle: Alpha Changed\ndate: 2026-03-04\n---\nChanged alpha body.\n",
  )
  @fs.write_string_to_file(
    content + "/posts/brand-new.md",
    "---\ntitle: Brand New\ndate: 2026-04-05\n---\nNew collection page.\n",
  )
  @fs.write_string_to_file(
    content + "/index.md",
    "---\ntitle: Home Changed\n---\nChanged home body.\n",
  )
  @fs.write_string_to_file(
    content + "/standalone/about.md",
    "---\ntitle: About Changed\n---\nChanged about body.\n",
  )
  @fs.write_bytes_to_file(
    content + "/static/images/pixel.bin",
    Bytes::from_array([254, 0, 129, 10, 255, 1]),
  )
  @fs.create_dir(content + "/static/new-assets")
  @fs.write_bytes_to_file(
    content + "/static/new-assets/new.bin",
    Bytes::from_array([0, 255, 128, 2]),
  )
}

///|
fn publication_assert_failed(result : @builder.BuildResult) -> Unit raise {
  assert_true(result.errors > 0)
  assert_true(@diagnostic.count_errors(result.diagnostics) > 0)
  assert_eq(result.rebuilt_pages, 0)
  assert_eq(result.redirect_count, 0)
  assert_eq(count_messages_with_prefix(result.messages, "[build]"), 0)
  assert_eq(count_messages_with_prefix(result.messages, "[lattice] wrote "), 0)
  assert_eq(count_messages_with_prefix(result.messages, "[lattice] copied "), 0)
}

///|
test "failed publication preserves every byte and directory for root standalone and collection errors" {
  for invalid_page in ["index.md", "standalone/about.md", "posts/beta.md"] {
    let config = publication_fixture("validation")
    publication_seed_success(config)
    let before = publication_snapshot(config.output_dir)
    let cache = publication_load_cache(config)
    let cache_before = @cache.render_store(cache)
    publication_change_valid_inputs(config)
    @fs.write_string_to_file(
      config.content_dir + "/" + invalid_page,
      "---\ndescription: Missing required title\n---\nInvalid replacement.\n",
    )
    let result = @builder.build(publication_incremental(config), cache)
    publication_assert_failed(result)
    assert_true(
      result.diagnostics.iter().any(fn(d) { d.message.contains("title") }),
    )
    assert_eq(publication_snapshot(config.output_dir), before)
    assert_eq(@cache.render_store(cache), cache_before)
  }
}

///|
test "invalid initial root standalone and collection builds create no output directory" {
  for invalid_page in ["index.md", "standalone/about.md", "posts/beta.md"] {
    let config = publication_fixture("initial")
    @fs.write_string_to_file(
      config.content_dir + "/" + invalid_page,
      "---\ndescription: Missing required title\n---\nInvalid initial page.\n",
    )
    assert_true(!@fs.path_exists(config.output_dir))
    publication_assert_failed(
      @builder.build(config, @cache.empty(config.output_dir)),
    )
    assert_true(!@fs.path_exists(config.output_dir))
  }
}

///|
test "late custom 404 render failure preserves pages binary assets cache and manifest" {
  let config = publication_fixture("404")
  publication_seed_success(config)
  let before = publication_snapshot(config.output_dir)
  publication_change_valid_inputs(config)
  @fs.write_string_to_file(
    config.content_dir + "/404.md",
    "---\ntitle: Broken Not Found\n---\n{{< unknown value=1 >}}\n",
  )
  let result = @builder.build(config, publication_load_cache(config))
  publication_assert_failed(result)
  assert_true(
    result.diagnostics
    .iter()
    .any(fn(d) { d.message.contains("404") && d.message.contains("shortcode") }),
  )
  assert_eq(publication_snapshot(config.output_dir), before)
}

///|
test "archive template render failure is fatal and preserves the complete previous output" {
  let config = publication_fixture("archive")
  publication_seed_success(config)
  let before = publication_snapshot(config.output_dir)
  publication_change_valid_inputs(config)
  let templates_dir = match config.site.templates_dir {
    Some(path) => path
    None => abort("publication fixture must have templates")
  }
  // This parses successfully, then fails during archive rendering only.
  @fs.write_string_to_file(
    templates_dir + "/archive.html",
    "<html>{{content}}{{data.missing.value}}</html>\n",
  )
  let result = @builder.build(config, publication_load_cache(config))
  publication_assert_failed(result)
  assert_true(
    result.diagnostics.iter().any(fn(d) { d.message.contains("archive") }),
  )
  assert_eq(publication_snapshot(config.output_dir), before)
}

///|
test "repair after failed publication publishes new bytes and keeps incremental cache reusable" {
  let config = publication_fixture("recovery")
  publication_seed_success(config)
  let before = publication_snapshot(config.output_dir)
  let old_cache = publication_load_cache(config)
  let old_alpha_fingerprint = @cache.lookup(old_cache, "alpha")
  publication_change_valid_inputs(config)
  @fs.write_string_to_file(
    config.content_dir + "/404.md",
    "---\ntitle: Broken Not Found\n---\n{{< unknown value=1 >}}\n",
  )
  let incremental = publication_incremental(config)
  publication_assert_failed(@builder.build(incremental, old_cache))
  assert_eq(publication_snapshot(config.output_dir), before)
  @fs.write_string_to_file(
    config.content_dir + "/404.md",
    "---\ntitle: Repaired Not Found\n---\nRepaired not found body.\n",
  )
  let repaired = @builder.build(incremental, publication_load_cache(config))
  assert_eq(repaired.errors, 0)
  assert_true(repaired.rebuilt_pages > 0)
  assert_true(
    @fs.read_file_to_string(config.output_dir + "/posts/alpha/index.html").contains(
      "Changed alpha body",
    ),
  )
  assert_true(
    @fs.read_file_to_string(config.output_dir + "/404.html").contains(
      "Repaired not found body",
    ),
  )
  assert_true(
    @fs.path_exists(config.output_dir + "/posts/brand-new/index.html"),
  )
  assert_eq(
    @fs.read_file_to_bytes(config.output_dir + "/static/images/pixel.bin"),
    Bytes::from_array([254, 0, 129, 10, 255, 1]),
  )
  assert_eq(
    @fs.read_file_to_bytes(config.output_dir + "/static/new-assets/new.bin"),
    Bytes::from_array([0, 255, 128, 2]),
  )
  let repaired_cache = publication_load_cache(config)
  assert_true(@cache.lookup(repaired_cache, "alpha") != old_alpha_fingerprint)
  let next = @builder.build(incremental, repaired_cache)
  assert_eq(next.errors, 0)
  assert_eq(next.unchanged_pages, 3)
  assert_eq(count_messages_with_prefix(next.messages, "[skip]"), 3)
  assert_eq(count_messages_with_prefix(next.messages, "[build] posts/"), 0)
}

///|
test "metadata destination directory conflict is detected before any output is published" {
  for metadata in [".lattice-cache", ".lattice-manifest.json"] {
    let config = publication_fixture("metadata_conflict")
    @fs.create_dir(config.output_dir)
    @fs.create_dir(config.output_dir + "/" + metadata)
    @fs.write_bytes_to_file(
      config.output_dir + "/" + metadata + "/keep.bin",
      Bytes::from_array([255, 0, 128]),
    )
    let before = publication_snapshot(config.output_dir)
    publication_assert_failed(
      @builder.build(config, @cache.empty(config.output_dir)),
    )
    assert_eq(publication_snapshot(config.output_dir), before)
  }
}

///|
test "nested static destination file conflict preserves the successful output tree" {
  let config = publication_fixture("nested_conflict")
  publication_seed_success(config)
  @fs.write_bytes_to_file(
    config.output_dir + "/static/new-assets",
    Bytes::from_array([255, 0, 128]),
  )
  let before = publication_snapshot(config.output_dir)
  publication_change_valid_inputs(config)
  publication_assert_failed(
    @builder.build(config, publication_load_cache(config)),
  )
  assert_eq(publication_snapshot(config.output_dir), before)
}
