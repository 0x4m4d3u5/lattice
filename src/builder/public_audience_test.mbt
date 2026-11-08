///|
fn public_audience_fixture(name : String) -> @builder.BuildConfig raise {
  let config = publication_fixture("audience_" + name)
  { ..config, site: @config.parse(@fs.read_file_to_string(config.config_path) + "static_allowlist = []\n").unwrap(), }
}

///|
fn public_audience_source(visibility : String, body : String, draft? : Bool = false) -> String {
  "---\ntitle: Audience page\ndate: 2026-01-02\n" +
  (if visibility == "" { "" } else { "visibility: " + visibility + "\n" }) +
  (if draft { "draft: true\n" } else { "" }) + "---\n" + body + "\n"
}

///|
test "public audience requires both explicit fresh output and static allowlist" {
  let config = public_audience_fixture("requirements")
  let ordinary = @builder.build(config, @cache.empty(config.output_dir), audience=Some(@builder.Audience::Public))
  assert_true(ordinary.errors > 0)
  assert_false(@builder.inventory(config, audience=Some(@builder.Audience::Public)).ready)
  let no_allowlist = { ..config, site: @config.parse(@fs.read_file_to_string(config.config_path)).unwrap(), }
  assert_true(@builder.build(no_allowlist, @cache.empty(config.output_dir), fresh_output=true, audience=Some(@builder.Audience::Public)).errors > 0)
  assert_false(@builder.inventory(no_allowlist, fresh_output=true, audience=Some(@builder.Audience::Public)).ready)
  assert_true(@builder.check(no_allowlist, audience=Some(@builder.Audience::Public)).violations.length() > 0)
  assert_false(@fs.path_exists(config.output_dir))
  assert_true(@builder.inventory(config, fresh_output=true, audience=Some(@builder.Audience::Public)).ready)
}

///|
test "public audience excludes private and missing visibility across source kinds" {
  let config = public_audience_fixture("source_kinds")
  for (path, visibility, sentinel) in [
    ("posts/alpha.md", "public", "PUBLIC_COLLECTION_SENTINEL"),
    ("posts/beta.md", "private", "PRIVATE_COLLECTION_SENTINEL"),
    ("standalone/about.md", "public", "PUBLIC_STANDALONE_SENTINEL"),
    ("standalone/secret.md", "private", "PRIVATE_STANDALONE_SENTINEL"),
    ("index.md", "public", "PUBLIC_ROOT_SENTINEL"),
    ("unlabelled.md", "", "UNLABELLED_ROOT_SENTINEL"),
    ("404.md", "private", "PRIVATE_404_SENTINEL"),
  ] {
    @fs.write_string_to_file(config.content_dir + "/" + path, public_audience_source(visibility, sentinel))
  }
  let before = publication_snapshot(config.content_dir)
  let inventory = @builder.inventory(config, fresh_output=true, audience=Some(@builder.Audience::Public))
  assert_true(inventory.ready)
  for path in ["posts/beta.md", "standalone/secret.md", "404.md"] {
    assert_true(inventory.entries.any(entry => entry.source == Some(config.content_dir + "/" + path) && entry.status == "excluded" && entry.reason.contains("private")))
  }
  assert_true(inventory.entries.any(entry => entry.source == Some(config.content_dir + "/unlabelled.md") && entry.status == "excluded" && entry.reason.contains("missing")))
  assert_eq(@builder.check(config, audience=Some(@builder.Audience::Public)).violations.length(), 0)
  assert_false(@fs.path_exists(config.output_dir))
  let result = @builder.build(config, @cache.empty(config.output_dir), fresh_output=true, audience=Some(@builder.Audience::Public))
  assert_eq(result.errors, 0)
  assert_true(@fs.read_file_to_string(config.output_dir + "/posts/alpha/index.html").contains("PUBLIC_COLLECTION_SENTINEL"))
  assert_true(@fs.read_file_to_string(config.output_dir + "/about/index.html").contains("PUBLIC_STANDALONE_SENTINEL"))
  assert_true(@fs.read_file_to_string(config.output_dir + "/index.html").contains("PUBLIC_ROOT_SENTINEL"))
  for file in publication_snapshot(config.output_dir) {
    if file.bytes is Some(bytes) {
      let content = @utf8.decode_lossy(bytes)
      assert_false(content.contains("PRIVATE_"))
      assert_false(content.contains("UNLABELLED_"))
    }
  }
  assert_eq(publication_snapshot(config.content_dir), before)
}

