///|
test "manifest render and parse roundtrip" {
  let manifest : ManifestFile = {
    version: 1,
    entries: [
      {
        src: "content/posts/hello.md",
        mtime: 123456789L,
        out: "_site/posts/hello/index.html",
        targets: ["about", "contact"],
      },
      { src: "content/lattice.conf", mtime: 42L, out: "", targets: [] },
    ],
  }

  let rendered = render(manifest)
  let parsed = parse(rendered) catch {
    ParseError(_) => {
      assert_true(false)
      { version: 0, entries: [] }
    }
  }

  assert_eq(parsed.version, 1)
  assert_eq(parsed.entries.length(), 2)
  assert_eq(parsed.entries[0].src, "content/posts/hello.md")
  assert_eq(parsed.entries[0].mtime, 123456789L)
  assert_eq(parsed.entries[0].out, "_site/posts/hello/index.html")
  assert_eq(parsed.entries[0].targets.length(), 2)
  assert_eq(parsed.entries[0].targets[0], "about")
  assert_eq(parsed.entries[0].targets[1], "contact")
  assert_eq(parsed.entries[1].targets.length(), 0)
}

///|
test "manifest parse accepts entries without targets" {
  let source = "{\"version\":1,\"entries\":[{\"src\":\"a.md\",\"mtime\":1,\"out\":\"out/index.html\"}]}"
  let parsed = parse(source) catch {
    ParseError(_) => {
      assert_true(false)
      { version: 0, entries: [] }
    }
  }
  assert_eq(parsed.entries.length(), 1)
  assert_eq(parsed.entries[0].targets.length(), 0)
}
