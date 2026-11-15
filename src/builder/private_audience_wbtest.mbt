///|
test "private snapshot is independent from public projection and default rereads" {
  let output = OutputPlan::new("output", fresh_output=true, audience=Some(Private))
  assert_true(output.public_projection is None)
  assert_eq(output.selected_404().unwrap().length(), 0)
  let source : SourceFile = { path: "nonexistent/404.md", filename: "404.md", slug: "404",
    content: "---\nvisibility: private\n---\nPRIVATE_SNAPSHOT", fingerprint: "", stamp: 0L, link_targets: [] }
  output.private_404.push(source)
  let config = public_projection_test_config()
  let sources = image_embed_sources([], config, selected_404=output.selected_404())
  assert_eq(sources.length(), 1)
  assert_eq(sources[0].content, source.content)
  assert_eq(private_audit_sources([], output)[0].sources[0].content, source.content)
  assert_true(OutputPlan::new("output").selected_404() is None)
  let public = OutputPlan::new("output", audience=Some(Public))
  assert_true(public.public_projection is Some(_))
  assert_eq(public.selected_404().unwrap().length(), 0)
  assert_true(publication_visibility_violation(source.path, source.content) is Some(_))
  assert_true(publication_visibility_violation(source.path, source.content, private_export=true) is None)
}

///|
test "private base URL narrow spelling rejects authority tricks" {
  for base in ["/", "http://127.0.0.1", "https://127.0.0.1/", "http://[::1]", "https://[::1]:65535/", "http://127.0.0.1:1", "http://127.0.0.1:8000"] {
    assert_true(private_base_url_allowed(base), msg=base)
  }
  for base in ["", "//", "///", "/memory", "http://localhost", "file:///tmp", "https://example.test", "http://127.0.0.1.evil", "http://127.0.0.1@evil", "http://evil@127.0.0.1", "http://[::1]@evil", "http://[::1].evil", "http://127.0.0.1:0", "http://127.0.0.1:65536", "http://127.0.0.1:-1", "http://127.0.0.1:+80", "http://127.0.0.1:", "http://127.0.0.1:999999999999", "http://127.0.0.1/path", "http://127.0.0.1//", "http://127.0.0.1?x", "http://127.0.0.1#x", "http://127.0.0.1\\evil", "http://127.0.0.1\t", "http://127.0.0.1\n", "http://127.0.0.1:80/../evil"] {
    assert_false(private_base_url_allowed(base), msg=base)
  }
}