///|
test "public audience draft readiness cannot grant private publication" {
  for include_drafts in [false, true] {
    let base = public_audience_fixture("drafts_" + include_drafts.to_string())
    let config = { ..base, include_drafts, }
    @fs.write_string_to_file(config.content_dir + "/posts/alpha.md", public_audience_source("public", "PUBLIC_DRAFT_SENTINEL", draft=true))
    @fs.write_string_to_file(config.content_dir + "/posts/beta.md", public_audience_source("private", "PRIVATE_DRAFT_SENTINEL", draft=true))
    assert_eq(@builder.build(config, @cache.empty(config.output_dir), fresh_output=true, audience=Some(@builder.Audience::Public)).errors, 0)
    assert_eq(@fs.path_exists(config.output_dir + "/posts/alpha/index.html"), include_drafts)
    assert_false(@fs.path_exists(config.output_dir + "/posts/beta/index.html"))
    for file in publication_snapshot(config.output_dir) {
      if file.bytes is Some(bytes) { assert_false(@utf8.decode_lossy(bytes).contains("PRIVATE_DRAFT_SENTINEL")) }
    }
  }
}

///|
test "public audience validates excluded frontmatter before selection" {
  for index, source in [
    public_audience_source("true", "INVALID"),
    public_audience_source("PRIVATE", "INVALID"),
    "---\nvisibility: private\nvisibility: public\n---\nINVALID\n",
    "---\nvisibility: private\ntitle without separator\n---\nINVALID\n",
  ] {
    let config = public_audience_fixture("invalid_" + index.to_string())
    @fs.write_string_to_file(config.content_dir + "/posts/alpha.md", source)
    assert_false(@builder.inventory(config, fresh_output=true, audience=Some(@builder.Audience::Public)).ready)
    assert_true(@builder.check(config, audience=Some(@builder.Audience::Public)).violations.length() > 0)
    assert_true(@builder.build(config, @cache.empty(config.output_dir), fresh_output=true, audience=Some(@builder.Audience::Public)).errors > 0)
    assert_false(@fs.path_exists(config.output_dir))
  }
}

///|
test "private collection slug cannot suppress public root discovery" {
  let config = public_audience_fixture("root_discovery")
  @fs.write_string_to_file(config.content_dir + "/posts/alpha.md", public_audience_source("private", "PRIVATE_COLLISION_SENTINEL"))
  @fs.write_string_to_file(config.content_dir + "/alpha.md", public_audience_source("public", "PUBLIC_ROOT_COLLISION_SENTINEL"))
  assert_true(@builder.inventory(config, fresh_output=true, audience=Some(@builder.Audience::Public)).ready)
  assert_eq(@builder.check(config, audience=Some(@builder.Audience::Public)).violations.length(), 0)
  assert_eq(@builder.build(config, @cache.empty(config.output_dir), fresh_output=true, audience=Some(@builder.Audience::Public)).errors, 0)
  assert_true(@fs.read_file_to_string(config.output_dir + "/alpha/index.html").contains("PUBLIC_ROOT_COLLISION_SENTINEL"))
  assert_false(@fs.path_exists(config.output_dir + "/posts/alpha/index.html"))
}

