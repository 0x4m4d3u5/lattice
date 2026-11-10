///|
fn evidence_context_fixture(
  name : String,
  schema : String,
) -> @builder.BuildConfig raise {
  let base = publication_fixture("evidence_context_" + name)
  @fs.write_string_to_file(
    base.collections_path.unwrap(),
    "[posts]\nschema = title:String,date:Date," +
    schema +
    "\ndir = " +
    base.content_dir +
    "/posts\n",
  )
  {
    ..base,
    site: @config.parse(
      @fs.read_file_to_string(base.config_path) +
      "content_index_file = content-index.json\n",
    ).unwrap(),
  }
}

///|
fn evidence_context_note(extra : String) -> String {
  "---\ntitle: Correction\ndate: 2026-03-04\n" +
  extra +
  "\n---\n## Observation\nThe revised procedure.\n"
}

///|
test "typed evidence dates and supersedes survive publication and cached rebuild" {
  let base = evidence_context_fixture(
    "typed", "supersedes:Optional[Array[Ref[posts]]],observed_at:Optional[DateTime],valid_from:Optional[DateTime],valid_until:Optional[DateTime]",
  )
  let config = { ..base, force_rebuild: false, }
  @fs.write_string_to_file(
    config.content_dir + "/posts/beta.md",
    evidence_context_note(
      "supersedes: [alpha, alpha, beta]\nobserved_at: '2026-03-04T12:00:00Z'\nvalid_from: '2026-02-03 04:05:06'\nvalid_until: '2027-01-01T00:00:00+05:30'",
    ),
  )
  let first = @builder.build(config, @cache.empty(config.output_dir))
  assert_eq(first.errors, 0)
  let index = @fs.read_file_to_string(config.output_dir + "/content-index.json")
  assert_true(
    index.contains(
      "\"supersedes\": [{\"url\": \"/posts/alpha/\", \"title\": \"Alpha\"}]",
    ),
  )
  assert_true(index.contains("\"observed_at\": \"2026-03-04T12:00:00Z\""))
  assert_true(index.contains("\"valid_from\": \"2026-02-03 04:05:06\""))
  assert_true(index.contains("\"valid_until\": \"2027-01-01T00:00:00+05:30\""))
  assert_true(index.contains("Original alpha."))
  let second = @builder.build(config, publication_load_cache(config))
  assert_eq(second.errors, 0)
  assert_eq(
    @fs.read_file_to_string(config.output_dir + "/content-index.json"),
    index,
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Hidden title sentinel\ndate: 2026-01-02\ndraft: true\n---\nHidden body sentinel",
  )
  assert_eq(@builder.build(config, publication_load_cache(config)).errors, 0)
  let hidden = @fs.read_file_to_string(
    config.output_dir + "/content-index.json",
  )
  assert_false(hidden.contains("supersedes"))
  assert_false(hidden.contains("Hidden title sentinel"))
  assert_false(hidden.contains("/posts/alpha/"))
  assert_eq(
    @builder.build(
      { ..config, include_drafts: true, },
      @cache.empty(config.output_dir),
    ).errors,
    0,
  )
  assert_true(
    @fs.read_file_to_string(config.output_dir + "/content-index.json").contains(
      "\"supersedes\":",
    ),
  )
}

///|
test "untyped evidence field names do not opt into context" {
  let config = evidence_context_fixture(
    "untyped", "supersedes:Optional[String],observed_at:Optional[String],valid_from:Optional[String]",
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/beta.md",
    evidence_context_note(
      "supersedes: alpha\nobserved_at: arbitrary sentinel\nvalid_from: arbitrary sentinel",
    ),
  )
  assert_eq(@builder.build(config, @cache.empty(config.output_dir)).errors, 0)
  let index = @fs.read_file_to_string(config.output_dir + "/content-index.json")
  assert_false(index.contains("supersedes"))
  assert_false(index.contains("observed_at"))
  assert_false(index.contains("arbitrary sentinel"))
}

