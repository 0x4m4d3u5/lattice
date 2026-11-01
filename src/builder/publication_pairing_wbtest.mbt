///|
test "publication SHA-256 uses UTF-8 on every target" {
  assert_eq(publication_digest(""), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
  assert_eq(publication_digest("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
  assert_eq(publication_digest("Café 🌱\r\n"), "9b4e6a2d4a74716f0cab326bf83bb63992f4a2870f3f05322c48e44c3914dd13")
}
