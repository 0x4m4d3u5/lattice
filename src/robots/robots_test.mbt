///|
/// Tests for robots.txt generation.

///|
test "render_robots_txt produces valid header" {
  let robots = @robots.render_robots_txt("https://example.com", true)

  inspect(robots.contains("User-agent: *"), content="true")
  inspect(robots.contains("Allow: /"), content="true")
}

///|
test "render_robots_txt includes sitemap directive with base_url" {
  let robots = @robots.render_robots_txt("https://example.com", true)

  inspect(
    robots.contains("Sitemap: https://example.com/sitemap.xml"),
    content="true",
  )
}

///|
test "render_robots_txt handles base_url with trailing slash" {
  let robots1 = @robots.render_robots_txt("https://example.com", true)
  let robots2 = @robots.render_robots_txt("https://example.com/", true)

  inspect(
    robots1.contains("Sitemap: https://example.com/sitemap.xml"),
    content="true",
  )
  inspect(
    robots2.contains("Sitemap: https://example.com/sitemap.xml"),
    content="true",
  )
  inspect(
    not(robots2.contains("https://example.com//sitemap.xml")),
    content="true",
  )
}

///|
test "render_robots_txt skips sitemap when base_url is empty" {
  let robots = @robots.render_robots_txt("", true)

  inspect(robots.contains("User-agent: *"), content="true")
  inspect(robots.contains("Allow: /"), content="true")
  inspect(not(robots.contains("Sitemap:")), content="true")
}

///|
test "render_robots_txt skips sitemap when base_url is just slash" {
  let robots = @robots.render_robots_txt("/", true)

  inspect(robots.contains("User-agent: *"), content="true")
  inspect(robots.contains("Allow: /"), content="true")
  inspect(not(robots.contains("Sitemap:")), content="true")
}

///|
test "render_robots_txt returns empty string when disabled" {
  let robots = @robots.render_robots_txt("https://example.com", false)

  inspect(robots.length(), content="0")
}

///|
test "render_robots_txt returns empty string when disabled even with base_url" {
  let robots = @robots.render_robots_txt("https://example.com/", false)

  inspect(robots.length(), content="0")
}

///|
test "render_robots_txt preserves newlines in correct order" {
  let robots = @robots.render_robots_txt("https://example.com", true)

  inspect(
    robots,
    content="User-agent: *\nAllow: /\nSitemap: https://example.com/sitemap.xml\n",
  )
}

///|
test "render_robots_txt handles http base_url" {
  let robots = @robots.render_robots_txt("http://example.org", true)

  inspect(
    robots.contains("Sitemap: http://example.org/sitemap.xml"),
    content="true",
  )
}

///|
test "render_robots_txt handles base_url with path" {
  let robots = @robots.render_robots_txt("https://example.com/blog", true)

  inspect(
    robots.contains("Sitemap: https://example.com/blog/sitemap.xml"),
    content="true",
  )
}
