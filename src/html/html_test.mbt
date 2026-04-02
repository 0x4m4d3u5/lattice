///|
test "render_page without canonical_url or og_image" {
  let meta : @html.PageMeta = {
    title: "Test Page",
    description: Some("Test description"),
    lang: "en",
    stylesheet: Some("/style.css"),
    canonical_url: None,
    og_image: None,
    feed_url: None,
    structured_data: [],
  }
  let html = @html.render_page(meta, "<p>Body content</p>")
  // Should NOT contain OG tags when canonical_url is None
  assert_eq(html.contains("<link rel=\"canonical\""), false)
  assert_eq(html.contains("og:title"), false)
  assert_eq(html.contains("og:type"), false)
  assert_eq(html.contains("og:url"), false)
  assert_eq(html.contains("og:image"), false)
  assert_eq(html.contains("alternate.*atom"), false)
  // Should NOT contain Twitter Card tags when canonical_url is None
  assert_eq(html.contains("twitter:card"), false)
  assert_eq(html.contains("twitter:title"), false)
  assert_eq(html.contains("twitter:description"), false)
  assert_eq(html.contains("twitter:image"), false)
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
    feed_url: None,
    structured_data: [],
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
  // Should NOT contain feed discovery when feed_url is None
  assert_eq(html.contains("alternate.*atom"), false)
  // Should contain Twitter Card tags when canonical_url is Some
  // Uses "summary" card type when og_image is absent
  assert_eq(
    html.contains("<meta name=\"twitter:card\" content=\"summary\" />"),
    true,
  )
  assert_eq(
    html.contains("<meta name=\"twitter:title\" content=\"Test Page\" />"),
    true,
  )
  assert_eq(
    html.contains(
      "<meta name=\"twitter:description\" content=\"Test description\" />",
    ),
    true,
  )
  // Should NOT contain twitter:image when og_image is None
  assert_eq(html.contains("twitter:image"), false)
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
    feed_url: None,
    structured_data: [],
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
  // Should NOT contain feed discovery when feed_url is None
  assert_eq(html.contains("alternate.*atom"), false)
  // Should contain twitter:image when og_image is Some
  assert_eq(
    html.contains(
      "<meta name=\"twitter:image\" content=\"https://example.com/images/og.png\" />",
    ),
    true,
  )
  // Uses "summary_large_image" card type when og_image is present
  assert_eq(
    html.contains(
      "<meta name=\"twitter:card\" content=\"summary_large_image\" />",
    ),
    true,
  )
}

///|
test "render_page without description should skip og:description" {
  let meta : @html.PageMeta = {
    title: "Test & Page",
    description: None,
    lang: "en",
    stylesheet: Some("/style.css"),
    canonical_url: Some("https://example.com/test-page/"),
    og_image: None,
    feed_url: None,
    structured_data: [],
  }
  let html = @html.render_page(meta, "<p>Body content</p>")
  // Should have OG tags but NO og:description when description is None
  assert_eq(html.contains("<meta name=\"description\""), false)
  assert_eq(html.contains("og:description"), false)
  assert_eq(
    html.contains("<meta property=\"og:title\" content=\"Test &amp; Page\" />"),
    true,
  )
  assert_eq(
    html.contains(
      "<meta property=\"og:url\" content=\"https://example.com/test-page/\" />",
    ),
    true,
  )
  // Should NOT contain feed discovery when feed_url is None
  assert_eq(html.contains("alternate.*atom"), false)
  // Twitter Card: title present, description absent
  assert_eq(
    html.contains("<meta name=\"twitter:title\" content=\"Test &amp; Page\" />"),
    true,
  )
  assert_eq(html.contains("twitter:description"), false)
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
    feed_url: None,
    structured_data: [],
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
  // Twitter Card tags should also escape special characters
  assert_eq(
    html.contains("<meta name=\"twitter:title\" content=\"Test &amp; Page\" />"),
    true,
  )
  assert_eq(
    html.contains(
      "<meta name=\"twitter:description\" content=\"Test &quot;description&quot;\" />",
    ),
    true,
  )
  assert_eq(
    html.contains(
      "<meta name=\"twitter:image\" content=\"https://example.com/img/og.png?v=1&amp;x=2\" />",
    ),
    true,
  )
}

