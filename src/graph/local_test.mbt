///|
test "local graph selects incoming and outgoing neighbors and rejects missing center" {
  let source = "{\"nodes\":[{\"slug\":\"a\",\"url\":\"/a/\",\"title\":\"A\"},{\"slug\":\"b\",\"url\":\"/b/\",\"title\":\"B\"},{\"slug\":\"c\",\"url\":\"/c/\",\"title\":\"C\"}],\"edges\":[{\"source\":\"b\",\"target\":\"a\"},{\"source\":\"a\",\"target\":\"b\"}]}"
  let output = @graph.local_layout(source, "/a/")
  assert_true(output.contains("\"/a/\""))
  assert_true(output.contains("\"/b/\""))
  assert_true(!output.contains("\"/c/\""))
  assert_eq(output, @graph.local_layout(source, "/a/"))
  assert_eq(@graph.local_layout(source, "/missing/"), "{}")
  assert_eq(@graph.local_layout("broken", "/a/"), "{}")
}
