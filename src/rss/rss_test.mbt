///|
/// Tests for RSS/Atom feed generation.

///|
fn test_pages() -> Array[@graph.GraphPage] {
  [
    {
      slug: "first-post",
      title: "First Post",
      url: "/posts/first-post/",
      description: Some("First post description"),
      date: Some("2024-01-15"),
      outgoing: [],
      weight: None,
    },
    {
      slug: "second-post",
      title: "Second Post",
      url: "/posts/second-post/",
      description: Some("Second post description"),
      date: Some("2024-02-20"),
      outgoing: [],
      weight: None,
    },
    {
      slug: "third-post",
      title: "Third Post",
      url: "/posts/third-post/",
      description: Some("Third post description"),
      date: Some("2024-01-10"),
      outgoing: [],
      weight: None,
    },
  ]
}

///|
test "render_feed generates valid Atom feed XML" {
  let pages = test_pages()
  let feed = @rss.render_feed("Test Site", "https://example.com", pages, None)

  inspect(
    feed.contains("<?xml version=\"1.0\" encoding=\"utf-8\"?>"),
    content="true",
  )
  inspect(
    feed.contains("<feed xmlns=\"http://www.w3.org/2005/Atom\">"),
    content="true",
  )
  inspect(feed.contains("<title>Test Site</title>"), content="true")
  inspect(feed.contains("<id>https://example.com/</id>"), content="true")
  inspect(
    feed.contains("<link href=\"https://example.com/\" />"),
    content="true",
  )
  inspect(feed.contains("<updated>"), content="true")
  inspect(feed.contains("<entry>"), content="true")

  // Entries should be sorted by date (newest first: Second, First, Third)
  // Verify all three are present
  inspect(feed.contains("<title>Second Post</title>"), content="true")
  inspect(feed.contains("<title>First Post</title>"), content="true")
  inspect(feed.contains("<title>Third Post</title>"), content="true")
}

///|
test "render_feed includes entry details" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "test-post",
      title: "Test Post Title",
      url: "/posts/test-post/",
      description: Some("Test description with <special> & chars"),
      date: Some("2024-03-01"),
      outgoing: [],
      weight: None,
    },
  ]
  let feed = @rss.render_feed("Test", "https://example.com", pages, None)

  inspect(feed.contains("<title>Test Post Title</title>"), content="true")
  inspect(
    feed.contains("<id>https://example.com/posts/test-post/</id>"),
    content="true",
  )
  inspect(
    feed.contains("<link href=\"https://example.com/posts/test-post/\" />"),
    content="true",
  )
  inspect(
    feed.contains("<updated>2024-03-01T00:00:00Z</updated>"),
    content="true",
  )
  inspect(
    feed.contains("<published>2024-03-01T00:00:00Z</published>"),
    content="true",
  )
  inspect(feed.contains("&lt;special&gt; &amp; chars"), content="true")
  inspect(feed.contains("<summary>"), content="true")
}

///|
test "render_feed handles pages without description" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "no-desc",
      title: "Post Without Description",
      url: "/posts/no-desc/",
      description: None,
      date: Some("2024-01-01"),
      outgoing: [],
      weight: None,
    },
  ]
  let feed = @rss.render_feed("Test", "https://example.com", pages, None)

  inspect(
    feed.contains("<title>Post Without Description</title>"),
    content="true",
  )
}

///|
test "render_feed handles pages without date" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "no-date",
      title: "Post Without Date",
      url: "/posts/no-date/",
      description: Some("No date"),
      date: None,
      outgoing: [],
      weight: None,
    },
  ]
  let feed = @rss.render_feed("Test", "https://example.com", pages, None)

  inspect(feed.contains("<title>Post Without Date</title>"), content="true")
}

///|
test "render_feed with RFC3339 date format" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "rfc-post",
      title: "RFC3339 Date Post",
      url: "/posts/rfc-post/",
      description: Some("Has RFC3339 date"),
      date: Some("2024-03-15T14:30:00Z"),
      outgoing: [],
      weight: None,
    },
  ]
  let feed = @rss.render_feed("Test", "https://example.com", pages, None)

  inspect(
    feed.contains("<updated>2024-03-15T14:30:00Z</updated>"),
    content="true",
  )
  inspect(
    feed.contains("<published>2024-03-15T14:30:00Z</published>"),
    content="true",
  )
}

///|
test "render_feed handles base URL variations" {
  let pages = test_pages()

  let feed1 = @rss.render_feed("Test", "https://example.com", pages, None)
  inspect(feed1.contains("<id>https://example.com/</id>"), content="true")

  let feed2 = @rss.render_feed("Test", "https://example.com/", pages, None)
  inspect(feed2.contains("<id>https://example.com/</id>"), content="true")

  let feed3 = @rss.render_feed("Test", "https://example.com/blog", pages, None)
  inspect(feed3.contains("<id>https://example.com/blog/</id>"), content="true")
  inspect(
    feed3.contains(
      "<link href=\"https://example.com/blog/posts/first-post/\" />",
    ),
    content="true",
  )
}