///|
test "render_page emits blog posting json ld in head" {
  let meta : @html.PageMeta = {
    title: "Ignored for JSON-LD",
    description: Some("Test description"),
    lang: "en",
    stylesheet: Some("/style.css"),
    canonical_url: Some("https://example.com/test-page/"),
    og_image: Some("https://example.com/images/og.png"),
    feed_url: None,
    structured_data: [
      @html.BlogPosting({
        headline: "Test Page",
        description: Some("Test description"),
        url: "https://example.com/test-page/",
        date_published: Some("2026-03-19"),
        author: Some("A. Writer"),
        image: Some("https://example.com/images/og.png"),
      }),
    ],
  }
  let html = @html.render_page(meta, "<p>Body content</p>")
  assert_true(html.contains("<script type=\"application/ld+json\">"))
  assert_true(html.contains("\"@type\": \"BlogPosting\""))
  assert_true(html.contains("\"headline\": \"Test Page\""))
  assert_true(html.contains("\"datePublished\": \"2026-03-19\""))
  assert_true(html.contains("\"name\": \"A. Writer\""))
  assert_true(
    html.contains("\"mainEntityOfPage\": {\n    \"@type\": \"WebPage\""),
  )
  assert_true(
    html.contains(
      "</script>\n  <link rel=\"stylesheet\" href=\"/style.css\" />",
    ),
  )
}

///|
test "render_structured_data_script emits breadcrumb list alongside blog posting" {
  let script = @html.render_structured_data_script([
    @html.BreadcrumbList({
      items: [
        { name: "Lattice", item: "https://example.com/" },
        { name: "posts", item: "https://example.com/posts/" },
        { name: "Test Page", item: "https://example.com/posts/test-page/" },
      ],
    }),
    @html.BlogPosting({
      headline: "Test Page",
      description: Some("Test description"),
      url: "https://example.com/posts/test-page/",
      date_published: Some("2026-03-19"),
      author: Some("A. Writer"),
      image: None,
    }),
  ])
  assert_true(script.contains("\"@type\": \"BreadcrumbList\""))
  assert_true(script.contains("\"@type\": \"ListItem\""))
  assert_true(script.contains("\"position\": 1"))
  assert_true(script.contains("\"position\": 3"))
  assert_true(script.contains("\"item\": \"https://example.com/posts/\""))
  assert_true(script.contains("\"@type\": \"BlogPosting\""))
}

///|
test "render_structured_data_script escapes script breaking content" {
  let script = @html.render_structured_data_script([
    @html.BlogPosting({
      headline: "A </script> title",
      description: Some("Rock & roll"),
      url: "https://example.com/post/",
      date_published: None,
      author: None,
      image: None,
    }),
  ])
  assert_true(script.contains("\\u003c/script\\u003e"))
  assert_true(script.contains("Rock \\u0026 roll"))
}

///|
test "inject_head_markup inserts before closing head" {
  let html = "<html><head><title>X</title></head><body></body></html>"
  let out = @html.inject_head_markup(html, "<meta name=\"x\" content=\"1\" />")
  assert_eq(
    out, "<html><head><title>X</title><meta name=\"x\" content=\"1\" /></head><body></body></html>",
  )
}

///|
test "render_page with feed_url includes atom discovery link" {
  let meta : @html.PageMeta = {
    title: "Posts",
    description: Some("All posts"),
    lang: "en",
    stylesheet: Some("/style.css"),
    canonical_url: Some("https://example.com/posts/"),
    og_image: None,
    feed_url: Some("https://example.com/posts/feed.xml"),
    structured_data: [],
  }
  let html = @html.render_page(meta, "<p>Body content</p>")
  // Should contain feed discovery link
  assert_true(
    html.contains(
      "<link rel=\"alternate\" type=\"application/atom+xml\" title=\"Posts\" href=\"https://example.com/posts/feed.xml\" />",
    ),
  )
  // Should also contain OG tags when canonical_url is Some
  assert_true(html.contains("<link rel=\"canonical\""))
  assert_true(html.contains("<meta property=\"og:title\""))
}

