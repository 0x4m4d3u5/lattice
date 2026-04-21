///|
test "slug filename_to_slug normalizes extension case and separators" {
  assert_eq(filename_to_slug("My Post.md"), "my-post")
  assert_eq(filename_to_slug("about_me.md"), "about-me")
  assert_eq(filename_to_slug("GUIDE.MD"), "guide")
  assert_eq(filename_to_slug("guide.MD"), "guide")
  assert_eq(filename_to_slug("INDEX.Md"), "index")
}

///|
test "slug Latin transliteration — café, résumé, naïve" {
  assert_eq(filename_to_slug("café.md"), "cafe")
  assert_eq(filename_to_slug("résumé.md"), "resume")
  assert_eq(filename_to_slug("naïve.md"), "naive")
}

///|
test "slug Latin transliteration — Ångström, El Niño" {
  assert_eq(filename_to_slug("Ångström.md"), "angstrom")
  assert_eq(filename_to_slug("El Niño.md"), "el-nino")
}

///|
test "slug Latin transliteration — ß → ss, æ → ae, œ → oe" {
  assert_eq(filename_to_slug("straße.md"), "strasse")
  assert_eq(filename_to_slug("strasse.md"), "strasse")
  assert_eq(filename_to_slug("Cœur.md"), "coeur")
  assert_eq(filename_to_slug("Æther.md"), "aether")
}

///|
test "slug Latin transliteration — uppercase accented variants" {
  assert_eq(filename_to_slug("Été.md"), "ete")
  assert_eq(filename_to_slug("ÜBER.md"), "uber")
  assert_eq(filename_to_slug("Österreich.md"), "osterreich")
}
