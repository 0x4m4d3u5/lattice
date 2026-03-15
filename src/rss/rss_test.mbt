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
    },
    {
      slug: "second-post",
      title: "Second Post",
      url: "/posts/second-post/",
      description: Some("Second post description"),
      date: Some("2024-02-20"),
      outgoing: [],
    },
    {
      slug: "third-post",
      title: "Third Post",
      url: "/posts/third-post/",
      description: Some("Third post description"),
      date: Some("2024-01-10"),
      outgoing: [],
    },
  ]
}

///|
test "render_feed generates valid Atom feed XML" {
  let pages = test_pages()
  let feed = @rss.render_feed("Test Site", "https://example.com", pages, None)

  inspect(feed.contains("<?xml version=\"1.0\" encoding=\"utf-8\"?>"), content="true")
  inspect(feed.contains("<feed xmlns=\"http://www.w3.org/2005/Atom\">"), content="true")
  inspect(feed.contains("<title>Test Site</title>"), content="true")
  inspect(feed.contains("<id>https://example.com/</id>"), content="true")
  inspect(feed.contains("<link href=\"https://example.com/\" />"), content="true")
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
    },
  ]
  let feed = @rss.render_feed("Test", "https://example.com", pages, None)

  inspect(feed.contains("<title>Test Post Title</title>"), content="true")
  inspect(feed.contains("<id>https://example.com/posts/test-post/</id>"), content="true")
  inspect(feed.contains("<link href=\"https://example.com/posts/test-post/\" />"), content="true")
  inspect(feed.contains("<updated>2024-03-01T00:00:00Z</updated>"), content="true")
  inspect(feed.contains("<published>2024-03-01T00:00:00Z</published>"), content="true")
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
    },
  ]
  let feed = @rss.render_feed("Test", "https://example.com", pages, None)

  inspect(feed.contains("<title>Post Without Description</title>"), content="true")
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
    },
  ]
  let feed = @rss.render_feed("Test", "https://example.com", pages, None)

  inspect(feed.contains("<updated>2024-03-15T14:30:00Z</updated>"), content="true")
  inspect(feed.contains("<published>2024-03-15T14:30:00Z</published>"), content="true")
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
    feed3.contains("<link href=\"https://example.com/blog/posts/first-post/\" />"),
    content="true",
  )
}

///|
test "render_feed handles empty pages array" {
  let pages : Array[@graph.GraphPage] = []
  let feed = @rss.render_feed("Empty Site", "https://example.com", pages, None)

  inspect(feed.contains("<?xml version=\"1.0\" encoding=\"utf-8\"?>"), content="true")
  inspect(feed.contains("<feed xmlns=\"http://www.w3.org/2005/Atom\">"), content="true")
  inspect(feed.contains("<title>Empty Site</title>"), content="true")
  inspect(not(feed.contains("<entry>")), content="true")
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
    },
  ]
  let feed = @rss.render_feed("Test", "https://example.com", pages, None)

  inspect(feed.contains("&amp;"), content="true")
  inspect(feed.contains("&lt;"), content="true")
  inspect(feed.contains("&gt;"), content="true")
  inspect(not(feed.contains(" & ")), content="true")
  inspect(not(feed.contains(" < ")), content="true")
  inspect(not(feed.contains(" > ")), content="true")
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
    },
    {
      slug: "post-2",
      title: "Post 2",
      url: "/posts/post-2/",
      description: Some("Second"),
      date: Some("2024-01-02"),
      outgoing: [],
    },
    {
      slug: "post-3",
      title: "Post 3",
      url: "/posts/post-3/",
      description: Some("Third"),
      date: Some("2024-01-03"),
      outgoing: [],
    },
  ]

  let limited_feed = @rss.render_feed("Test", "https://example.com", pages, Some(2))
  inspect(limited_feed.contains("<title>Post 3</title>"), content="true")
  inspect(limited_feed.contains("<title>Post 2</title>"), content="true")
  inspect(not(limited_feed.contains("<title>Post 1</title>")), content="true")

  let full_feed = @rss.render_feed("Test", "https://example.com", pages, None)
  inspect(full_feed.contains("<title>Post 3</title>"), content="true")
  inspect(full_feed.contains("<title>Post 2</title>"), content="true")
  inspect(full_feed.contains("<title>Post 1</title>"), content="true")

  let oversized_feed = @rss.render_feed(
    "Test", "https://example.com", pages, Some(100),
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
  inspect(not(feed.contains("<title>First Post</title>")), content="true")
  inspect(not(feed.contains("<title>Third Post</title>")), content="true")
}