///|
test "render_feed handles empty pages array" {
  let pages : Array[@graph.GraphPage] = []
  let feed = @rss.render_feed("Empty Site", "https://example.com", pages, None)

  inspect(
    feed.contains("<?xml version=\"1.0\" encoding=\"utf-8\"?>"),
    content="true",
  )
  inspect(
    feed.contains("<feed xmlns=\"http://www.w3.org/2005/Atom\">"),
    content="true",
  )
  inspect(feed.contains("<title>Empty Site</title>"), content="true")
  inspect(!feed.contains("<entry>"), content="true")
}

///|
test "render_feed XML character escaping" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "escape-test",
      title: "Title with &amp; <tag> \"quotes\" 'apost'",
      url: "/posts/escape/",
      description: Some("Description with & < > \" '"),
      date: Some("2024-01-01"),
      outgoing: [],
      weight: None,
    },
  ]
  let feed = @rss.render_feed("Test", "https://example.com", pages, None)

  inspect(feed.contains("&amp;"), content="true")
  inspect(feed.contains("&lt;"), content="true")
  inspect(feed.contains("&gt;"), content="true")
  inspect(!feed.contains(" & "), content="true")
  inspect(!feed.contains(" < "), content="true")
  inspect(!feed.contains(" > "), content="true")
}

///|
test "render_feed respects limit parameter" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "post-1",
      title: "Post 1",
      url: "/posts/post-1/",
      description: Some("First"),
      date: Some("2024-01-01"),
      outgoing: [],
      weight: None,
    },
    {
      slug: "post-2",
      title: "Post 2",
      url: "/posts/post-2/",
      description: Some("Second"),
      date: Some("2024-01-02"),
      outgoing: [],
      weight: None,
    },
    {
      slug: "post-3",
      title: "Post 3",
      url: "/posts/post-3/",
      description: Some("Third"),
      date: Some("2024-01-03"),
      outgoing: [],
      weight: None,
    },
  ]

  let limited_feed = @rss.render_feed(
    "Test",
    "https://example.com",
    pages,
    Some(2),
  )
  inspect(limited_feed.contains("<title>Post 3</title>"), content="true")
  inspect(limited_feed.contains("<title>Post 2</title>"), content="true")
  inspect(!limited_feed.contains("<title>Post 1</title>"), content="true")

  let full_feed = @rss.render_feed("Test", "https://example.com", pages, None)
  inspect(full_feed.contains("<title>Post 3</title>"), content="true")
  inspect(full_feed.contains("<title>Post 2</title>"), content="true")
  inspect(full_feed.contains("<title>Post 1</title>"), content="true")

  let oversized_feed = @rss.render_feed(
    "Test",
    "https://example.com",
    pages,
    Some(100),
  )
  inspect(oversized_feed.contains("<title>Post 1</title>"), content="true")
  inspect(oversized_feed.contains("<title>Post 2</title>"), content="true")
  inspect(oversized_feed.contains("<title>Post 3</title>"), content="true")
}

///|
test "render_feed with limit of 1" {
  let pages = test_pages()
  let feed = @rss.render_feed("Test", "https://example.com", pages, Some(1))

  inspect(feed.contains("<title>Second Post</title>"), content="true")
  inspect(!feed.contains("<title>First Post</title>"), content="true")
  inspect(!feed.contains("<title>Third Post</title>"), content="true")
}

///|
test "render_json_feed basic structure" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "hello",
      title: "Hello World",
      url: "/posts/hello/",
      description: Some("A greeting"),
      date: Some("2024-01-01"),
      outgoing: [],
      weight: None,
    },
  ]
  let feed = @rss.render_json_feed_from_pages(
    "My Site",
    "https://example.com/",
    pages,
    None,
    "https://example.com/feed.json",
  )
  inspect(
    feed.contains("\"version\": \"https://jsonfeed.org/version/1.1\""),
    content="true",
  )
  inspect(feed.contains("\"title\": \"My Site\""), content="true")
  inspect(
    feed.contains("\"home_page_url\": \"https://example.com/\""),
    content="true",
  )
  inspect(
    feed.contains("\"feed_url\": \"https://example.com/feed.json\""),
    content="true",
  )
  inspect(
    feed.contains("\"authors\": [{\"name\": \"My Site\"}]"),
    content="true",
  )
  inspect(feed.contains("\"items\":"), content="true")
}

///|
test "render_json_feed items have correct fields" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "foo",
      title: "Post Title",
      url: "/posts/foo/",
      description: Some("Description text here"),
      date: Some("2024-01-01"),
      outgoing: [],
      weight: None,
    },
  ]
  let feed = @rss.render_json_feed_from_pages(
    "My Site",
    "https://example.com/",
    pages,
    None,
    "https://example.com/feed.json",
  )
  inspect(
    feed.contains("\"id\": \"https://example.com/posts/foo/\""),
    content="true",
  )
  inspect(
    feed.contains("\"url\": \"https://example.com/posts/foo/\""),
    content="true",
  )
  inspect(feed.contains("\"title\": \"Post Title\""), content="true")
}