///|
test "strip_leading_h1 removes leading h1 from body" {
  let html = "<h1>Title</h1>\n<p>Content</p>"
  let result = @html.strip_leading_h1(html)
  assert_eq(result, "<p>Content</p>")
}

///|
test "strip_leading_h1 removes h1 with leading whitespace" {
  let html = "  \n  <h1>Title</h1>\n<p>Content</p>"
  let result = @html.strip_leading_h1(html)
  assert_eq(result, "<p>Content</p>")
}

///|
test "strip_leading_h1 does not strip h1 not at start" {
  let html = "<p>Intro</p>\n<h1>Title</h1>\n<p>Content</p>"
  let result = @html.strip_leading_h1(html)
  assert_eq(result, "<p>Intro</p>\n<h1>Title</h1>\n<p>Content</p>")
}

///|
test "strip_leading_h1 returns empty when only h1" {
  let html = "<h1>Title</h1>"
  let result = @html.strip_leading_h1(html)
  assert_eq(result, "")
}

///|
test "strip_leading_h1 returns empty when h1 and whitespace" {
  let html = "<h1>Title</h1>\n"
  let result = @html.strip_leading_h1(html)
  assert_eq(result, "")
}

///|
test "strip_leading_h1 preserves h1 with attributes in body" {
  // The stripping only handles plain <h1>...</h1>, not <h1 class="...">
  // This test verifies that a body with only a non-matching start is unchanged
  let html = "<h2>Subtitle</h2>\n<p>Content</p>"
  let result = @html.strip_leading_h1(html)
  assert_eq(result, "<h2>Subtitle</h2>\n<p>Content</p>")
}

///|
test "strip_leading_h1 with complex h1 content" {
  let html = "<h1>Title with <em>emphasis</em></h1>\n<p>Content</p>"
  let result = @html.strip_leading_h1(html)
  assert_eq(result, "<p>Content</p>")
}

///|
test "strip_leading_h1 on empty string" {
  let result = @html.strip_leading_h1("")
  assert_eq(result, "")
}

///|
test "strip_leading_h1 on whitespace only" {
  let result = @html.strip_leading_h1("  \n\t  ")
  assert_eq(result, "  \n\t  ")
}

///|
test "render_head_meta with all fields" {
  let result = @html.render_head_meta(
    "My Page",
    Some("A description"),
    "https://example.com/my-page/",
  )
  assert_true(
    result.contains("<meta property=\"og:title\" content=\"My Page\" />"),
  )
  assert_true(
    result.contains(
      "<meta property=\"og:description\" content=\"A description\" />",
    ),
  )
  assert_true(
    result.contains(
      "<meta property=\"og:url\" content=\"https://example.com/my-page/\" />",
    ),
  )
  assert_true(
    result.contains("<meta property=\"og:type\" content=\"article\" />"),
  )
  assert_true(
    result.contains(
      "<link rel=\"canonical\" href=\"https://example.com/my-page/\" />",
    ),
  )
}

///|
test "render_head_meta without description" {
  let result = @html.render_head_meta("My Page", None, "https://example.com/")
  assert_true(
    result.contains("<meta property=\"og:title\" content=\"My Page\" />"),
  )
  assert_true(!result.contains("og:description"))
  assert_true(
    result.contains(
      "<meta property=\"og:url\" content=\"https://example.com/\" />",
    ),
  )
}

///|
test "render_head_meta escapes special characters" {
  let result = @html.render_head_meta(
    "Test & Page",
    Some("A \"quoted\" description"),
    "https://example.com/test?q=1&x=2",
  )
  assert_true(result.contains("content=\"Test &amp; Page\""))
  assert_true(result.contains("content=\"A &quot;quoted&quot; description\""))
  assert_true(result.contains("href=\"https://example.com/test?q=1&amp;x=2\""))
}
