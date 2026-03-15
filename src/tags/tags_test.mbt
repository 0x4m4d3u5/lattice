///|
/// Tests for tag extraction and rendering.

///|
test "tag_url generates correct URL" {
  let url = @tags.tag_url("my-tag")
  inspect(url, content="/tags/my-tag/")
}

///|
test "tag_url with special characters" {
  let url = @tags.tag_url("csharp")
  inspect(url, content="/tags/csharp/")
}

///|
test "extract tags from frontmatter with tags field" {
  let fm : @frontmatter.Frontmatter = {
    fields: Map::from_array([
      ("title", @frontmatter.FStr("Test Post")),
      ("tags", @frontmatter.FArray([
        @frontmatter.FStr("intro"),
        @frontmatter.FStr("lattice"),
        @frontmatter.FStr("demo")
      ]))
    ])
  }
  match @tags.extract(fm, "tags") {
    Ok(tag_refs) => {
      inspect(tag_refs.length(), content=3)
      inspect(tag_refs[0].value, content="intro")
      inspect(tag_refs[0].slug, content="intro")
      inspect(tag_refs[1].value, content="lattice")
      inspect(tag_refs[1].slug, content="lattice")
      inspect(tag_refs[2].value, content="demo")
      inspect(tag_refs[2].slug, content="demo")
    }
    Err(msg) => inspect(msg, content="unexpected error")
  }
}

///|
test "extract tags returns empty array when tags field missing" {
  let fm : @frontmatter.Frontmatter = {
    fields: Map::from_array([
      ("title", @frontmatter.FStr("Test Post"))
    ])
  }
  match @tags.extract(fm, "tags") {
    Ok(tag_refs) => {
      inspect(tag_refs.length(), content=0)
    }
    Err(msg) => inspect(msg, content="unexpected error")
  }
}

///|
test "extract tags with duplicate tags deduplicates" {
  let fm : @frontmatter.Frontmatter = {
    fields: Map::from_array([
      ("title", @frontmatter.FStr("Test Post")),
      ("tags", @frontmatter.FArray([
        @frontmatter.FStr("intro"),
        @frontmatter.FStr("intro"),
        @frontmatter.FStr("lattice")
      ]))
    ])
  }
  match @tags.extract(fm, "tags") {
    Ok(tag_refs) => {
      inspect(tag_refs.length(), content=2)
      inspect(tag_refs[0].value, content="intro")
      inspect(tag_refs[1].value, content="lattice")
    }
    Err(msg) => inspect(msg, content="unexpected error")
  }
}

///|
test "extract tags trims whitespace" {
  let fm : @frontmatter.Frontmatter = {
    fields: Map::from_array([
      ("title", @frontmatter.FStr("Test Post")),
      ("tags", @frontmatter.FArray([
        @frontmatter.FStr("  intro  "),
        @frontmatter.FStr("\tlattice\n"),
        @frontmatter.FStr("\r\n  demo  \r\n")
      ]))
    ])
  }
  match @tags.extract(fm, "tags") {
    Ok(tag_refs) => {
      inspect(tag_refs.length(), content=3)
      inspect(tag_refs[0].value, content="intro")
      inspect(tag_refs[1].value, content="lattice")
      inspect(tag_refs[2].value, content="demo")
    }
    Err(msg) => inspect(msg, content="unexpected error")
  }
}

///|
test "extract tags with empty strings skips empty tags" {
  let fm : @frontmatter.Frontmatter = {
    fields: Map::from_array([
      ("title", @frontmatter.FStr("Test Post")),
      ("tags", @frontmatter.FArray([
        @frontmatter.FStr("intro"),
        @frontmatter.FStr(""),
        @frontmatter.FStr("lattice"),
        @frontmatter.FStr("  "),
        @frontmatter.FStr("demo")
      ]))
    ])
  }
  match @tags.extract(fm, "tags") {
    Ok(tag_refs) => {
      inspect(tag_refs.length(), content=3)
      inspect(tag_refs[0].value, content="intro")
      inspect(tag_refs[1].value, content="lattice")
      inspect(tag_refs[2].value, content="demo")
    }
    Err(msg) => inspect(msg, content="unexpected error")
  }
}

