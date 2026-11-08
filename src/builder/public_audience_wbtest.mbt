///|
fn public_projection_test_config() -> BuildConfig {
  { content_dir: "content", output_dir: "output", config_path: "site.cfg",
    site: @config.parse("title = Public\nbase_url = https://example.test\nstatic_allowlist = []\n").unwrap(),
    collections_path: None, force_rebuild: true, include_drafts: false }
}

///|
test "projection retains only public bytes and diagnostic normalized identities" {
  let config = public_projection_test_config()
  let output = OutputPlan::new("output", fresh_output=true, audience=Some(Public))
  let diagnostics : Array[@diagnostic.Diagnostic] = []
  let source : SourceFile = { path: "content/posts/Secret Note.md", filename: "Secret Note.md", slug: "secret-note",
    content: "---\nvisibility: private\naliases: [Friendly Name]\nredirect_from: [/old/]\n---\nPRIVATE_BYTES\n", fingerprint: "", stamp: 0L, link_targets: [] }
  assert_eq(project_public_sources([source], "posts", config, output, diagnostics).length(), 0)
  assert_eq(diagnostics.length(), 0)
  let projection = output.public_projection.unwrap()
  assert_true(projection.denied_names.contains("friendly-name"))
  assert_true(projection.denied_paths.contains("/posts/secret-note/index.html"))
  assert_true(projection.denied_paths.contains(public_route_key("/posts/Secret Note.md")))
  assert_true(projection.denied_paths.contains("/old/index.html"))
  assert_eq(output.files.length(), 0)
  assert_eq(output.excluded.length(), 1)
}

///|
test "selected 404 snapshot bypasses legacy source reread and never joins page indexes" {
  let config = public_projection_test_config()
  let source : SourceFile = { path: "content/404.md", filename: "404.md", slug: "404",
    content: "---\nvisibility: public\n---\nSelected snapshot", fingerprint: "", stamp: 0L, link_targets: [] }
  assert_eq(image_embed_sources([], config, selected_404=Some([])).length(), 0)
  let sources = image_embed_sources([], config, selected_404=Some([source]))
  assert_eq(sources.length(), 1)
  assert_eq(sources[0].content, source.content)
  let output = OutputPlan::new("output", audience=Some(Public))
  output.public_projection.unwrap().selected_404.push(source)
  assert_eq(public_audit_sources([], output)[0].definition.name, "_404")
  assert_eq(public_url_output_path("/404.html"), "/404.html")
}

///|
test "public boundary follows nested typed references" {
  let field_type = @schema.TOptional(@schema.TArray(@schema.TOptional(@schema.TRef(None))))
  assert_eq(public_typed_refs(field_type, @frontmatter.FArray([@frontmatter.FStr("secret")])), ["secret"])
  assert_eq(public_typed_refs(@schema.TString(None, None), @frontmatter.FStr("secret")), [])
}

///|
test "excluded directory routes retain html-like slug extensions" {
  let projection = PublicProjection::new()
  projection.denied_paths.set(public_route_key("/secret.html/"), true)
  assert_eq(public_route_key("/secret.html/"), "/secret.html/index.html")
  assert_true(public_route_denied(projection, "/secret.html/index.html"))
  assert_true(public_route_denied(projection, "/secret.html/"))
  assert_true(public_route_denied(projection, "/secret.html"))
  assert_false(public_route_denied(projection, "/public.html"))
}
