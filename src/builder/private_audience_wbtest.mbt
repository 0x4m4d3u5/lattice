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
