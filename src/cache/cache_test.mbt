///|
test "cache render and parse roundtrip" {
  let source = render({
    version: 1,
    entries: [
      { slug: "posts/hello", fingerprint: "123" },
      { slug: "about", fingerprint: "456" },
    ],
  })
  let parsed = parse(source) catch {
    ParseFailure(_) => {
      assert_true(false)
      { version: 0, entries: [] }
    }
  }
  assert_eq(parsed.version, 1)
  assert_eq(parsed.entries.length(), 2)
  assert_eq(parsed.entries[0].slug, "posts/hello")
  assert_eq(parsed.entries[0].fingerprint, "123")
}

///|
test "fingerprint changes with source content" {
  let same_a = fingerprint_for_source(
    "content/a.md", "---\ntitle: A\n---\nBody",
  )
  let same_b = fingerprint_for_source(
    "content/a.md", "---\ntitle: A\n---\nBody",
  )
  let changed = fingerprint_for_source(
    "content/a.md", "---\ntitle: A\n---\nBody!",
  )
  assert_eq(same_a, same_b)
  assert_true(same_a != changed)
}

///|
test "cache remember and lookup by slug" {
  let store = empty("./dist")
  remember(store, "hello", "one")
  remember(store, "hello", "two")
  remember(store, "about", "three")
  match lookup(store, "hello") {
    Some(fp) => assert_eq(fp, "two")
    None => assert_true(false)
  }
  match lookup(store, "about") {
    Some(fp) => assert_eq(fp, "three")
    None => assert_true(false)
  }
}

///|
test "should_skip force_rebuild bypasses a matching cache hit" {
  let store = empty("./dist")
  remember(store, "post-a", "fp123")
  // force_rebuild must return false (do not skip) even when the fingerprint matches
  assert_true(!should_skip(store, "post-a", "fp123", ".", true))
}

///|
test "should_skip returns false when output file does not exist on disk" {
  let store = empty("./dist")
  remember(store, "post-a", "fp123")
  let missing = "./_cache_test_nonexistent_output_dir/index.html"
  // No file on disk means the output is gone — must rebuild regardless of cache
  assert_true(!should_skip(store, "post-a", "fp123", missing, false))
}

///|
test "should_skip returns false for a slug not yet in the cache" {
  let store = empty("./dist")
  // No prior build record — cannot confirm output is fresh
  assert_true(!should_skip(store, "brand-new-slug", "fp123", ".", false))
}

///|
test "should_skip returns true when fingerprint matches and output exists" {
  let store = empty("./dist")
  remember(store, "post-a", "fp-abc")
  // Fingerprint matches and "." exists on disk — safe to skip
  assert_true(should_skip(store, "post-a", "fp-abc", ".", false))
}

///|
test "should_skip returns false when fingerprint changed since last build" {
  let store = empty("./dist")
  remember(store, "post-a", "fp-old")
  // Source was modified — fingerprint differs from cached value
  assert_true(!should_skip(store, "post-a", "fp-new", ".", false))
}

///|
test "fingerprint_for_source is sensitive to path as well as content" {
  let content = "---\ntitle: Same\n---\nSame body"
  let fp_a = fingerprint_for_source("content/a.md", content)
  let fp_b = fingerprint_for_source("content/b.md", content)
  // Renaming a file with identical content must produce a distinct fingerprint
  assert_true(fp_a != fp_b)
}

///|
test "cache parse rejects completely malformed input" {
  let raised = try {
    let _ = parse("not json at all")
    false
  } catch {
    ParseFailure(_) => true
  }
  assert_true(raised)
}

///|
test "cache parse rejects input missing entries field" {
  let raised = try {
    let _ = parse("{\"version\":1}")
    false
  } catch {
    ParseFailure(_) => true
  }
  assert_true(raised)
}

///|
test "cache error_text formats all three error variants with context" {
  assert_true(error_text(ReadError("disk I/O failure")).contains("read failed"))
  assert_true(error_text(ReadError("disk I/O failure")).contains("disk I/O failure"))
  assert_true(error_text(ParseError("unexpected token")).contains("parse failed"))
  assert_true(error_text(ParseError("unexpected token")).contains("unexpected token"))
  assert_true(error_text(WriteError("permission denied")).contains("write failed"))
  assert_true(error_text(WriteError("permission denied")).contains("permission denied"))
}

///|
test "cache render and parse preserves special characters in slug" {
  let file : CacheFile = {
    version: 1,
    entries: [{ slug: "path/with\"quotes", fingerprint: "fp-val" }],
  }
  let rendered = render(file)
  let parsed = parse(rendered) catch {
    ParseFailure(_) => {
      assert_true(false)
      { version: 0, entries: [] }
    }
  }
  assert_eq(parsed.entries[0].slug, "path/with\"quotes")
}
