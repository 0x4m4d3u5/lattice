///|
fn navigation_expected_slots(change : String) -> Array[(String, String)] {
  // Literal neighboring URL/title expectations for the authored date fixtures.
  // Keep these independent of production sorting and adjacency helpers.
  match change {
    "insert" =>
      [
        ("delta", "|||/posts/gamma/|Gamma|"),
        ("gamma", "|/posts/delta/|Delta|/posts/epsilon/|Epsilon|"),
        ("epsilon", "|/posts/gamma/|Gamma|/posts/beta/|Beta|"),
        ("beta", "|/posts/epsilon/|Epsilon|/posts/alpha/|Alpha|"),
        ("alpha", "|/posts/beta/|Beta|||"),
      ]
    "delete" =>
      [
        ("delta", "|||/posts/gamma/|Gamma|"),
        ("gamma", "|/posts/delta/|Delta|/posts/alpha/|Alpha|"),
        ("alpha", "|/posts/gamma/|Gamma|||"),
      ]
    "retitle" =>
      [
        ("delta", "|||/posts/gamma/|Gamma|"),
        ("gamma", "|/posts/delta/|Delta|/posts/beta/|Revised Beta|"),
        ("beta", "|/posts/gamma/|Gamma|/posts/alpha/|Alpha|"),
        ("alpha", "|/posts/beta/|Revised Beta|||"),
      ]
    "reorder" =>
      [
        ("beta", "|||/posts/delta/|Delta|"),
        ("delta", "|/posts/beta/|Beta|/posts/gamma/|Gamma|"),
        ("gamma", "|/posts/delta/|Delta|/posts/alpha/|Alpha|"),
        ("alpha", "|/posts/gamma/|Gamma|||"),
      ]
    "rename" =>
      [
        ("delta", "|||/posts/gamma/|Gamma|"),
        ("gamma", "|/posts/delta/|Delta|/posts/omega/|Beta|"),
        ("omega", "|/posts/gamma/|Gamma|/posts/alpha/|Alpha|"),
        ("alpha", "|/posts/omega/|Beta|||"),
      ]
    _ => abort("unknown navigation fixture")
  }
}

///|
fn navigation_assert_slots(
  config : @builder.BuildConfig,
  change : String,
) -> Unit raise {
  for (slug, expected) in navigation_expected_slots(change) {
    let html = @fs.read_file_to_string(
      config.output_dir + "/posts/" + slug + "/index.html",
    )
    assert_true(html.contains(expected))
  }
}

///|
fn navigation_cache_case(change : String) -> Unit raise {
  let config = publication_fixture("navigation_" + change)
  let templates = match config.site.templates_dir {
    Some(path) => path
    None => abort("navigation fixture needs templates")
  }
  @fs.write_string_to_file(
    templates + "/page.html",
    "<html><body>{{title}}|{{prev_post_url}}|{{prev_post_title}}|{{next_post_url}}|{{next_post_title}}|{{content}}</body></html>\n",
  )
  for
    (slug, title, date) in [
      ("gamma", "Gamma", "2026-03-04"),
      ("delta", "Delta", "2026-04-05"),
    ] {
    @fs.write_string_to_file(
      config.content_dir + "/posts/" + slug + ".md",
      "---\ntitle: " + title + "\ndate: " + date + "\n---\nBody.\n",
    )
  }
  publication_seed_success(config)
  let incremental = publication_incremental(config)
  let cached = @builder.build(incremental, publication_load_cache(config))
  assert_eq(cached.errors, 0)
  assert_eq(cached.unchanged_pages, 4)
  let beta = config.content_dir + "/posts/beta.md"
  let mut slugs = ["alpha", "beta", "gamma", "delta"]
  let expected_skips = match change {
    "insert" => {
      @fs.write_string_to_file(
        config.content_dir + "/posts/epsilon.md",
        "---\ntitle: Epsilon\ndate: 2026-02-15\n---\nNew post.\n",
      )
      slugs.push("epsilon")
      2
    }
    "delete" => {
      @fs.remove_file(beta)
      slugs = ["alpha", "gamma", "delta"]
      1
    }
    "retitle" => {
      @fs.write_string_to_file(
        beta, "---\ntitle: Revised Beta\ndate: 2026-02-03\n---\nOriginal beta.\n",
      )
      1
    }
    "reorder" => {
      @fs.write_string_to_file(
        beta, "---\ntitle: Beta\ndate: 2026-05-06\n---\nOriginal beta.\n",
      )
      0
    }
    "rename" => {
      @fs.write_string_to_file(
        config.content_dir + "/posts/omega.md",
        @fs.read_file_to_string(beta),
      )
      @fs.remove_file(beta)
      slugs = ["alpha", "omega", "gamma", "delta"]
      1
    }
    _ => abort("unknown navigation mutation")
  }
  let result = @builder.build(incremental, publication_load_cache(config))
  assert_eq(result.errors, 0)
  navigation_assert_slots(config, change)
  let actual : Array[String] = []
  for slug in slugs {
    actual.push(
      @fs.read_file_to_string(
        config.output_dir + "/posts/" + slug + "/index.html",
      ),
    )
  }
  // The incremental build itself must save reusable metadata.
  let next = @builder.build(incremental, publication_load_cache(config))
  assert_eq(next.errors, 0)
  assert_eq(next.unchanged_pages, slugs.length())
  // A cached build must publish the same navigation as a forced full build.
  let full = @builder.build(config, publication_load_cache(config))
  assert_eq(full.errors, 0)
  navigation_assert_slots(config, change)
  for i, slug in slugs {
    assert_eq(
      actual[i],
      @fs.read_file_to_string(
        config.output_dir + "/posts/" + slug + "/index.html",
      ),
    )
  }
  // Keep pages whose rendered navigation did not change cached.
  assert_eq(result.unchanged_pages, expected_skips)
}

///|
test "cached navigation matches full builds after inserting and deleting a post" {
  for change in ["insert", "delete"] {
    navigation_cache_case(change)
  }
}

///|
test "cached navigation matches full builds after neighbor metadata and path changes" {
  for change in ["retitle", "reorder", "rename"] {
    navigation_cache_case(change)
  }
}