///|
test "public audience mandates wiki and ordinary local Markdown checks" {
  for index, body in ["[[does-not-exist]]", "[missing](/does-not-exist/)"] {
    let config = public_audience_fixture("mandatory_links_" + index.to_string())
    @fs.write_string_to_file(config.content_dir + "/posts/alpha.md", public_audience_source("public", body))
    assert_false(@builder.inventory(config, fresh_output=true, audience=Some(@builder.Audience::Public)).ready)
    assert_true(@builder.check(config, audience=Some(@builder.Audience::Public)).violations.length() > 0)
    assert_true(@builder.build(config, @cache.empty(config.output_dir), fresh_output=true, audience=Some(@builder.Audience::Public), strict_wikilinks=false, strict_local_links=false).errors > 0)
    assert_false(@fs.path_exists(config.output_dir))
  }
}

///|
test "public audience checks selected 404 at its actual route" {
  let config = public_audience_fixture("public_404")
  @fs.write_string_to_file(config.content_dir + "/posts/alpha.md", public_audience_source("public", "# Public destination\nDestination."))
  @fs.write_string_to_file(config.content_dir + "/404.md", public_audience_source("public", "PUBLIC_404_SENTINEL [destination](posts/alpha/)"))
  assert_true(@builder.inventory(config, fresh_output=true, audience=Some(@builder.Audience::Public)).ready)
  assert_eq(@builder.check(config, audience=Some(@builder.Audience::Public)).violations.length(), 0)
  assert_eq(@builder.build(config, @cache.empty(config.output_dir), fresh_output=true, audience=Some(@builder.Audience::Public)).errors, 0)
  assert_true(@fs.read_file_to_string(config.output_dir + "/404.html").contains("PUBLIC_404_SENTINEL"))
}

///|
test "public 404 broken links block but excluded 404 embeds never enter planning" {
  for index, body in ["[[missing]]", "[missing](missing/)"] {
    let config = public_audience_fixture("broken_404_" + index.to_string())
    @fs.write_string_to_file(config.content_dir + "/404.md", public_audience_source("public", body))
    assert_false(@builder.inventory(config, fresh_output=true, audience=Some(@builder.Audience::Public)).ready)
  }
  for index, visibility in ["private", ""] {
    let config = public_audience_fixture("excluded_404_" + index.to_string())
    @fs.write_string_to_file(config.content_dir + "/404.md", public_audience_source(visibility, "PRIVATE_404_EMBED ![[missing.png]] [[missing]] [missing](missing/)"))
    assert_true(@builder.inventory(config, fresh_output=true, audience=Some(@builder.Audience::Public)).ready)
    assert_eq(@builder.build(config, @cache.empty(config.output_dir), fresh_output=true, audience=Some(@builder.Audience::Public)).errors, 0)
    assert_false(@fs.read_file_to_string(config.output_dir + "/404.html").contains("PRIVATE_404_EMBED"))
  }
}

///|
test "public audience denies excluded alias and redirect identities despite public collisions" {
  for index, reference in ["[[Secret Name]]", "[secret](/old-secret/)"] {
    let base = public_audience_fixture("denied_collision_" + index.to_string())
    let config = { ..base, site: @config.parse(@fs.read_file_to_string(base.config_path) + "static_allowlist = []\nwikilink_aliases = true\n").unwrap(), }
    @fs.write_string_to_file(config.content_dir + "/posts/alpha.md", "---\ntitle: Public\ndate: 2026-01-02\nvisibility: public\naliases: [Secret Name]\nredirect_from: [/old-secret/]\n---\n" + reference + "\n")
    @fs.write_string_to_file(config.content_dir + "/posts/beta.md", "---\ntitle: Private\ndate: 2026-01-02\nvisibility: private\naliases: [Secret Name]\nredirect_from: [/old-secret/]\n---\nPRIVATE_BODY\n")
    assert_false(@builder.inventory(config, fresh_output=true, audience=Some(@builder.Audience::Public)).ready)
    assert_true(@builder.build(config, @cache.empty(config.output_dir), fresh_output=true, audience=Some(@builder.Audience::Public)).errors > 0)
    assert_false(@fs.path_exists(config.output_dir))
  }
}

