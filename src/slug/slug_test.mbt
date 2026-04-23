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

///|
test "slug slug_to_url basic conversion" {
  assert_eq(slug_to_url("hello-world"), "/hello-world/")
  assert_eq(slug_to_url("index"), "/index/")
  assert_eq(slug_to_url("my-post"), "/my-post/")
}

///|
test "slug slug_to_url empty string" {
  assert_eq(slug_to_url(""), "//")
}

///|
test "slug slug_to_url single char" {
  assert_eq(slug_to_url("a"), "/a/")
}

///|
test "slug slug_to_url already-slashed input" {
  // slug_to_url does not deduplicate slashes — it wraps whatever it gets
  assert_eq(slug_to_url("nested/path"), "/nested/path/")
  assert_eq(slug_to_url("/leading"), "//leading/")
}

///|
test "slug filename_to_slug no extension passes through" {
  assert_eq(filename_to_slug("readme"), "readme")
  assert_eq(filename_to_slug("CHANGELOG"), "changelog")
}

///|
test "slug filename_to_slug empty string" {
  assert_eq(filename_to_slug(""), "")
}

///|
test "slug filename_to_slug numeric filename" {
  assert_eq(filename_to_slug("2024.md"), "2024")
  assert_eq(filename_to_slug("404.md"), "404")
}

///|
test "slug filename_to_slug hyphens pass through" {
  assert_eq(filename_to_slug("hello-world.md"), "hello-world")
  assert_eq(filename_to_slug("a-b-c.md"), "a-b-c")
}

///|
test "slug filename_to_slug non-md extension stays" {
  assert_eq(filename_to_slug("notes.txt"), "notes.txt")
  assert_eq(filename_to_slug("image.png"), "image.png")
}

///|
test "slug filename_to_slug multiple dots" {
  // only the trailing .md is stripped (case-insensitive)
  assert_eq(filename_to_slug("v1.0.md"), "v1.0")
  assert_eq(filename_to_slug("file.name.with.dots.md"), "file.name.with.dots")
}

///|
test "slug transliteration ø → o, Ø → o" {
  // ø is U+00F8, Ø is U+00D8
  assert_eq(filename_to_slug("føø.md"), "foo")
  assert_eq(filename_to_slug("Øystein.md"), "oystein")
}

///|
test "slug transliteration ù ú û ü → u, Ù Ú Û Ü → u" {
  assert_eq(filename_to_slug("résumé.md"), "resume")
  assert_eq(filename_to_slug("naïve.md"), "naive")
  assert_eq(filename_to_slug("dès.md"), "des")
  assert_eq(filename_to_slug("Über.md"), "uber")
  assert_eq(filename_to_slug("ÙÚÛÜ.md"), "uuuu")
}

///|
test "slug transliteration ý ÿ → y, Ý → y" {
  assert_eq(filename_to_slug("mýth.md"), "myth")
  assert_eq(filename_to_slug("Ý.md"), "y")
}

///|
test "slug transliteration ligatures Œ œ → oe" {
  // Œ is U+0152, œ is U+0153
  assert_eq(filename_to_slug("Œuvre.md"), "oeuvre")
  assert_eq(filename_to_slug("cœur.md"), "coeur")
}

///|
test "slug non-Latin chars pass through unchanged" {
  // Chinese characters should pass through as-is (no transliteration defined)
  assert_eq(filename_to_slug("你好.md"), "你好")
  assert_eq(filename_to_slug("日本語.md"), "日本語")
}
