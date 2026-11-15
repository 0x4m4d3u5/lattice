///|
fn private_audience_fixture(name : String) -> @builder.BuildConfig raise {
  let base = public_audience_fixture("private_" + name)
  { ..base, site: @config.parse(@fs.read_file_to_string(base.config_path) + "static_allowlist = []\ncontent_index_file = content-index.json\n").unwrap() }
}

///|
test "private export requires fresh output explicit assets and content index" {
  let config = private_audience_fixture("requirements")
  assert_true(@builder.build(config, @cache.empty(config.output_dir), audience=Some(@builder.Private)).errors > 0)
  assert_false(@builder.inventory(config, audience=Some(@builder.Private)).ready)
  for text in ["static_allowlist = []\n", "content_index_file = content-index.json\n"] {
    let config = { ..config, site: @config.parse(@fs.read_file_to_string(config.config_path) + text).unwrap() }
    assert_true(@builder.build(config, @cache.empty(config.output_dir), fresh_output=true, audience=Some(@builder.Private)).errors > 0)
    assert_false(@builder.inventory(config, fresh_output=true, audience=Some(@builder.Private)).ready)
    assert_true(@builder.check(config, audience=Some(@builder.Private)).violations.length() > 0)
    assert_false(@fs.path_exists(config.output_dir))
  }
}

///|
test "private export selects all declared audiences but leaves defaults protected" {
  let config = private_audience_fixture("sources")
  for (path, visibility, body) in [
    ("posts/alpha.md", "private", "PRIVATE_COLLECTION_CANARY"),
    ("posts/beta.md", "public", "PUBLIC_COLLECTION_TEXT"),
    ("standalone/about.md", "private", "PRIVATE_STANDALONE_CANARY"),
    ("index.md", "", "UNLABELLED_ROOT_CANARY"),
    ("404.md", "private", "PRIVATE_404_CANARY [[beta]] [beta](posts/beta/)"),
  ] { @fs.write_string_to_file(config.content_dir + "/" + path, public_audience_source(visibility, body)) }
  let before = publication_snapshot(config.content_dir)
  assert_eq(@builder.check(config, audience=Some(@builder.Private)).violations.length(), 0)
  assert_true(@builder.inventory(config, fresh_output=true, audience=Some(@builder.Private)).ready)
  assert_false(@fs.path_exists(config.output_dir))
  assert_eq(@builder.build(config, @cache.empty(config.output_dir), fresh_output=true, audience=Some(@builder.Private)).errors, 0)
  let private_before = publication_snapshot(config.output_dir)
  assert_true(@fs.read_file_to_string(config.output_dir + "/content-index.json").contains("PRIVATE_COLLECTION_CANARY"))
  assert_true(@fs.read_file_to_string(config.output_dir + "/404.html").contains("PRIVATE_404_CANARY"))
  assert_false(@fs.path_exists(config.output_dir + "/.lattice-cache"))
  assert_false(@fs.path_exists(config.output_dir + "/.lattice-manifest.json"))
  assert_false(@builder.inventory(config, fresh_output=true, audience=Some(@builder.Public)).ready)
  let public = { ..config, output_dir: config.output_dir + "-public" }
  assert_eq(@builder.build(public, @cache.empty(public.output_dir), fresh_output=true, audience=Some(@builder.Public)).errors, 0)
  for file in publication_snapshot(public.output_dir) {
    if file.bytes is Some(bytes) {
      let content = @utf8.decode_lossy(bytes)
      assert_false(content.contains("PRIVATE_"))
      assert_false(content.contains("UNLABELLED_"))
    }
  }
  let ordinary = { ..config, output_dir: config.output_dir + "-ordinary" }
  assert_true(@builder.build(ordinary, @cache.empty(ordinary.output_dir), fresh_output=true).errors > 0)
  assert_false(@fs.path_exists(ordinary.output_dir))
  assert_eq(publication_snapshot(config.content_dir), before)
  assert_eq(publication_snapshot(config.output_dir), private_before)
}

///|
test "private export retains draft readiness separately including 404" {
  for include_drafts in [false, true] {
    let base = private_audience_fixture("draft_" + include_drafts.to_string())
    let config = { ..base, include_drafts }
    for path in ["posts/alpha.md", "404.md"] {
      @fs.write_string_to_file(config.content_dir + "/" + path, public_audience_source("private", "PRIVATE_DRAFT_CANARY", draft=true))
    }
    assert_eq(@builder.build(config, @cache.empty(config.output_dir), fresh_output=true, audience=Some(@builder.Private)).errors, 0)
    assert_eq(@fs.path_exists(config.output_dir + "/posts/alpha/index.html"), include_drafts)
    assert_eq(@fs.read_file_to_string(config.output_dir + "/404.html").contains("PRIVATE_DRAFT_CANARY"), include_drafts)
    assert_eq(@fs.read_file_to_string(config.output_dir + "/content-index.json").contains("PRIVATE_DRAFT_CANARY"), include_drafts)
  }
}

///|
test "private export fails closed malformed visibility even hidden or custom 404" {
  for path in ["posts/alpha.md", "404.md"] {
    for source in [
      public_audience_source("true", "CANARY", draft=true),
      public_audience_source("PRIVATE", "CANARY", draft=true),
      "---\ntitle: Bad\nvisibility: private\n'visibility': public\n---\nCANARY",
      "---\ntitle: Bad\nvisibility: private\nbroken frontmatter\n---\nCANARY",
    ] {
      let config = private_audience_fixture("invalid")
      @fs.write_string_to_file(config.content_dir + "/" + path, source)
      assert_true(@builder.check(config, audience=Some(@builder.Private)).violations.length() > 0)
      assert_false(@builder.inventory(config, fresh_output=true, audience=Some(@builder.Private)).ready)
      assert_true(@builder.build(config, @cache.empty(config.output_dir), fresh_output=true, audience=Some(@builder.Private)).errors > 0)
      assert_false(@fs.path_exists(config.output_dir))
    }
  }
}

///|
test "private export audits wiki local links and 404 images before writes" {
  for path in ["posts/alpha.md", "404.md"] {
    for body in ["[[absent]]", "[missing](/absent/)", "![missing](/static/absent.png)", "![[absent.png]]"] {
      let config = private_audience_fixture("links")
      @fs.write_string_to_file(config.content_dir + "/" + path, public_audience_source("private", body))
      assert_false(@builder.inventory(config, fresh_output=true, audience=Some(@builder.Private)).ready)
      assert_true(@builder.build(config, @cache.empty(config.output_dir), fresh_output=true, audience=Some(@builder.Private)).errors > 0)
      assert_false(@fs.path_exists(config.output_dir))
    }
  }
}

///|
test "private export refuses overwritten content index" {
  for name in ["graph.json", "404.html", "search-index.json", "posts/alpha/index.html"] {
    let base = private_audience_fixture("index_ownership")
    let config = { ..base, site: @config.parse(@fs.read_file_to_string(base.config_path) + "static_allowlist = []\ncontent_index_file = " + name + "\n").unwrap() }
    assert_false(@builder.inventory(config, fresh_output=true, audience=Some(@builder.Private)).ready)
    let result = @builder.build(config, @cache.empty(config.output_dir), fresh_output=true, audience=Some(@builder.Private))
    assert_true(result.diagnostics.any(d => d.message.contains("content index collides")))
    assert_false(@fs.path_exists(config.output_dir))
  }
}