///|
test "public check uses nonpublishing fresh destination rules" {
  let config = public_audience_fixture("check_fresh")
  assert_eq(@builder.check(config, audience=Some(@builder.Audience::Public)).violations.length(), 0)
  assert_false(@fs.path_exists(config.output_dir))
  @fs.create_dir(config.output_dir)
  assert_true(@builder.check(config, audience=Some(@builder.Audience::Public)).violations.length() > 0)
  let overlap = { ..config, output_dir: config.content_dir + "/new-output", }
  assert_true(@builder.check(overlap, audience=Some(@builder.Audience::Public)).violations.length() > 0)
  assert_false(@fs.path_exists(overlap.output_dir))
}

///|
test "omitted and explicit none audience retain legacy source compatibility" {
  let config = publication_fixture("audience_legacy")
  assert_true(@builder.inventory(config).ready)
  assert_true(@builder.inventory_with_fragments(config, audience=None).0.ready)
  assert_eq(@builder.check(config, audience=None).violations.length(), 0)
  assert_eq(@builder.build(config, @cache.empty(config.output_dir), audience=None).errors, 0)
  assert_true(@fs.read_file_to_string(config.output_dir + "/posts/alpha/index.html").contains("Original alpha"))
}

///|
test "public audience denies excluded homepage even when generated home exists" {
  for index, reference in ["[[index]]", "[home](/)"] {
    let config = public_audience_fixture("excluded_home_" + index.to_string())
    @fs.write_string_to_file(config.content_dir + "/index.md", public_audience_source("private", "PRIVATE_HOME"))
    @fs.write_string_to_file(config.content_dir + "/posts/alpha.md", public_audience_source("public", reference))
    assert_false(@builder.inventory(config, fresh_output=true, audience=Some(@builder.Audience::Public)).ready)
    assert_false(@fs.path_exists(config.output_dir))
  }
}

///|
test "public audience checks excluded references before final owner pruning" {
  let config = public_audience_fixture("superseded_reference")
  @fs.write_string_to_file(config.content_dir + "/posts/alpha.md", public_audience_source("public", "[[secret]] [secret](/secret/)"))
  @fs.write_string_to_file(config.content_dir + "/secret.md", public_audience_source("private", "PRIVATE_SECRET"))
  @fs.write_string_to_file(config.content_dir + "/posts/beta.md", "---\ntitle: Replacement\ndate: 2026-01-02\nvisibility: public\nredirect_from: [/posts/alpha/]\n---\nPublic replacement.\n")
  assert_false(@builder.inventory(config, fresh_output=true, audience=Some(@builder.Audience::Public)).ready)
  assert_true(@builder.check(config, audience=Some(@builder.Audience::Public)).violations.length() > 0)
  assert_false(@fs.path_exists(config.output_dir))
}

///|
test "public audience fails closed on unreadable candidate source kinds" {
  for index, relative in ["posts/broken.md", "standalone/broken.md", "broken.md", "404.md"] {
    let config = public_audience_fixture("read_error_" + index.to_string())
    let path = config.content_dir + "/" + relative
    if @fs.path_exists(path) { @fs.remove_file(path) }
    @fs.create_dir(path)
    assert_false(@builder.inventory(config, fresh_output=true, audience=Some(@builder.Audience::Public)).ready)
    assert_true(@builder.check(config, audience=Some(@builder.Audience::Public)).violations.length() > 0)
    assert_true(@builder.build(config, @cache.empty(config.output_dir), fresh_output=true, audience=Some(@builder.Audience::Public)).errors > 0)
    assert_false(@fs.path_exists(config.output_dir))
  }
}

///|
test "public audience mandates ordinary Markdown image destinations" {
  for index, body in ["![missing image](/missing.png)"] {
    let config = public_audience_fixture("missing_image_" + index.to_string())
    @fs.write_string_to_file(config.content_dir + "/posts/alpha.md", public_audience_source("public", body))
    assert_false(@builder.inventory(config, fresh_output=true, audience=Some(@builder.Audience::Public)).ready)
    assert_true(@builder.check(config, audience=Some(@builder.Audience::Public)).violations.length() > 0)
    assert_false(@fs.path_exists(config.output_dir))
  }
}