///|
test "extract tags from non-array field returns error" {
  let fm : @frontmatter.Frontmatter = {
    fields: Map::from_array([
      ("title", @frontmatter.FStr("Test Post")),
      ("tags", @frontmatter.FStr("intro,lattice,demo"))
    ])
  }
  match @tags.extract(fm, "tags") {
    Ok(_) => inspect("expected error", content="")
    Err(msg) => {
      inspect(msg, content="expected Array[String]")
    }
  }
}

///|
test "extract tags with non-string element returns error" {
  let fm : @frontmatter.Frontmatter = {
    fields: Map::from_array([
      ("title", @frontmatter.FStr("Test Post")),
      ("tags", @frontmatter.FArray([
        @frontmatter.FStr("intro"),
        @frontmatter.FInt(42)
      ]))
    ])
  }
  match @tags.extract(fm, "tags") {
    Ok(_) => inspect("expected error", content="")
    Err(msg) => {
      inspect(msg, content="expected Array[String], found non-string element")
    }
  }
}

///|
test "render_page_tags with no tags returns empty string" {
  let tags : Array[@tags.TagRef] = []
  let html = @tags.render_page_tags(tags)
  inspect(html, content="")
}

///|
test "render_page_tags generates HTML links" {
  let tags : Array[@tags.TagRef] = [
    { value: "intro", slug: "intro" },
    { value: "lattice", slug: "lattice" },
    { value: "demo", slug: "demo" }
  ]
  let html = @tags.render_page_tags(tags)
  inspect(html.contains("<section>"), content=true)
  inspect(html.contains("<h2>Tags</h2>"), content=true)
  inspect(html.contains("<ul>"), content=true)
  inspect(html.contains("<li>"), content=true)
  inspect(html.contains("<a href=\"/tags/intro/\">intro</a>"), content=true)
  inspect(html.contains("<a href=\"/tags/lattice/\">lattice</a>"), content=true)
  inspect(html.contains("<a href=\"/tags/demo/\">demo</a>"), content=true)
  inspect(html.contains("</ul>"), content=true)
  inspect(html.contains("</section>"), content=true)
}

///|
test "render_tag_page generates correct HTML" {
  let page : @tags.TagPage = {
    tag: "lattice",
    slug: "lattice",
    pages: [
      { title: "Post 1", url: "/posts/post-1/", slug: "post-1" },
      { title: "Post 2", url: "/posts/post-2/", slug: "post-2" }
    ]
  }
  let html = @tags.render_tag_page(page)
  inspect(html.contains("<main>"), content=true)
  inspect(html.contains("<h1>Tag: lattice</h1>"), content=true)
  inspect(html.contains("<p>2 page(s)</p>"), content=true)
  inspect(html.contains("<ul>"), content=true)
  inspect(html.contains("<a href=\"/posts/post-1/\">Post 1</a>"), content=true)
  inspect(html.contains("<a href=\"/posts/post-2/\">Post 2</a>"), content=true)
  inspect(html.contains("<code>post-1</code>"), content=true)
  inspect(html.contains("<code>post-2</code>"), content=true)
  inspect(html.contains("</ul>"), content=true)
  inspect(html.contains("</main>"), content=true)
}

///|
test "render_tag_page with no pages shows count" {
  let page : @tags.TagPage = {
    tag: "empty-tag",
    slug: "empty-tag",
    pages: []
  }
  let html = @tags.render_tag_page(page)
  inspect(html.contains("<h1>Tag: empty-tag</h1>"), content=true)
  inspect(html.contains("<p>0 page(s)</p>"), content=true)
}

