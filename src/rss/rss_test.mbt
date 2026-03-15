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
  
  // Check for XML declaration
  assert(feed.contains("<?xml version=\"1.0\" encoding=\"utf-8\"?>"))
  
  // Check for feed element with Atom namespace
  assert(feed.contains("<feed xmlns=\"http://www.w3.org/2005/Atom\">"))
  
  // Check for feed title
  assert(feed.contains("<title>Test Site</title>"))
  
  // Check for feed ID and link
  assert(feed.contains("<id>https://example.com/</id>"))
  assert(feed.contains("<link href=\"https://example.com/\" />"))
  
  // Check for updated timestamp
  assert(feed.contains("<updated>"))
  
  // Check for entries
  assert(feed.contains("<entry>"))
  
  // Check that entries are sorted by date (newest first)
  let first_idx = feed.index_of("<entry>")
  let first_title_start = feed.index_of("Second Post", first_idx) // 2024-02-20 is newest
  let second_title_start = feed.index_of("First Post", first_idx)  // 2024-01-15
  let third_title_start = feed.index_of("Third Post", first_idx) // 2024-01-10 is oldest
  
  assert(first_title_start < second_title_start)
  assert(second_title_start < third_title_start)
}

///|
test "render_feed includes entry details" {
  let pages = [
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
  
  // Check entry title
  assert(feed.contains("<title>Test Post Title</title>"))
  
  // Check entry ID (which is the URL)
  assert(feed.contains("<id>https://example.com/posts/test-post/</id>"))
  
  // Check entry link
  assert(feed.contains("<link href=\"https://example.com/posts/test-post/\" />"))
  
  // Check entry date
  assert(feed.contains("<updated>2024-03-01T00:00:00Z</updated>"))
  assert(feed.contains("<published>2024-03-01T00:00:00Z</published>"))
  
  // Check that special XML characters are escaped in summary
  assert(feed.contains("&lt;special&gt; &amp; chars"))
  
  // Check summary element
  assert(feed.contains("<summary>"))
}

///|
test "render_feed handles pages without description" {
  let pages = [
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
  
  // Entry should still be created, just without summary element
  assert(feed.contains("<title>Post Without Description</title>"))
}

///|
test "render_feed handles pages without date" {
  let pages = [
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
  
  // Entry should still be created, feed uses default timestamp
  assert(feed.contains("<title>Post Without Date</title>"))
}

///|
test "render_feed with RFC3339 date format" {
  let pages = [
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
  
  // RFC3339 date should be preserved as-is
  assert(feed.contains("<updated>2024-03-15T14:30:00Z</updated>"))
  assert(feed.contains("<published>2024-03-15T14:30:00Z</published>"))
}

///|
test "render_feed handles base URL variations" {
  let pages = test_pages()
  
  // Base URL without trailing slash
  let feed1 = @rss.render_feed("Test", "https://example.com", pages, None)
  assert(feed1.contains("<id>https://example.com/</id>"))
  
  // Base URL with trailing slash
  let feed2 = @rss.render_feed("Test", "https://example.com/", pages, None)
  assert(feed2.contains("<id>https://example.com/</id>"))
  
  // Base URL with path
  let feed3 = @rss.render_feed("Test", "https://example.com/blog", pages, None)
  assert(feed3.contains("<id>https://example.com/blog/</id>"))
  assert(feed3.contains("<link href=\"https://example.com/blog/posts/first-post/\" />"))
}

///|
test "render_feed handles empty pages array" {
  let pages : Array[@graph.GraphPage] = []
  let feed = @rss.render_feed("Empty Site", "https://example.com", pages, None)
  
  // Should still generate valid feed structure
  assert(feed.contains("<?xml version=\"1.0\" encoding=\"utf-8\"?>"))
  assert(feed.contains("<feed xmlns=\"http://www.w3.org/2005/Atom\">"))
  assert(feed.contains("<title>Empty Site</title>"))
  
  // Should have no entry elements
  assert(not(feed.contains("<entry>")))
}

///|
test "render_feed XML character escaping" {
  let pages = [
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
  
  // Check XML entities are properly escaped
  assert(feed.contains("&amp;"))
  assert(feed.contains("&lt;"))
  assert(feed.contains("&gt;"))
  assert(feed.contains("&quot;"))
  
  // Unescaped characters should not appear in content
  assert(not(feed.contains(" & ")))
  assert(not(feed.contains(" < ")))
  assert(not(feed.contains(" > ")))
  assert(not(feed.contains(" \" ")))
}

///|
test "render_feed respects limit parameter" {
  let pages = [
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
  
  // With limit, only include specified number of entries
  let limited_feed = @rss.render_feed("Test", "https://example.com", pages, Some(2))
  assert(limited_feed.contains("<title>Post 3</title>"))
  assert(limited_feed.contains("<title>Post 2</title>"))
  assert(not(limited_feed.contains("<title>Post 1</title>")))
  
  // Without limit (None), include all entries
  let full_feed = @rss.render_feed("Test", "https://example.com", pages, None)
  assert(full_feed.contains("<title>Post 3</title>"))
  assert(full_feed.contains("<title>Post 2</title>"))
  assert(full_feed.contains("<title>Post 1</title>"))
  
  // Limit larger than array size includes all entries
  let oversized_feed = @rss.render_feed("Test", "https://example.com", pages, Some(100))
  assert(oversized_feed.contains("<title>Post 1</title>"))
  assert(oversized_feed.contains("<title>Post 2</title>"))
  assert(oversized_feed.contains("<title>Post 3</title>"))
}

///|
test "render_feed with limit of 1" {
  let pages = test_pages()
  let feed = @rss.render_feed("Test", "https://example.com", pages, Some(1))
  
  // Only newest entry should be present
  assert(feed.contains("<title>Second Post</title>"))
  assert(not(feed.contains("<title>First Post</title>")))
  assert(not(feed.contains("<title>Third Post</title>")))
}