///|
test "public 404 validates self heading and root relative destination" {
  let config = public_audience_fixture("404_fragments")
  @fs.write_string_to_file(config.content_dir + "/posts/alpha.md", public_audience_source("public", "# Destination\nPublic destination."))
  @fs.write_string_to_file(config.content_dir + "/404.md", public_audience_source("public", "# Not found\n[here](#not-found) [destination](/posts/alpha/#destination)\n[[alpha]] [[alpha#Destination]] [[#Not found]]"))
  assert_true(@builder.inventory(config, fresh_output=true, audience=Some(@builder.Audience::Public)).ready)
  assert_eq(@builder.check(config, audience=Some(@builder.Audience::Public)).violations.length(), 0)
  assert_false(@fs.path_exists(config.output_dir))
  assert_eq(@builder.build(config, @cache.empty(config.output_dir), fresh_output=true, audience=Some(@builder.Audience::Public)).errors, 0)
  let html = @fs.read_file_to_string(config.output_dir + "/404.html")
  assert_true(html.contains("href=\"/posts/alpha/\""))
  assert_true(html.contains("href=\"/posts/alpha/#destination\""))
  assert_true(html.contains("href=\"#not-found\""))
  assert_false(html.contains("[[alpha"))
  assert_false(html.contains("[[#Not found]]"))
}

///|
test "public audience denies excluded source paths even when copied assets match" {
  let base = publication_fixture("audience_source_asset_collision")
  let config = { ..base, site: @config.parse(@fs.read_file_to_string(base.config_path) + "static_allowlist = [\"posts/beta.md\"]\n").unwrap(), }
  @fs.create_dir(config.content_dir + "/static/posts")
  @fs.write_string_to_file(config.content_dir + "/static/posts/beta.md", "Explicit public static content.")
  @fs.write_string_to_file(config.content_dir + "/posts/beta.md", public_audience_source("private", "PRIVATE_BETA_SENTINEL"))
  @fs.write_string_to_file(config.content_dir + "/posts/alpha.md", public_audience_source("public", "[excluded source](/posts/beta.md)"))
  assert_false(@builder.inventory(config, fresh_output=true, audience=Some(@builder.Audience::Public)).ready)
  assert_true(@builder.check(config, audience=Some(@builder.Audience::Public)).violations.length() > 0)
  assert_true(@builder.build(config, @cache.empty(config.output_dir), fresh_output=true, audience=Some(@builder.Audience::Public)).errors > 0)
  assert_false(@fs.path_exists(config.output_dir))
}

///|
test "public audience denies typed references masked by public canonical collisions" {
  for index, field_type in ["Array[Ref]", "Optional[Array[Ref]]"] {
    let config = public_audience_fixture("typed_reference_collision_" + index.to_string())
    let collections_path = config.collections_path.unwrap()
    @fs.write_string_to_file(collections_path,
      "[posts]\nschema = title:String,date:Date,related:" + field_type + "\ndir = " + config.content_dir + "/posts\n")
    @fs.write_string_to_file(config.content_dir + "/posts/alpha.md",
      "---\ntitle: Alpha\ndate: 2026-01-02\nvisibility: public\nrelated: [beta]\n---\nPublic alpha.\n")
    @fs.write_string_to_file(config.content_dir + "/posts/beta.md",
      "---\ntitle: Private beta\ndate: 2026-01-02\nvisibility: private\naliases: [friendly]\n---\nPRIVATE_TYPED_REFERENCE_SENTINEL\n")
    @fs.write_string_to_file(config.content_dir + "/beta.md", public_audience_source("public", "Public root beta masks the excluded collection slug."))
    let inventory = @builder.inventory(config, fresh_output=true, audience=Some(@builder.Audience::Public))
    assert_false(inventory.ready)
    assert_true(inventory.diagnostics.any(diagnostic => diagnostic.message.contains("public audience boundary")))
    assert_true(@builder.check(config, audience=Some(@builder.Audience::Public)).violations.length() > 0)
    assert_true(@builder.build(config, @cache.empty(config.output_dir), fresh_output=true, audience=Some(@builder.Audience::Public)).errors > 0)
    assert_false(@fs.path_exists(config.output_dir))
  }
}

