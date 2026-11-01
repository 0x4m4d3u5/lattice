///|
test "local URLs resolve from published routes and mounted base paths" {
  assert_eq(
    local_link_destination(
      "../target/?q=1#r%C3%A9sum%C3%A9", "/notes/source/", "/wiki",
    ),
    Ok(Some(("/notes/target/", Some("résumé")))),
  )
  assert_eq(
    local_link_destination("#time:now", "/notes/source/", "/wiki"),
    Ok(Some(("/notes/source/", Some("time:now")))),
  )
  assert_eq(
    local_link_destination("?q=mailto:x#here", "/notes/source/", ""),
    Ok(Some(("/notes/source/", Some("here")))),
  )
  assert_eq(
    local_link_destination("/wiki/notes/%74arget/", "/notes/source/", "/wiki"),
    Ok(Some(("/notes/target/", None))),
  )
  assert_eq(
    local_link_destination("../../../outside/", "/notes/source/", "/wiki"),
    Err("destination is outside the configured publication base path"),
  )
  assert_eq(
    local_link_destination("../target%2Findex.html", "/notes/source/", ""),
    Err("encoded separators, backslashes and control characters are not supported"),
  )
  for
    url in [
      "https://example.test/missing", "//example.test/missing", "mailto:reader@example.test",
      "data:text/plain,hello",
    ] {
    assert_eq(local_link_destination(url, "/notes/source/", ""), Ok(None))
  }
}

///|
test "publication base paths include root-relative configuration" {
  assert_eq(local_link_base_path("/wiki/"), "/wiki")
  assert_eq(local_link_base_path("https://example.test/wiki/"), "/wiki")
  assert_eq(local_link_base_path("/"), "")
  assert_eq(local_link_path("/wiki//target/"), Err("repeated path separators are not supported"))
}
