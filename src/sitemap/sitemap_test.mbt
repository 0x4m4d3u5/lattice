///|
/// Tests for sitemap.xml generation.

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
      slug: "index",
      title: "Home",
      url: "/",
      description: None,
      date: None,
      outgoing: [],
    },
  ]
}

///|
test "render_sitemap produces valid XML envelope" {
  let pages = test_pages()
  let xml = @sitemap.render_sitemap("https://example.com", pages)

  inspect(xml.contains("<?xml version=\"1.0\" encoding=\"utf-8\"?>"), content="true")
  inspect(
    xml.contains("<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">"),
    content="true",
  )
  inspect(xml.contains("</urlset>"), content="true")
}

///|
test "render_sitemap emits one url block per page" {
  let pages = test_pages()
  let xml = @sitemap.render_sitemap("https://example.com", pages)

  inspect(
    xml.contains("<loc>https://example.com/posts/first-post/</loc>"),
    content="true",
  )
  inspect(
    xml.contains("<loc>https://example.com/posts/second-post/</loc>"),
    content="true",
  )
  inspect(xml.contains("<loc>https://example.com/</loc>"), content="true")
}

///|
test "render_sitemap includes lastmod from frontmatter date" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "dated",
      title: "Dated Page",
      url: "/dated/",
      description: None,
      date: Some("2024-03-10"),
      outgoing: [],
    },
  ]
  let xml = @sitemap.render_sitemap("https://example.com", pages)

  inspect(xml.contains("<lastmod>2024-03-10</lastmod>"), content="true")
}

///|
test "render_sitemap omits lastmod when date is absent" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "no-date",
      title: "No Date",
      url: "/no-date/",
      description: None,
      date: None,
      outgoing: [],
    },
  ]
  let xml = @sitemap.render_sitemap("https://example.com", pages)

  inspect(not(xml.contains("<lastmod>")), content="true")
}

///|
test "render_sitemap accepts RFC3339 date in lastmod" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "rfc-page",
      title: "RFC3339 Page",
      url: "/rfc/",
      description: None,
      date: Some("2024-03-15T14:30:00Z"),
      outgoing: [],
    },
  ]
  let xml = @sitemap.render_sitemap("https://example.com", pages)

  inspect(
    xml.contains("<lastmod>2024-03-15T14:30:00Z</lastmod>"),
    content="true",
  )
}

///|
test "render_sitemap index page gets higher priority" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "index",
      title: "Home",
      url: "/",
      description: None,
      date: None,
      outgoing: [],
    },
    {
      slug: "about",
      title: "About",
      url: "/about/",
      description: None,
      date: None,
      outgoing: [],
    },
  ]
  let xml = @sitemap.render_sitemap("https://example.com", pages)

  inspect(xml.contains("<priority>0.8</priority>"), content="true")
  inspect(xml.contains("<priority>0.6</priority>"), content="true")
}

///|
test "render_sitemap includes changefreq for all entries" {
  let pages = test_pages()
  let xml = @sitemap.render_sitemap("https://example.com", pages)

  inspect(xml.contains("<changefreq>weekly</changefreq>"), content="true")
}

///|
test "render_sitemap handles empty pages array" {
  let pages : Array[@graph.GraphPage] = []
  let xml = @sitemap.render_sitemap("https://example.com", pages)

  inspect(xml.contains("<?xml version=\"1.0\" encoding=\"utf-8\"?>"), content="true")
  inspect(
    xml.contains("<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">"),
    content="true",
  )
  inspect(not(xml.contains("<url>")), content="true")
}

///|
test "render_sitemap XML-escapes special characters in URLs" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "escape",
      title: "Escape Test",
      url: "/search?q=a&b=c",
      description: None,
      date: None,
      outgoing: [],
    },
  ]
  let xml = @sitemap.render_sitemap("https://example.com", pages)

  inspect(xml.contains("&amp;"), content="true")
  inspect(not(xml.contains(" & ")), content="true")
}

///|
test "render_sitemap handles base URL with trailing slash" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "page",
      title: "Page",
      url: "/page/",
      description: None,
      date: Some("2024-01-01"),
      outgoing: [],
    },
  ]
  let xml1 = @sitemap.render_sitemap("https://example.com", pages)
  let xml2 = @sitemap.render_sitemap("https://example.com/", pages)

  inspect(xml1.contains("<loc>https://example.com/page/</loc>"), content="true")
  inspect(xml2.contains("<loc>https://example.com/page/</loc>"), content="true")
  inspect(xml1.contains("<lastmod>2024-01-01</lastmod>"), content="true")
}

///|
test "render_sitemap rejects malformed date" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "bad-date",
      title: "Bad Date",
      url: "/bad/",
      description: None,
      date: Some("not-a-date"),
      outgoing: [],
    },
  ]
  let xml = @sitemap.render_sitemap("https://example.com", pages)

  inspect(not(xml.contains("<lastmod>")), content="true")
}
