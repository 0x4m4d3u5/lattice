///|
test "body-only notes have the same schema contract as empty headers" {
  let optional : @schema.Schema = {
    name: "notes",
    fields: [
      {
        name: "title",
        field_type: @schema.TOptional(@schema.TString(None, None)),
        required: false,
      },
    ],
  }
  let required : @schema.Schema = {
    name: "notes",
    fields: [
      {
        name: "title",
        field_type: @schema.TString(None, None),
        required: true,
      },
    ],
  }
  for body in ["", "\ufeff\r\n# Heading\r\nbody"] {
    let fm = @frontmatter.parse_with_policy(
      body,
      allow_missing_frontmatter=true,
    ).unwrap()
    assert_eq(@schema.validate(fm, optional).length(), 0)
    let errors = @schema.validate(fm, required)
    assert_eq(errors.length(), 1)
    assert_eq(errors[0].field, "title")
    assert_eq(errors[0].message, "required field missing")
    assert_eq(frontmatter_field_line(body, "title"), None)
    assert_eq(extract_title(fm), "Untitled")
    assert_true(publication_visibility(fm) is Ok(Public))
  }
}

///|
test "headerless public projection is excluded with denied identities and no body derivation" {
  let base = public_projection_test_config()
  let config = {
    ..base,
    site: @config.parse(
      "title=Site\nbase_url=/\nallow_missing_frontmatter=true\nstatic_allowlist=[]\n",
    ).unwrap(),
  }
  let source : SourceFile = {
    path: "content/posts/Secret Note.md",
    filename: "Secret Note.md",
    slug: "secret-note",
    content: "# Private body\nvisibility: public\n[[other]]",
    fingerprint: "",
    stamp: 0L,
    link_targets: [],
  }
  let output = OutputPlan::new(
    "output",
    fresh_output=true,
    audience=Some(Public),
  )
  let diagnostics : Array[@diagnostic.Diagnostic] = []
  assert_eq(
    project_public_sources([source], "posts", config, output, diagnostics).length(),
    0,
  )
  assert_eq(diagnostics.length(), 0)
  assert_eq(output.excluded.length(), 1)
  let projection = output.public_projection.unwrap()
  assert_true(projection.denied_names.contains("secret-note"))
  assert_true(public_route_denied(projection, "/posts/secret-note/"))
  assert_true(public_route_denied(projection, "/posts/Secret Note.md"))
  assert_eq(output.files.length(), 0)
  let malformed = { ..source, content: "---\n# body without closing header", }
  assert_eq(
    project_public_sources([malformed], "posts", config, output, diagnostics).length(),
    0,
  )
  assert_eq(diagnostics.length(), 1)
}

///|
test "body-only location scanners retain lines and BOM normalized body" {
  let source = "\ufeff\r\n# Heading\r\n\r\n![[missing.png]]\r\n"
  assert_eq(
    image_embed_location(source, "missing.png", allow_missing_frontmatter=true),
    (Some(4), Some(1)),
  )
  assert_eq(
    extract_link_targets(source, "note", allow_missing_frontmatter=true),
    [],
  )
}