///|
test "render_json_feed summary present when description exists" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "with-desc",
      title: "With Desc",
      url: "/posts/with-desc/",
      description: Some("Description text here"),
      date: Some("2024-01-01"),
      outgoing: [],
      weight: None,
    },
  ]
  let feed = @rss.render_json_feed_from_pages(
    "Test",
    "https://example.com",
    pages,
    None,
    "https://example.com/feed.json",
  )
  inspect(
    feed.contains("\"summary\": \"Description text here\""),
    content="true",
  )
}

///|
test "render_json_feed summary absent when description is None" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "no-desc",
      title: "No Desc",
      url: "/posts/no-desc/",
      description: None,
      date: Some("2024-01-01"),
      outgoing: [],
      weight: None,
    },
  ]
  let feed = @rss.render_json_feed_from_pages(
    "Test",
    "https://example.com",
    pages,
    None,
    "https://example.com/feed.json",
  )
  inspect(!feed.contains("\"summary\""), content="true")
}

///|
test "render_json_feed date fields present when date exists" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "dated",
      title: "Dated Post",
      url: "/posts/dated/",
      description: None,
      date: Some("2024-06-15"),
      outgoing: [],
      weight: None,
    },
  ]
  let feed = @rss.render_json_feed_from_pages(
    "Test",
    "https://example.com",
    pages,
    None,
    "https://example.com/feed.json",
  )
  inspect(
    feed.contains("\"date_published\": \"2024-06-15T00:00:00Z\""),
    content="true",
  )
  inspect(
    feed.contains("\"date_modified\": \"2024-06-15T00:00:00Z\""),
    content="true",
  )
}

///|
test "render_json_feed date fields absent when no date" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "undated",
      title: "Undated Post",
      url: "/posts/undated/",
      description: None,
      date: None,
      outgoing: [],
      weight: None,
    },
  ]
  let feed = @rss.render_json_feed_from_pages(
    "Test",
    "https://example.com",
    pages,
    None,
    "https://example.com/feed.json",
  )
  inspect(!feed.contains("\"date_published\""), content="true")
  inspect(!feed.contains("\"date_modified\""), content="true")
}

///|
test "render_json_feed JSON string escaping" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "escape",
      title: "Title with \"quotes\" and \\backslash",
      url: "/posts/escape/",
      description: Some("Has <tag> & 'apos' too"),
      date: Some("2024-01-01"),
      outgoing: [],
      weight: None,
    },
  ]
  let feed = @rss.render_json_feed_from_pages(
    "Test",
    "https://example.com",
    pages,
    None,
    "https://example.com/feed.json",
  )
  // Double quotes must be escaped as \"
  inspect(feed.contains("\\\"quotes\\\""), content="true")
  // Backslashes must be escaped as \\
  inspect(feed.contains("\\\\backslash"), content="true")
}

///|
test "render_json_feed respects limit parameter" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "post-1",
      title: "Post 1",
      url: "/posts/post-1/",
      description: Some("First"),
      date: Some("2024-01-01"),
      outgoing: [],
      weight: None,
    },
    {
      slug: "post-2",
      title: "Post 2",
      url: "/posts/post-2/",
      description: Some("Second"),
      date: Some("2024-01-02"),
      outgoing: [],
      weight: None,
    },
    {
      slug: "post-3",
      title: "Post 3",
      url: "/posts/post-3/",
      description: Some("Third"),
      date: Some("2024-01-03"),
      outgoing: [],
      weight: None,
    },
  ]
  let feed = @rss.render_json_feed_from_pages(
    "Test",
    "https://example.com",
    pages,
    Some(2),
    "https://example.com/feed.json",
  )
  inspect(feed.contains("\"title\": \"Post 3\""), content="true")
  inspect(feed.contains("\"title\": \"Post 2\""), content="true")
  inspect(!feed.contains("\"title\": \"Post 1\""), content="true")
}

///|
test "render_json_feed sorting newest first" {
  let pages = test_pages()
  let feed = @rss.render_json_feed_from_pages(
    "Test",
    "https://example.com",
    pages,
    None,
    "https://example.com/feed.json",
  )
  // Verify all three exist in the output
  inspect(feed.contains("\"title\": \"Second Post\""), content="true")
  inspect(feed.contains("\"title\": \"First Post\""), content="true")
  inspect(feed.contains("\"title\": \"Third Post\""), content="true")
  // Second Post (2024-02-20) should appear before First Post (2024-01-15)
  let second_idx = @strutil.find_str(feed, 0, "Second Post", feed.length())
  let first_idx = @strutil.find_str(feed, 0, "First Post", feed.length())
  inspect(second_idx >= 0, content="true")
  inspect(first_idx >= 0, content="true")
  inspect(second_idx < first_idx, content="true")
}