///|
test "render_tag_index generates correct HTML" {
  let index : @tags.TagIndex = {
    tags: [
      { tag: "lattice", slug: "lattice", count: 5 },
      { tag: "moonbit", slug: "moonbit", count: 3 },
      { tag: "demo", slug: "demo", count: 2 }
    ]
  }
  let html = @tags.render_tag_index(index)
  inspect(html.contains("<main>"), content=true)
  inspect(html.contains("<h1>Tags</h1>"), content=true)
  inspect(html.contains("<ul>"), content=true)
  inspect(html.contains("<a href=\"/tags/lattice/\">lattice</a>"), content=true)
  inspect(html.contains("<a href=\"/tags/moonbit/\">moonbit</a>"), content=true)
  inspect(html.contains("<a href=\"/tags/demo/\">demo</a>"), content=true)
  inspect(html.contains("(5)"), content=true)
  inspect(html.contains("(3)"), content=true)
  inspect(html.contains("(2)"), content=true)
  inspect(html.contains("</ul>"), content=true)
  inspect(html.contains("</main>"), content=true)
}

///|
test "render_tag_index with no tags shows message" {
  let index : @tags.TagIndex = {
    tags: []
  }
  let html = @tags.render_tag_index(index)
  inspect(html.contains("<main>"), content=true)
  inspect(html.contains("<h1>Tags</h1>"), content=true)
  inspect(html.contains("<p>No tags found.</p>"), content=true)
  inspect(html.contains("</main>"), content=true)
}

///|
test "tag extraction with slug normalization" {
  let fm : @frontmatter.Frontmatter = {
    fields: Map::from_array([
      ("title", @frontmatter.FStr("Test Post")),
      ("tags", @frontmatter.FArray([
        @frontmatter.FStr("C#"),
        @frontmatter.FStr("C++"),
        @frontmatter.FStr("WebAssembly")
      ]))
    ])
  }
  match @tags.extract(fm, "tags") {
    Ok(tag_refs) => {
      inspect(tag_refs.length(), content=3)
      // Slugs should be normalized by @slug.filename_to_slug
      inspect(tag_refs[0].value, content="C#")
      inspect(tag_refs[1].value, content="C++")
      inspect(tag_refs[2].value, content="WebAssembly")
    }
    Err(msg) => inspect(msg, content="unexpected error")
  }
}

///|
test "render_page_tags HTML escaping" {
  let tags : Array[@tags.TagRef] = [
    { value: "test & demo", slug: "test-demo" },
    { value: "<script>", slug: "script" }
  ]
  let html = @tags.render_page_tags(tags)
  // Tag values in link text should be HTML-escaped
  inspect(not(html.contains("test & demo")), content=true)
  inspect(html.contains("&amp;"), content=true)
  inspect(not(html.contains("<script>")), content=true)
  inspect(html.contains("&lt;"), content=true)
  // But URLs should not be double-escaped
  inspect(html.contains("href=\"/tags/test-demo/\""), content=true)
  inspect(html.contains("href=\"/tags/script/\""), content=true)
}

///|
test "render_tag_page HTML escaping" {
  let page : @tags.TagPage = {
    tag: "test & <tag>",
    slug: "test-tag",
    pages: [
      { title: "Post & Test", url: "/posts/test/", slug: "test" }
    ]
  }
  let html = @tags.render_tag_page(page)
  // Tag name in h1 should be escaped
  inspect(not(html.contains("test & <tag>")), content=true)
  inspect(html.contains("test &amp; &lt;tag&gt;"), content=true)
}

///|
test "render_tag_index HTML escaping" {
  let index : @tags.TagIndex = {
    tags: [
      { tag: "test & demo", slug: "test-demo", count: 1 }
    ]
  }
  let html = @tags.render_tag_index(index)
  // Tag names in links should be escaped
  inspect(not(html.contains("test & demo")), content=true)
  inspect(html.contains("&amp;"), content=true)
}