///|
test "public root discovery deduplicates default and explicit root collection files" {
  for mode in ["default", "explicit"] {
    let base = public_audience_fixture("root_collection_" + mode)
    let config = if mode == "default" { { ..base, collections_path: None } } else {
      @fs.write_string_to_file(base.collections_path.unwrap(),
        "[posts]\nschema = title:String,date:Date\ndir = " + @path.Path(base.content_dir + "/posts/../.").resolve().to_string() + "\n")
      base
    }
    let public_path = config.content_dir + "/root-post.md"
    let private_path = config.content_dir + "/excluded-post.md"
    @fs.write_string_to_file(public_path, public_audience_source("public", "ROOT_COLLECTION_PUBLIC_SENTINEL"))
    @fs.write_string_to_file(private_path, public_audience_source("private", "ROOT_COLLECTION_PRIVATE_SENTINEL"))
    let inventory = @builder.inventory(config, fresh_output=true, audience=Some(@builder.Audience::Public))
    assert_true(inventory.ready)
    assert_eq(inventory.entries.filter(entry => entry.status == "excluded" && entry.source is Some(source) && source.has_suffix("/excluded-post.md")).length(), 1)
    assert_eq(@builder.check(config, audience=Some(@builder.Audience::Public)).violations.length(), 0)
    assert_false(@fs.path_exists(config.output_dir))
    assert_eq(@builder.build(config, @cache.empty(config.output_dir), fresh_output=true, audience=Some(@builder.Audience::Public)).errors, 0)
    assert_true(@fs.read_file_to_string(config.output_dir + "/posts/root-post/index.html").contains("ROOT_COLLECTION_PUBLIC_SENTINEL"))
    assert_false(@fs.path_exists(config.output_dir + "/root-post/index.html"))
    assert_false(@fs.path_exists(config.output_dir + "/posts/excluded-post/index.html"))
  }
}

///|
test "public root discovery deduplicates raw standalone files without suppressing distinct slugs" {
  let base = public_audience_fixture("root_standalone")
  let config = { ..base, site: @config.parse(@fs.read_file_to_string(base.config_path) + "static_allowlist = []\nstandalone_dir = " + @path.Path(base.content_dir + "/posts/../.").resolve().to_string() + "\n").unwrap() }
  @fs.write_string_to_file(config.content_dir + "/posts/alpha.md", public_audience_source("private", "PRIVATE_COLLECTION_SENTINEL"))
  @fs.write_string_to_file(config.content_dir + "/alpha.md", public_audience_source("public", "PUBLIC_STANDALONE_SENTINEL"))
  @fs.write_string_to_file(config.content_dir + "/excluded-root.md", public_audience_source("private", "PRIVATE_STANDALONE_SENTINEL"))
  let inventory = @builder.inventory(config, fresh_output=true, audience=Some(@builder.Audience::Public))
  assert_true(inventory.ready)
  assert_eq(inventory.entries.filter(entry => entry.status == "excluded" && entry.source is Some(source) && source.has_suffix("/excluded-root.md")).length(), 1)
  assert_eq(@builder.check(config, audience=Some(@builder.Audience::Public)).violations.length(), 0)
  assert_eq(@builder.build(config, @cache.empty(config.output_dir), fresh_output=true, audience=Some(@builder.Audience::Public)).errors, 0)
  assert_true(@fs.read_file_to_string(config.output_dir + "/alpha/index.html").contains("PUBLIC_STANDALONE_SENTINEL"))
  assert_false(@fs.path_exists(config.output_dir + "/posts/alpha/index.html"))
}
