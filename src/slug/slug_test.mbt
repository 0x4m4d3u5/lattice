///|
test "slug filename_to_slug normalizes extension case and separators" {
  assert_eq(filename_to_slug("My Post.md"), "my-post")
  assert_eq(filename_to_slug("about_me.md"), "about-me")
  assert_eq(filename_to_slug("GUIDE.MD"), "guide.md")
}

///|
test "slug filename_to_slug leaves non markdown filenames intact" {
  assert_eq(filename_to_slug("notes.txt"), "notes.txt")
  assert_eq(filename_to_slug("Already-Slugged"), "already-slugged")
}

///|
test "slug to url always emits root relative trailing slash" {
  assert_eq(slug_to_url("hello-world"), "/hello-world/")
  assert_eq(slug_to_url("index"), "/index/")
}
