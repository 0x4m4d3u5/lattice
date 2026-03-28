///|
test "slug filename_to_slug normalizes extension case and separators" {
  assert_eq(filename_to_slug("My Post.md"), "my-post")
  assert_eq(filename_to_slug("about_me.md"), "about-me")
  assert_eq(filename_to_slug("GUIDE.MD"), "guide")
  assert_eq(filename_to_slug("guide.MD"), "guide")
  assert_eq(filename_to_slug("INDEX.Md"), "index")
}