///|
test "evidence metadata uses existing DateTime and Ref validation" {
  for
    i, extra in [
      "observed_at: '2026-02-30T12:00:00Z'", "supersedes: missing", "supersedes: about",
    ] {
    let config = evidence_context_fixture(
      "invalid_" + i.to_string(),
      "supersedes:Optional[Ref[posts]],observed_at:Optional[DateTime]",
    )
    @fs.write_string_to_file(
      config.content_dir + "/posts/beta.md",
      evidence_context_note(extra),
    )
    assert_true(@builder.check(config).violations.length() > 0)
    assert_true(
      @builder.build(config, @cache.empty(config.output_dir)).errors > 0,
    )
    assert_false(@fs.path_exists(config.output_dir))
  }
}

///|
test "author supersession excludes targets replaced by final output" {
  let config = evidence_context_fixture(
    "replaced", "supersedes:Optional[Ref[posts]]",
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/beta.md",
    evidence_context_note("supersedes: alpha\nredirect_from: [/posts/alpha/]"),
  )
  assert_eq(@builder.build(config, @cache.empty(config.output_dir)).errors, 0)
  assert_false(
    @fs.read_file_to_string(config.output_dir + "/content-index.json").contains(
      "\"supersedes\":",
    ),
  )
}

///|
test "public audience rejects supersedes into excluded identities before publication" {
  let base = evidence_context_fixture(
    "private", "supersedes:Optional[Ref[posts]],visibility:String",
  )
  let config = {
    ..base,
    site: @config.parse(
      @fs.read_file_to_string(base.config_path) +
      "content_index_file = content-index.json\nstatic_allowlist = []\n",
    ).unwrap(),
  }
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Private sentinel\ndate: 2026-01-02\nvisibility: private\n---\nSecret",
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/beta.md",
    evidence_context_note("visibility: public\nsupersedes: alpha"),
  )
  assert_true(
    @builder.check(config, audience=Some(@builder.Audience::Public)).violations.length() >
    0,
  )
  assert_true(
    @builder.build(
      config,
      @cache.empty(config.output_dir),
      fresh_output=true,
      audience=Some(@builder.Audience::Public),
    ).errors >
    0,
  )
  assert_false(@fs.path_exists(config.output_dir))
}

///|
test "replaced sources cannot export times or outgoing correction claims" {
  let config = evidence_context_fixture(
    "replaced_source", "supersedes:Optional[Ref[posts]],observed_at:Optional[DateTime]",
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/beta.md",
    evidence_context_note(
      "supersedes: alpha\nobserved_at: '2099-01-01T00:00:00Z'",
    ),
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/gamma.md",
    "---\ntitle: Gamma\ndate: 2026-04-05\nredirect_from: [/posts/beta/]\n---\nReplacement.",
  )
  assert_eq(@builder.build(config, @cache.empty(config.output_dir)).errors, 0)
  let index = @fs.read_file_to_string(config.output_dir + "/content-index.json")
  assert_false(index.contains("\"supersedes\":"))
  assert_false(index.contains("\"observed_at\":"))
  assert_false(index.contains("2099-01-01"))
}

///|
test "static final owner cannot be a correction target" {
  let config = evidence_context_fixture(
    "static_target", "supersedes:Optional[Ref[posts]]",
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/beta.md",
    evidence_context_note("supersedes: alpha"),
  )
  let config = {
    ..config,
    site: { ..config.site, static_dir: Some("posts"), },
  }
  @fs.create_dir(config.content_dir + "/posts/alpha")
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha/index.html",
    "Static final owner",
  )
  assert_eq(@builder.build(config, @cache.empty(config.output_dir)).errors, 0)
  assert_eq(
    @fs.read_file_to_string(config.output_dir + "/posts/alpha/index.html"),
    "Static final owner",
  )
  assert_false(
    @fs.read_file_to_string(config.output_dir + "/content-index.json").contains(
      "\"supersedes\":",
    ),
  )
}
