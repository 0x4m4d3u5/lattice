///|
test "render_page without canonical_url or og_image" {
  let meta : @html.PageMeta = {
    title: "Test Page",
    description: Some("Test description"),
    lang: "en",
    stylesheet: Some("/style.css"),
    canonical_url: None,
    og_image: None,
  }
  let html = @html.render_page(meta, "<p>Body content</p>")
  // Should NOT contain OG tags when canonical_url is None
  assert_eq(html.contains("<link rel=\"canonical\""), false)
  assert_eq(html.contains("og:title"), false)
  assert_eq(html.contains("og:type"), false)
  assert_eq(html.contains("og:url"), false)
  assert_eq(html.contains("og:image"), false)
  // Should contain basic meta tags
  assert_eq(
    html.contains("<meta name=\"description\" content=\"Test description\""),
    true,
  )
  assert_eq(html.contains("<title>Test Page</title>"), true)
}

///|
test "render_page with canonical_url only" {
  let meta : @html.PageMeta = {
    title: "Test Page",
    description: Some("Test description"),
    lang: "en",
    stylesheet: Some("/style.css"),
    canonical_url: Some("https://example.com/test-page/"),
    og_image: None,
  }
  let html = @html.render_page(meta, "<p>Body content</p>")
  // Should contain OG tags when canonical_url is Some
  assert_eq(
    html.contains(
      "<link rel=\"canonical\" href=\"https://example.com/test-page/\" />",
    ),
    true,
  )
  assert_eq(
    html.contains("<meta property=\"og:type\" content=\"article\" />"),
    true,
  )
  assert_eq(
    html.contains("<meta property=\"og:title\" content=\"Test Page\" />"),
    true,
  )
  assert_eq(
    html.contains(
      "<meta property=\"og:description\" content=\"Test description\" />",
    ),
    true,
  )
  assert_eq(
    html.contains(
      "<meta property=\"og:url\" content=\"https://example.com/test-page/\" />",
    ),
    true,
  )
  // Should NOT contain og:image when it's None
  assert_eq(html.contains("og:image"), false)
}

///|
test "render_page with canonical_url and og_image" {
  let meta : @html.PageMeta = {
    title: "Test Page",
    description: Some("Test description"),
    lang: "en",
    stylesheet: Some("/style.css"),
    canonical_url: Some("https://example.com/test-page/"),
    og_image: Some("https://example.com/images/og.png"),
  }
  let html = @html.render_page(meta, "<p>Body content</p>")
  // Should contain all OG tags including og:image
  assert_eq(
    html.contains(
      "<link rel=\"canonical\" href=\"https://example.com/test-page/\" />",
    ),
    true,
  )
  assert_eq(
    html.contains("<meta property=\"og:type\" content=\"article\" />"),
    true,
  )
  assert_eq(
    html.contains("<meta property=\"og:title\" content=\"Test Page\" />"),
    true,
  )
  assert_eq(
    html.contains(
      "<meta property=\"og:description\" content=\"Test description\" />",
    ),
    true,
  )
  assert_eq(
    html.contains(
      "<meta property=\"og:url\" content=\"https://example.com/test-page/\" />",
    ),
    true,
  )
  assert_eq(
    html.contains(
      "<meta property=\"og:image\" content=\"https://example.com/images/og.png\" />",
    ),
    true,
  )
}

///|
test "render_page without description should skip og:description" {
  let meta : @html.PageMeta = {
    title: "Test Page",
    description: None,
    lang: "en",
    stylesheet: Some("/style.css"),
    canonical_url: Some("https://example.com/test-page/"),
    og_image: None,
  }
  let html = @html.render_page(meta, "<p>Body content</p>")
  // Should have OG tags but NO og:description when description is None
  assert_eq(html.contains("<meta name=\"description\""), false)
  assert_eq(html.contains("og:description"), false)
  assert_eq(
    html.contains("<meta property=\"og:title\" content=\"Test Page\" />"),
    true,
  )
  assert_eq(
    html.contains(
      "<meta property=\"og:url\" content=\"https://example.com/test-page/\" />",
    ),
    true,
  )
}

///|
test "render_page escapes special characters in canonical_url and og_image" {
  let meta : @html.PageMeta = {
    title: "Test & Page",
    description: Some("Test \"description\""),
    lang: "en",
    stylesheet: Some("/style.css"),
    canonical_url: Some("https://example.com/test-page/?q=1&lang=en"),
    og_image: Some("https://example.com/img/og.png?v=1&x=2"),
  }
  let html = @html.render_page(meta, "<p>Body content</p>")
  // Special characters in URLs should be escaped
  assert_eq(
    html.contains("href=\"https://example.com/test-page/?q=1&amp;lang=en\""),
    true,
  )
  assert_eq(
    html.contains("content=\"https://example.com/img/og.png?v=1&amp;x=2\""),
    true,
  )
  // Title and description should also be escaped
  assert_eq(html.contains("content=\"Test &amp; Page\""), true)
  assert_eq(html.contains("content=\"Test &quot;description&quot;\""), true)
}
