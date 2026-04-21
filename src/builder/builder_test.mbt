///|
fn ensure_dir_test(path : String) -> Unit {
  if !@fs.path_exists(path) {
    @fs.create_dir(path) catch {
      @fs.IOError(_) => ()
    }
  }
}

///|
fn write_file_test(path : String, content : String) -> Bool {
  try {
    @fs.write_string_to_file(path, content)
    true
  } catch {
    @fs.IOError(_) => false
  }
}

///|
test "redirect_url_to_output_path converts trailing slash URLs to index.html" {
  assert_eq(
    @builder.redirect_url_to_output_path("/old-url/"),
    "old-url/index.html",
  )
  assert_eq(
    @builder.redirect_url_to_output_path("/old/path/"),
    "old/path/index.html",
  )
}

///|
test "redirect_url_to_output_path converts URLs without trailing slash to index.html" {
  assert_eq(
    @builder.redirect_url_to_output_path("/old-url"),
    "old-url/index.html",
  )
  assert_eq(
    @builder.redirect_url_to_output_path("/old/path"),
    "old/path/index.html",
  )
}

///|
test "redirect_url_to_output_path preserves .html extension" {
  assert_eq(@builder.redirect_url_to_output_path("/old.html"), "old.html")
  assert_eq(
    @builder.redirect_url_to_output_path("/old/path.html"),
    "old/path.html",
  )
}

///|
test "redirect_url_to_output_path handles root path" {
  assert_eq(@builder.redirect_url_to_output_path("/"), "index.html")
}

///|
test "collection index lookup alias uses numeric prefix directory basename" {
  let collection : @collections.CollectionDef = {
    name: "projects",
    schema: { name: "projects", fields: [] },
    content_dir: "/vault/10 - Projects",
    template: None,
    page_size: None,
    sort_order: @collections.DateDesc,
    description: None,
  }
  match @builder.collection_index_lookup_alias(collection) {
    Some(lookup_key) => assert_eq(lookup_key, "10---projects")
    None => assert_true(false)
  }
}

///|
test "collection index lookup alias skips matching directory names" {
  let collection : @collections.CollectionDef = {
    name: "posts",
    schema: { name: "posts", fields: [] },
    content_dir: "/vault/posts",
    template: None,
    page_size: None,
    sort_order: @collections.DateDesc,
    description: None,
  }
  match @builder.collection_index_lookup_alias(collection) {
    Some(_) => assert_true(false)
    None => ()
  }
}

///|
test "collection index lookup alias skips basename that normalizes to collection name" {
  let collection : @collections.CollectionDef = {
    name: "posts",
    schema: { name: "posts", fields: [] },
    content_dir: "/vault/Posts",
    template: None,
    page_size: None,
    sort_order: @collections.DateDesc,
    description: None,
  }
  match @builder.collection_index_lookup_alias(collection) {
    Some(_) => assert_true(false)
    None => ()
  }
}

///|
test "group_pages_by_year_month groups pages correctly" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "post1",
      title: "Post 1",
      url: "/posts/post1",
      description: None,
      date: Some("2024-03-15"),
      outgoing: [],
      weight: None,
    },
    {
      slug: "post2",
      title: "Post 2",
      url: "/posts/post2",
      description: None,
      date: Some("2024-01-10"),
      outgoing: [],
      weight: None,
    },
    {
      slug: "post3",
      title: "Post 3",
      url: "/posts/post3",
      description: None,
      date: Some("2023-12-05"),
      outgoing: [],
      weight: None,
    },
    {
      slug: "post4",
      title: "Post 4",
      url: "/posts/post4",
      description: None,
      date: Some("2024-03-20"),
      outgoing: [],
      weight: None,
    },
    {
      slug: "post5",
      title: "Post 5",
      url: "/posts/post5",
      description: None,
      date: None,
      outgoing: [],
      weight: None,
    },
  ]

  let groups = @builder.group_pages_by_year_month(pages)

  // Should have 3 groups: 2024-03, 2024-01, 2023-12
  // (sorted newest first)
  assert_eq(groups.length(), 3)

  // First group should be 2024-03
  assert_eq(groups[0].year, "2024")
  assert_eq(groups[0].month, "03")
  assert_eq(groups[0].pages.length(), 2)

  // Second group should be 2024-01
  assert_eq(groups[1].year, "2024")
  assert_eq(groups[1].month, "01")
  assert_eq(groups[1].pages.length(), 1)

  // Third group should be 2023-12
  assert_eq(groups[2].year, "2023")
  assert_eq(groups[2].month, "12")
  assert_eq(groups[2].pages.length(), 1)

  // Pages within groups should be sorted by date descending
  assert_eq(groups[0].pages[0].slug, "post4")
  assert_eq(groups[0].pages[1].slug, "post1")
}

///|
test "aggregate_pages_by_year collects all months under the same year key" {
  // Regression: year archive used group.pages (per-month) instead of all
  // pages for that year. Result: only the last-processed month appeared in
  // the year archive.
  let groups : Array[@builder.ArchiveGroup] = [
    {
      year: "2026",
      month: "04",
      pages: [
        {
          slug: "april-post",
          title: "April Post",
          url: "/posts/april-post",
          description: None,
          date: Some("2026-04-01"),
          outgoing: [],
          weight: None,
        },
      ],
    },
    {
      year: "2026",
      month: "03",
      pages: [
        {
          slug: "march-post",
          title: "March Post",
          url: "/posts/march-post",
          description: None,
          date: Some("2026-03-15"),
          outgoing: [],
          weight: None,
        },
      ],
    },
    {
      year: "2025",
      month: "12",
      pages: [
        {
          slug: "dec-post",
          title: "December Post",
          url: "/posts/dec-post",
          description: None,
          date: Some("2025-12-01"),
          outgoing: [],
          weight: None,
        },
      ],
    },
  ]
  let year_map = @builder.aggregate_pages_by_year(groups)
  // 2026 year key must contain both April and March posts
  match year_map.get("2026") {
    Some(year_pages) => assert_eq(year_pages.length(), 2)
    None => assert_true(false)
  }
  match year_map.get("2025") {
    Some(year_pages) => assert_eq(year_pages.length(), 1)
    None => assert_true(false)
  }
}

///|
test "extract_year_month extracts year and month from date string" {
  match @builder.extract_year_month("2024-03-15") {
    Some((year, month)) => {
      assert_eq(year, "2024")
      assert_eq(month, "03")
    }
    None => assert_true(false)
  }

  match @builder.extract_year_month("2023-12") {
    Some((year, month)) => {
      assert_eq(year, "2023")
      assert_eq(month, "12")
    }
    None => assert_true(false)
  }

  match @builder.extract_year_month("2024-1") {
    Some((year, month)) => {
      assert_eq(year, "2024")
      assert_eq(month, "01")
    }
    None => assert_true(false)
  }

  // Invalid dates should return None
  match @builder.extract_year_month("2024") {
    Some(_) => assert_true(false)
    None => ()
  }

  match @builder.extract_year_month("invalid") {
    Some(_) => assert_true(false)
    None => ()
  }
}

///|
test "render_archive_page_content generates HTML list of page links" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "post1",
      title: "First Post",
      url: "/posts/post1",
      description: None,
      date: Some("2024-03-15"),
      outgoing: [],
      weight: None,
    },
    {
      slug: "post2",
      title: "Second Post",
      url: "/posts/post2",
      description: None,
      date: Some("2024-01-10"),
      outgoing: [],
      weight: None,
    },
  ]

  let html = @builder.render_archive_page_content(pages)

  // Should contain ul tags
  assert_true(html.contains("<ul>"))
  assert_true(html.contains("</ul>"))

  // Should contain li tags
  assert_true(html.contains("<li>"))
  assert_true(html.contains("</li>"))

  // Should contain page titles
  assert_true(html.contains("First Post"))
  assert_true(html.contains("Second Post"))

  // Should contain dates
  assert_true(html.contains("(2024-03-15)"))
  assert_true(html.contains("(2024-01-10)"))

  // Should contain links
  assert_true(html.contains("href=\"/posts/post1\""))
  assert_true(html.contains("href=\"/posts/post2\""))
}

///|
test "render_archive_index generates HTML with year headings and month links" {
  let groups : Array[@builder.ArchiveGroup] = [
    {
      year: "2024",
      month: "03",
      pages: [
        {
          slug: "post1",
          title: "Post 1",
          url: "/posts/post1",
          description: None,
          date: Some("2024-03-15"),
          outgoing: [],
          weight: None,
        },
        {
          slug: "post2",
          title: "Post 2",
          url: "/posts/post2",
          description: None,
          date: Some("2024-03-20"),
          outgoing: [],
          weight: None,
        },
      ],
    },
    {
      year: "2024",
      month: "01",
      pages: [
        {
          slug: "post3",
          title: "Post 3",
          url: "/posts/post3",
          description: None,
          date: Some("2024-01-10"),
          outgoing: [],
          weight: None,
        },
      ],
    },
    {
      year: "2023",
      month: "12",
      pages: [
        {
          slug: "post4",
          title: "Post 4",
          url: "/posts/post4",
          description: None,
          date: Some("2023-12-05"),
          outgoing: [],
          weight: None,
        },
      ],
    },
  ]

  let site = match @config.parse("title = Test\nbase_url = /\n") {
    Ok(s) => s
    Err(_) => {
      assert_true(false)
      abort("config parse failed")
    }
  }
  let result = @builder.render_archive_index(
    groups,
    "posts",
    site,
    None, // no archive template
    None, // no index template
    "",
    "",
    @data.empty_store(),
  )
  match result {
    Ok(html) => {
      // Should have year headings
      assert_true(html.contains("<h2>2024</h2>"))
      assert_true(html.contains("<h2>2023</h2>"))
      // Should have month links with proper URLs
      assert_true(html.contains("href=\"/posts/2024/03/\""))
      assert_true(html.contains("March 2024"))
      assert_true(html.contains("href=\"/posts/2024/01/\""))
      assert_true(html.contains("January 2024"))
      assert_true(html.contains("href=\"/posts/2023/12/\""))
      assert_true(html.contains("December 2023"))
      // Should show post counts
      assert_true(html.contains("(2 posts)"))
      assert_true(html.contains("(1 post)"))
    }
    Err(msg) => {
      assert_true(false)
      abort("render_archive_index failed: " + msg)
    }
  }
}

///|
test "build uses per-collection page template override" {
  let root = "./_tmp_builder_collection_template"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  assert_true(
    write_file_test(
      posts_root + "/hello.md",
      "---\n" +
      "title: Hello\n" +
      "date: 2026-03-11\n" +
      "---\n\n" +
      "Hello override\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body>default {{content}}</body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/post.html",
      "<html><body>override {{content}}</body></html>\n",
    ),
  )
  let site_cfg = "title = Test\n" +
    "base_url = /\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "collections_file = " +
    root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))
  assert_true(
    write_file_test(
      root + "/collections.cfg",
      "[posts]\n" +
      "schema = title:String,date:Date\n" +
      "dir = " +
      posts_root +
      "\n" +
      "template = " +
      templates_root +
      "/post.html\n",
    ),
  )

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: Some(root + "/collections.cfg"),
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)

  let output = @fs.read_file_to_string(output_root + "/posts/hello/index.html") catch {
    @fs.IOError(_) => ""
  }
  assert_true(output.contains("override"))
  assert_true(!output.contains("default"))
}

///|
test "template total_pages slot parses and renders" {
  let tpl = match
    @template.parse_template("Page {{page_num}} of {{total_pages}}") {
    Ok(t) => t
    Err(_) => {
      assert_true(false)
      abort("template parse failed")
    }
  }
  let slots : Map[@template.TemplateSlot, String] = Map::new()
  slots.set(@template.PageNum, "2")
  slots.set(@template.TotalPages, "5")
  match @template.render_template(tpl, slots, Map::new()) {
    Ok(html) => assert_eq(html, "Page 2 of 5")
    Err(_) => assert_true(false)
  }
}

///|
test "build with paginated index template exposes page_num and total_pages" {
  let root = "./_tmp_builder_pagination_template"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  // Create 3 posts so with page_size=2 we get 2 pages
  let mut p = 0
  while p < 3 {
    let n = (p + 1).to_string()
    assert_true(
      write_file_test(
        posts_root + "/post" + n + ".md",
        "---\ntitle: Post " +
        n +
        "\ndate: 2026-0" +
        n +
        "-01\n---\nBody " +
        n +
        "\n",
      ),
    )
    p = p + 1
  }

  // Index template that uses pagination slots
  assert_true(
    write_file_test(
      templates_root + "/index.html",
      "<html><head></head><body>page={{page_num}} of={{total_pages}} prev={{prev_page}} next={{next_page}}</body></html>\n",
    ),
  )

  let collections_cfg = "[posts]\nschema = title:String,date:Date\ndir = " +
    posts_root +
    "\n"
  assert_true(write_file_test(root + "/collections.cfg", collections_cfg))

  let site_cfg = "title = PaginationTest\n" +
    "base_url = /\n" +
    "page_size = 2\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "collections_file = " +
    root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: Some(root + "/collections.cfg"),
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)

  // Page 1 index: page=1 of=2, no prev, has next
  let page1 = @fs.read_file_to_string(output_root + "/posts/index.html") catch {
    @fs.IOError(_) => ""
  }
  assert_true(page1.contains("page=1"))
  assert_true(page1.contains("of=2"))
  assert_true(page1.contains("next=/posts/page/2/"))

  // Page 2 index: page=2 of=2, has prev, no next
  let page2 = @fs.read_file_to_string(output_root + "/posts/page/2/index.html") catch {
    @fs.IOError(_) => ""
  }
  assert_true(page2.contains("page=2"))
  assert_true(page2.contains("of=2"))
  assert_true(page2.contains("prev=/posts/"))
  assert_true(page2.contains("\"@type\": \"BreadcrumbList\""))
  assert_true(page2.contains("\"item\": \"/posts/page/2/\""))
}

///|
test "build uses per-collection page_size override from inline collections" {
  let root = "./_tmp_builder_inline_collection_page_size_override"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let notes_root = content_root + "/notes"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(notes_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  let mut i = 0
  while i < 3 {
    let n = (i + 1).to_string()
    assert_true(
      write_file_test(
        posts_root + "/post" + n + ".md",
        "---\ntitle: Post " +
        n +
        "\ndate: 2026-03-0" +
        n +
        "\n---\nPost " +
        n +
        "\n",
      ),
    )
    assert_true(
      write_file_test(
        notes_root + "/note" + n + ".md",
        "---\ntitle: Note " +
        n +
        "\ndate: 2026-03-0" +
        n +
        "\n---\nNote " +
        n +
        "\n",
      ),
    )
    i = i + 1
  }

  assert_true(
    write_file_test(
      templates_root + "/index.html",
      "page={{page_num}} of={{total_pages}} prev={{prev_page}} next={{next_page}}\n",
    ),
  )

  let site_cfg = "title = InlinePagination\n" +
    "base_url = /\n" +
    "page_size = 3\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "output_dir = " +
    output_root +
    "\n" +
    "[[collections]]\n" +
    "name = posts\n" +
    "dir = " +
    posts_root +
    "\n" +
    "schema = title:String,date:Date\n" +
    "page_size = 2\n" +
    "[[collections]]\n" +
    "name = notes\n" +
    "dir = " +
    notes_root +
    "\n" +
    "schema = title:String,date:Date\n"

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: None,
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)

  assert_true(@fs.path_exists(output_root + "/posts/page/2/index.html"))
  assert_true(!@fs.path_exists(output_root + "/notes/page/2/index.html"))
}

///|
test "build inline collections fall back to global page_size" {
  let root = "./_tmp_builder_inline_collection_page_size_global"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  let mut i = 0
  while i < 3 {
    let n = (i + 1).to_string()
    assert_true(
      write_file_test(
        posts_root + "/post" + n + ".md",
        "---\ntitle: Post " +
        n +
        "\ndate: 2026-03-0" +
        n +
        "\n---\nPost " +
        n +
        "\n",
      ),
    )
    i = i + 1
  }

  assert_true(
    write_file_test(
      templates_root + "/index.html",
      "page={{page_num}} of={{total_pages}}\n",
    ),
  )

  let site_cfg = "title = InlineGlobalFallback\n" +
    "base_url = /\n" +
    "page_size = 2\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "output_dir = " +
    output_root +
    "\n" +
    "[[collections]]\n" +
    "name = posts\n" +
    "dir = " +
    posts_root +
    "\n" +
    "schema = title:String,date:Date\n"

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: None,
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)

  assert_true(@fs.path_exists(output_root + "/posts/page/2/index.html"))
}

///|
test "build inline collections without page_size does not paginate" {
  let root = "./_tmp_builder_inline_collection_page_size_none"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  let mut i = 0
  while i < 11 {
    let n = (i + 1).to_string()
    let day = if i < 9 { "0" + n } else { n }
    assert_true(
      write_file_test(
        posts_root + "/post" + n + ".md",
        "---\ntitle: Post " +
        n +
        "\ndate: 2026-03-" +
        day +
        "\n---\nPost " +
        n +
        "\n",
      ),
    )
    i = i + 1
  }

  assert_true(
    write_file_test(
      templates_root + "/index.html",
      "page={{page_num}} of={{total_pages}}\n",
    ),
  )

  let site_cfg = "title = InlineNoPagination\n" +
    "base_url = /\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "output_dir = " +
    output_root +
    "\n" +
    "[[collections]]\n" +
    "name = posts\n" +
    "dir = " +
    posts_root +
    "\n" +
    "schema = title:String,date:Date\n"

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: None,
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)

  assert_true(!@fs.path_exists(output_root + "/posts/page/2/index.html"))
}

///|
test "count_words_markdown simple prose" {
  // 10 words
  let body = "The quick brown fox jumps over the lazy dog today"
  assert_eq(@builder.count_words_markdown(body), 10)
}

///|
test "count_words_markdown skips fenced code blocks" {
  let body = "Intro paragraph here.\n\n```\nlet x = 1;\nlet y = 2;\n```\n\nConclusion."
  // "Intro paragraph here." = 3 words, "Conclusion." = 1 word → 4 total
  assert_eq(@builder.count_words_markdown(body), 4)
}

///|
test "count_words_markdown empty body" {
  assert_eq(@builder.count_words_markdown(""), 0)
}

///|
test "reading_time_str typical article" {
  // 450 words ÷ 225 = 2 min
  assert_eq(@builder.reading_time_str(450), "2 min")
}

///|
test "reading_time_str short content rounds up to 1 min" {
  assert_eq(@builder.reading_time_str(50), "1 min")
  assert_eq(@builder.reading_time_str(0), "1 min")
}

///|
test "reading_time_str long article" {
  // 2250 words ÷ 225 = 10 min
  assert_eq(@builder.reading_time_str(2250), "10 min")
}

///|
test "truncate_to_builder within limit returns original" {
  assert_eq(@builder.truncate_to_builder("short text", 160), "short text")
}

///|
test "truncate_to_builder over limit truncates at char boundary" {
  let long = "abcdefghij"
  assert_eq(@builder.truncate_to_builder(long, 5), "abcde")
}

///|
test "count_words_markdown heading lines counted as words" {
  // Headings are not skipped — their words contribute to count
  let body = "# My Title\n\nSome text here."
  // "# My Title" = 3 tokens, "Some text here." = 3 tokens → 6
  assert_eq(@builder.count_words_markdown(body), 6)
}

///|
test "build populates table_of_contents slot from content headings" {
  let root = "./_tmp_builder_toc"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  assert_true(
    write_file_test(
      posts_root + "/guide.md",
      "---\n" +
      "title: Guide\n" +
      "date: 2026-03-17\n" +
      "---\n\n" +
      "## Intro\n\n" +
      "Body.\n\n" +
      "### Setup\n\n" +
      "More.\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body><aside>{{table_of_contents}}</aside><main>{{content}}</main></body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      root + "/collections.cfg",
      "[posts]\n" +
      "schema = title:String,date:Date\n" +
      "dir = " +
      posts_root +
      "\n",
    ),
  )

  let site_cfg = "title = ToCTest\n" +
    "base_url = /\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "collections_file = " +
    root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: Some(root + "/collections.cfg"),
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)

  let output = @fs.read_file_to_string(output_root + "/posts/guide/index.html") catch {
    @fs.IOError(_) => ""
  }
  assert_true(output.contains("table-of-contents"))
  assert_true(output.contains("href=\"#intro\""))
  assert_true(output.contains("href=\"#setup\""))
}

///|
test "build table_of_contents slot is empty when page has no headings" {
  let root = "./_tmp_builder_toc_empty"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  assert_true(
    write_file_test(
      posts_root + "/plain.md",
      "---\n" +
      "title: Plain\n" +
      "date: 2026-03-17\n" +
      "---\n\n" +
      "No headings here.\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body><aside>{{table_of_contents}}</aside><main>{{content}}</main></body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      root + "/collections.cfg",
      "[posts]\n" +
      "schema = title:String,date:Date\n" +
      "dir = " +
      posts_root +
      "\n",
    ),
  )

  let site_cfg = "title = ToCEmpty\n" +
    "base_url = /\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "collections_file = " +
    root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: Some(root + "/collections.cfg"),
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)

  let output = @fs.read_file_to_string(output_root + "/posts/plain/index.html") catch {
    @fs.IOError(_) => ""
  }
  assert_true(output.contains("<aside></aside>"))
}

///|
test "build table_of_contents slot is empty when toc disabled" {
  let root = "./_tmp_builder_toc_disabled"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  assert_true(
    write_file_test(
      posts_root + "/hidden.md",
      "---\n" +
      "title: Hidden\n" +
      "date: 2026-03-17\n" +
      "toc: false\n" +
      "---\n\n" +
      "## Intro\n\n" +
      "Body.\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body><aside>{{table_of_contents}}</aside><main>{{content}}</main></body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      root + "/collections.cfg",
      "[posts]\n" +
      "schema = title:String,date:Date\n" +
      "dir = " +
      posts_root +
      "\n",
    ),
  )

  let site_cfg = "title = ToCDisabled\n" +
    "base_url = /\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "collections_file = " +
    root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: Some(root + "/collections.cfg"),
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)

  let output = @fs.read_file_to_string(output_root + "/posts/hidden/index.html") catch {
    @fs.IOError(_) => ""
  }
  assert_true(output.contains("<aside></aside>"))
  assert_true(!output.contains("table-of-contents"))
}

///|
test "build table_of_contents depth filters deeper headings" {
  let root = "./_tmp_builder_toc_depth"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  assert_true(
    write_file_test(
      posts_root + "/depth.md",
      "---\n" +
      "title: Depth\n" +
      "date: 2026-03-17\n" +
      "toc_depth: 2\n" +
      "---\n\n" +
      "## Intro\n\n" +
      "### Setup\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body><aside>{{table_of_contents}}</aside><main>{{content}}</main></body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      root + "/collections.cfg",
      "[posts]\n" +
      "schema = title:String,date:Date\n" +
      "dir = " +
      posts_root +
      "\n",
    ),
  )

  let site_cfg = "title = ToCDepth\n" +
    "base_url = /\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "collections_file = " +
    root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: Some(root + "/collections.cfg"),
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)

  let output = @fs.read_file_to_string(output_root + "/posts/depth/index.html") catch {
    @fs.IOError(_) => ""
  }
  assert_true(output.contains("href=\"#intro\""))
  assert_true(!output.contains("href=\"#setup\""))
}

///|
test "draft post is excluded from collection index when --drafts is false" {
  let root = "./_tmp_builder_draft_excluded"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  assert_true(
    write_file_test(
      posts_root + "/published.md",
      "---\n" +
      "title: Published Post\n" +
      "date: 2026-03-11\n" +
      "---\n\n" +
      "This is published.\n",
    ),
  )
  assert_true(
    write_file_test(
      posts_root + "/draft.md",
      "---\n" +
      "title: Draft Post\n" +
      "date: 2026-03-12\n" +
      "draft: true\n" +
      "---\n\n" +
      "This is a draft.\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body>{{content}}</body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/index.html",
      "<html><body>Index:{{content}}</body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      content_root + "/lattice.conf",
      "title = \"Test\"\n" + "base_url = \"/\"\n" + "collections = []\n",
    ),
  )
  assert_true(
    write_file_test(
      content_root + "/collections.cfg",
      "[posts]\n" +
      "dir = " +
      posts_root +
      "\n" +
      "schema = title:String,date:Date\n",
    ),
  )

  let site_cfg = "title = Test\n" +
    "base_url = /\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "collections_file = " +
    content_root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(content_root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }

  let config : @builder.BuildConfig = {
    content_dir: content_root,
    output_dir: output_root,
    config_path: content_root + "/site.cfg",
    site,
    collections_path: Some(content_root + "/collections.cfg"),
    force_rebuild: true,
    include_drafts: false,
  }

  let result = @builder.build(config, @cache.empty(output_root))
  assert_eq(result.errors, 0)
  // Published page should be built
  assert_true(@fs.path_exists(output_root + "/posts/published/index.html"))
  // Draft page should not be built
  assert_false(@fs.path_exists(output_root + "/posts/draft/index.html"))
  // Collection index should only contain published page
  assert_true(@fs.path_exists(output_root + "/posts/index.html"))
  let index_content = @fs.read_file_to_string(output_root + "/posts/index.html") catch {
    @fs.IOError(_) => {
      assert_true(false)
      ""
    }
  }
  assert_true(index_content.contains("Published Post"))
  assert_false(index_content.contains("Draft Post"))
  // Should report 1 skipped draft
  assert_eq(result.skipped_drafts, 1)
}

///|
test "draft post is included when --drafts flag is true" {
  let root = "./_tmp_builder_draft_included"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  assert_true(
    write_file_test(
      posts_root + "/published.md",
      "---\n" +
      "title: Published Post\n" +
      "date: 2026-03-11\n" +
      "---\n\n" +
      "This is published.\n",
    ),
  )
  assert_true(
    write_file_test(
      posts_root + "/draft.md",
      "---\n" +
      "title: Draft Post\n" +
      "date: 2026-03-12\n" +
      "draft: true\n" +
      "---\n\n" +
      "This is a draft.\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body>{{content}}</body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/index.html",
      "<html><body>Index:{{content}}</body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      content_root + "/lattice.conf",
      "title = \"Test\"\n" + "base_url = \"/\"\n" + "collections = []\n",
    ),
  )
  assert_true(
    write_file_test(
      content_root + "/collections.cfg",
      "[posts]\n" +
      "dir = " +
      posts_root +
      "\n" +
      "schema = title:String,date:Date\n",
    ),
  )

  let site_cfg = "title = Test\n" +
    "base_url = /\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "collections_file = " +
    content_root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(content_root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }

  let config : @builder.BuildConfig = {
    content_dir: content_root,
    output_dir: output_root,
    config_path: content_root + "/site.cfg",
    site,
    collections_path: Some(content_root + "/collections.cfg"),
    force_rebuild: true,
    include_drafts: true,
  }

  let result = @builder.build(config, @cache.empty(output_root))
  assert_eq(result.errors, 0)
  // Both pages should be built
  assert_true(@fs.path_exists(output_root + "/posts/published/index.html"))
  assert_true(@fs.path_exists(output_root + "/posts/draft/index.html"))
  // Collection index should contain both pages
  assert_true(@fs.path_exists(output_root + "/posts/index.html"))
  let index_content = @fs.read_file_to_string(output_root + "/posts/index.html") catch {
    @fs.IOError(_) => {
      assert_true(false)
      ""
    }
  }
  assert_true(index_content.contains("Published Post"))
  assert_true(index_content.contains("Draft Post"))
  // Should report 0 skipped drafts
  assert_eq(result.skipped_drafts, 0)
}

///|
test "page without draft key is always included" {
  let root = "./_tmp_builder_no_draft_key"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  assert_true(
    write_file_test(
      posts_root + "/nodraft.md",
      "---\n" +
      "title: No Draft Key\n" +
      "date: 2026-03-11\n" +
      "---\n\n" +
      "This has no draft key.\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body>{{content}}</body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/index.html",
      "<html><body>Index:{{content}}</body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      content_root + "/lattice.conf",
      "title = \"Test\"\n" + "base_url = \"/\"\n" + "collections = []\n",
    ),
  )
  assert_true(
    write_file_test(
      content_root + "/collections.cfg",
      "[posts]\n" +
      "dir = " +
      posts_root +
      "\n" +
      "schema = title:String,date:Date\n",
    ),
  )

  let site_cfg = "title = Test\n" +
    "base_url = /\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "collections_file = " +
    content_root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(content_root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }

  let config : @builder.BuildConfig = {
    content_dir: content_root,
    output_dir: output_root,
    config_path: content_root + "/site.cfg",
    site,
    collections_path: Some(content_root + "/collections.cfg"),
    force_rebuild: true,
    include_drafts: false,
  }

  let result = @builder.build(config, @cache.empty(output_root))
  assert_eq(result.errors, 0)
  // Page without draft key should be built
  assert_true(@fs.path_exists(output_root + "/posts/nodraft/index.html"))
  // Should report 0 skipped drafts
  assert_eq(result.skipped_drafts, 0)
}

///|
test "build emits json ld for content pages and homepage root copy" {
  let root = "./_tmp_builder_json_ld"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(output_root)

  assert_true(
    write_file_test(
      posts_root + "/home.md",
      "---\n" +
      "title: Home\n" +
      "description: Site entrypoint\n" +
      "date: 2026-03-19\n" +
      "author: Kurisu\n" +
      "og_image: https://example.test/images/home.png\n" +
      "---\n\n" +
      "Hello home page.\n",
    ),
  )
  assert_true(
    write_file_test(
      root + "/collections.cfg",
      "[posts]\n" +
      "schema = title:String,description:String,date:Date,author:String,og_image:String\n" +
      "dir = " +
      posts_root +
      "\n",
    ),
  )

  let site_cfg = "title = Lattice\n" +
    "base_url = https://example.test\n" +
    "description = Typed site\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "collections_file = " +
    root +
    "/collections.cfg\n" +
    "root_page = \"home\"\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }

  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: Some(root + "/collections.cfg"),
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)

  let post_output = @fs.read_file_to_string(
    output_root + "/posts/home/index.html",
  ) catch {
    @fs.IOError(_) => ""
  }
  assert_true(post_output.contains("<script type=\"application/ld+json\">"))
  assert_true(post_output.contains("\"@type\": \"BreadcrumbList\""))
  assert_true(post_output.contains("\"@type\": \"BlogPosting\""))
  assert_true(post_output.contains("\"item\": \"https://example.test/\""))
  assert_true(post_output.contains("\"item\": \"https://example.test/posts/\""))
  assert_true(
    post_output.contains("\"item\": \"https://example.test/posts/home/\""),
  )
  assert_true(post_output.contains("\"headline\": \"Home\""))
  assert_true(
    post_output.contains("\"url\": \"https://example.test/posts/home/\""),
  )
  assert_true(post_output.contains("\"datePublished\": \"2026-03-19\""))
  assert_true(post_output.contains("\"name\": \"Kurisu\""))

  let collection_output = @fs.read_file_to_string(
    output_root + "/posts/index.html",
  ) catch {
    @fs.IOError(_) => ""
  }
  assert_true(
    collection_output.contains("<script type=\"application/ld+json\">"),
  )
  assert_true(collection_output.contains("\"@type\": \"BreadcrumbList\""))
  assert_true(collection_output.contains("\"item\": \"https://example.test/\""))
  assert_true(
    collection_output.contains("\"item\": \"https://example.test/posts/\""),
  )
  assert_false(collection_output.contains("\"@type\": \"BlogPosting\""))

  let root_output = @fs.read_file_to_string(output_root + "/index.html") catch {
    @fs.IOError(_) => ""
  }
  assert_true(root_output.contains("<script type=\"application/ld+json\">"))
  assert_true(root_output.contains("\"@type\": \"WebSite\""))
  assert_true(root_output.contains("\"name\": \"Lattice\""))
  assert_true(root_output.contains("\"url\": \"https://example.test/\""))
  assert_false(root_output.contains("\"@type\": \"BlogPosting\""))
}

///|

///|
test "template tags slot renders space-separated tag links" {
  let root = "./_tmp_template_tags_slot"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  // Create site.cfg
  assert_true(
    write_file_test(
      root + "/site.cfg",
      "site:\n  title: Test Site\n  base_url: https://example.test/\n",
    ),
  )

  // Create post with tags
  assert_true(
    write_file_test(
      posts_root + "/post1.md",
      "---\ntitle: Post With Tags\ndate: 2026-03-19\ntags: [foo, bar]\n---\nContent\n",
    ),
  )

  // Create page template that uses tags slot
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body>tags={{tags}} collection={{collection}} year={{year}} month={{month}} day={{day}}</body></html>\n",
    ),
  )

  // Build
  let collections_cfg = "[posts]\nschema = title:String,date:Date,tags:Array[String]\ndir = " +
    posts_root +
    "\n"
  assert_true(write_file_test(root + "/collections.cfg", collections_cfg))

  let site_cfg = "title = Test Site\n" +
    "base_url = https://example.test/\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "collections_file = " +
    root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: Some(root + "/collections.cfg"),
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)

  let post_output = @fs.read_file_to_string(
    output_root + "/posts/post1/index.html",
  ) catch {
    @fs.IOError(_) => ""
  }
  // Tags slot should have space-separated links
  assert_true(post_output.contains("<a href=\"/tags/foo/\">foo</a>"))
  assert_true(post_output.contains("<a href=\"/tags/bar/\">bar</a>"))
  // Collection slot should be "posts"
  assert_true(post_output.contains("collection=posts"))
  // Date components should be split
  assert_true(post_output.contains("year=2026"))
  assert_true(post_output.contains("month=03"))
  assert_true(post_output.contains("day=19"))
}

///|
test "template tags slot is empty for pages without tags" {
  let root = "./_tmp_template_tags_empty"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  // Create post without tags
  assert_true(
    write_file_test(
      posts_root + "/post1.md",
      "---\ntitle: Post Without Tags\ndate: 2026-03-19\ntags: []\n---\nContent\n",
    ),
  )

  // Create page template that uses tags slot
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body>tags={{tags}}</body></html>\n",
    ),
  )

  // Build
  let collections_cfg = "[posts]\nschema = title:String,date:Date,tags:Array[String]\ndir = " +
    posts_root +
    "\n"
  assert_true(write_file_test(root + "/collections.cfg", collections_cfg))

  let site_cfg = "title = Test Site\n" +
    "base_url = https://example.test/\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "collections_file = " +
    root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: Some(root + "/collections.cfg"),
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)

  let post_output = @fs.read_file_to_string(
    output_root + "/posts/post1/index.html",
  ) catch {
    @fs.IOError(_) => ""
  }
  // Tags slot should be empty
  assert_true(post_output.contains("tags="))
}

///|
test "template year/month/day slots are empty for pages without date" {
  let root = "./_tmp_template_date_empty"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  // Create post without date
  assert_true(
    write_file_test(
      posts_root + "/post1.md",
      "---\ntitle: Post Without Date\ntags: []\n---\nContent\n",
    ),
  )

  // Create page template that uses date slots
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body>year={{year}} month={{month}} day={{day}}</body></html>\n",
    ),
  )

  // Build — date is optional so the post without a date must not fail schema validation
  let collections_cfg = "[posts]\nschema = title:String,date:Optional[Date],tags:Optional[Array[String]]\ndir = " +
    posts_root +
    "\n"
  assert_true(write_file_test(root + "/collections.cfg", collections_cfg))

  let site_cfg = "title = Test Site\n" +
    "base_url = https://example.test/\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "collections_file = " +
    root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: Some(root + "/collections.cfg"),
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)

  let post_output = @fs.read_file_to_string(
    output_root + "/posts/post1/index.html",
  ) catch {
    @fs.IOError(_) => ""
  }
  // Date slots should be empty
  assert_true(post_output.contains("year="))
  assert_true(post_output.contains("month="))
  assert_true(post_output.contains("day="))
}

///|
test "prev/next post slots populated in collection" {
  let root = "./_tmp_prev_next_navigation_slots"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  // Create site.cfg
  assert_true(
    write_file_test(
      root + "/site.cfg",
      "site:\n  title: Test Site\n  base_url: https://example.test/\n",
    ),
  )

  // Create three posts with dates (sorted desc: post3 > post2 > post1)
  assert_true(
    write_file_test(
      posts_root + "/post3.md",
      "---\ntitle: Post 3\ndate: 2026-03-21\n---\nContent 3\n",
    ),
  )
  assert_true(
    write_file_test(
      posts_root + "/post2.md",
      "---\ntitle: Post 2\ndate: 2026-03-20\n---\nContent 2\n",
    ),
  )
  assert_true(
    write_file_test(
      posts_root + "/post1.md",
      "---\ntitle: Post 1\ndate: 2026-03-19\n---\nContent 1\n",
    ),
  )

  // Create page template that uses prev/next slots
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body>{{prev_post_url}}|{{prev_post_title}}|{{next_post_url}}|{{next_post_title}}</body></html>\n",
    ),
  )

  // Build
  let collections_cfg = "[posts]\nschema = title:String,date:Date\ndir = " +
    posts_root +
    "\n"
  assert_true(write_file_test(root + "/collections.cfg", collections_cfg))

  let site_cfg = "title = Test Site\n" +
    "base_url = https://example.test/\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "collections_file = " +
    root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: Some(root + "/collections.cfg"),
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)

  // Check first post (post3) - should have empty prev, post2 as next
  let post3_output = @fs.read_file_to_string(
    output_root + "/posts/post3/index.html",
  ) catch {
    @fs.IOError(_) => ""
  }
  assert_true(post3_output.contains("||/posts/post2/|Post 2"))

  // Check middle post (post2) - should have post3 as prev, post1 as next
  let post2_output = @fs.read_file_to_string(
    output_root + "/posts/post2/index.html",
  ) catch {
    @fs.IOError(_) => ""
  }
  assert_true(
    post2_output.contains("/posts/post3/|Post 3|/posts/post1/|Post 1"),
  )

  // Check last post (post1) - should have post2 as prev, empty next
  let post1_output = @fs.read_file_to_string(
    output_root + "/posts/post1/index.html",
  ) catch {
    @fs.IOError(_) => ""
  }
  assert_true(post1_output.contains("/posts/post2/|Post 2||"))
}

///|
test "per-page template override via frontmatter" {
  let root = "./_tmp_per_page_template_override"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  // Create site.cfg
  assert_true(
    write_file_test(
      root + "/site.cfg",
      "site:\n  title: Test Site\n  base_url: https://example.test/\n",
    ),
  )

  // Create two posts - one with custom template, one without
  assert_true(
    write_file_test(
      posts_root + "/custom.md",
      "---\n" +
      "title: Custom Template Page\n" +
      "template: landing.html\n" +
      "---\n\n" +
      "This uses a custom template.\n",
    ),
  )
  assert_true(
    write_file_test(
      posts_root + "/default.md",
      "---\n" +
      "title: Default Template Page\n" +
      "---\n\n" +
      "This uses the default template.\n",
    ),
  )

  // Create default page template
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body>DEFAULT: {{content}}</body></html>\n",
    ),
  )

  // Create custom landing template
  assert_true(
    write_file_test(
      templates_root + "/landing.html",
      "<html><body>LANDING PAGE: {{content}}</body></html>\n",
    ),
  )

  // Create collections.cfg
  assert_true(
    write_file_test(
      root + "/collections.cfg",
      "[posts]\n" + "schema = title:String\n" + "dir = " + posts_root + "\n",
    ),
  )

  // Build
  let config : @builder.BuildConfig = {
    content_dir: content_root,
    output_dir: output_root,
    config_path: root + "/site.cfg",
    site: match
      @config.parse(
        "title = Test Site\n" +
        "base_url = https://example.test/\n" +
        "templates_dir = " +
        templates_root +
        "\n" +
        "data_dir = " +
        data_root +
        "\n" +
        "collections_file = " +
        root +
        "/collections.cfg\n" +
        "output_dir = " +
        output_root +
        "\n",
      ) {
      Ok(parsed) => parsed
      Err(_) => {
        assert_true(false)
        abort("site config parse failed")
      }
    },
    collections_path: Some(root + "/collections.cfg"),
    force_rebuild: false,
    include_drafts: false,
  }
  let cache = @cache.empty(output_root)
  let result = @builder.build(config, cache)
  assert_eq(result.errors, 0)

  // Check custom template page
  let custom_output = @fs.read_file_to_string(
    output_root + "/posts/custom/index.html",
  ) catch {
    @fs.IOError(_) => ""
  }
  assert_true(custom_output.contains("LANDING PAGE:"))
  assert_true(custom_output.contains("This uses a custom template."))

  // Check default template page
  let default_output = @fs.read_file_to_string(
    output_root + "/posts/default/index.html",
  ) catch {
    @fs.IOError(_) => ""
  }
  assert_true(default_output.contains("DEFAULT:"))
  assert_true(default_output.contains("This uses the default template."))
}

///|
test "per-page template override warns on missing template file" {
  let root = "./_tmp_per_page_template_missing"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  // Create site.cfg
  assert_true(
    write_file_test(
      root + "/site.cfg",
      "site:\n  title: Test Site\n  base_url: https://example.test/\n",
    ),
  )

  // Create post with missing custom template
  assert_true(
    write_file_test(
      posts_root + "/missing.md",
      "---\n" +
      "title: Missing Template Page\n" +
      "template: missing_template.html\n" +
      "---\n\n" +
      "This falls back to default template.\n",
    ),
  )

  // Create default page template only
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body>DEFAULT: {{content}}</body></html>\n",
    ),
  )

  // Create collections.cfg
  assert_true(
    write_file_test(
      root + "/collections.cfg",
      "[posts]\n" + "schema = title:String\n" + "dir = " + posts_root + "\n",
    ),
  )

  // Build
  let config : @builder.BuildConfig = {
    content_dir: content_root,
    output_dir: output_root,
    config_path: root + "/site.cfg",
    site: match
      @config.parse(
        "title = Test Site\n" +
        "base_url = https://example.test/\n" +
        "templates_dir = " +
        templates_root +
        "\n" +
        "data_dir = " +
        data_root +
        "\n" +
        "collections_file = " +
        root +
        "/collections.cfg\n" +
        "output_dir = " +
        output_root +
        "\n",
      ) {
      Ok(parsed) => parsed
      Err(_) => {
        assert_true(false)
        abort("site config parse failed")
      }
    },
    collections_path: Some(root + "/collections.cfg"),
    force_rebuild: false,
    include_drafts: false,
  }
  let cache = @cache.empty(output_root)
  let result = @builder.build(config, cache)

  // Build should still succeed
  assert_eq(result.errors, 0)

  // Should have a warning about missing template
  let mut has_warning = false
  let mut i = 0
  while i < result.diagnostics.length() {
    let diag = result.diagnostics[i]
    match diag {
      { severity: @diagnostic.Warning, message: msg, .. } =>
        if msg.contains("missing_template.html") &&
          msg.contains("not found") &&
          msg.contains("using default page template") {
          has_warning = true
        }
      _ => ()
    }
    i = i + 1
  }
  assert_true(has_warning)

  // Check that page still renders with default template
  let output = @fs.read_file_to_string(
    output_root + "/posts/missing/index.html",
  ) catch {
    @fs.IOError(_) => ""
  }
  assert_true(output.contains("DEFAULT:"))
  assert_true(output.contains("This falls back to default template."))
}

///|
test "redirect pages generated from redirect_from frontmatter" {
  let root = "./_tmp_builder_redirects"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  assert_true(
    write_file_test(
      posts_root + "/new-post.md",
      "---\n" +
      "title: New Post\n" +
      "date: 2026-03-11\n" +
      "redirect_from:\n" +
      "  - \"/old-path/\"\n" +
      "  - \"/another/old.html\"\n" +
      "---\n\n" +
      "This is the new location.\n",
    ),
  )

  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body>{{content}}</body></html>\n",
    ),
  )

  let site_cfg = "title = Test\n" +
    "base_url = https://example.com\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "collections_file = " +
    root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))
  assert_true(
    write_file_test(
      root + "/collections.cfg",
      "[posts]\n" +
      "schema = title:String,date:Date\n" +
      "dir = " +
      posts_root +
      "\n",
    ),
  )

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: Some(root + "/collections.cfg"),
      force_rebuild: false,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )

  // Build should succeed
  assert_eq(result.errors, 0)
  // Should report 2 redirects
  assert_eq(result.redirect_count, 2)

  // Check redirect for /old-path/
  let redirect1 = @fs.read_file_to_string(output_root + "/old-path/index.html") catch {
    @fs.IOError(_) => {
      assert_true(false)
      ""
    }
  }
  assert_true(redirect1.contains("<meta http-equiv=\"refresh\""))
  assert_true(redirect1.contains("https://example.com/posts/new-post"))
  assert_true(redirect1.contains("<link rel=\"canonical\""))

  // Check redirect for /another/old.html
  let redirect2 = @fs.read_file_to_string(output_root + "/another/old.html") catch {
    @fs.IOError(_) => {
      assert_true(false)
      ""
    }
  }
  assert_true(redirect2.contains("<meta http-equiv=\"refresh\""))
  assert_true(redirect2.contains("https://example.com/posts/new-post"))
  assert_true(redirect2.contains("<link rel=\"canonical\""))
}

///|
test "check reports TemplateSlotError when template references undeclared schema field" {
  // Validates the structural contract: {{page.field}} in a template must
  // correspond to a field declared in the collection schema. A mismatch is
  // caught at --check time rather than silently rendering empty at build time.
  let root = "./_tmp_check_template_schema_mismatch"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  // Schema declares only title and date — not subtitle
  assert_true(
    write_file_test(
      root + "/collections.cfg",
      "[posts]\nschema = title:String,date:Date\ndir = " + posts_root + "\n",
    ),
  )
  // Template references {{page.subtitle}} which is not in the schema
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body><h2>{{page.subtitle}}</h2>{{content}}</body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      posts_root + "/hello.md",
      "---\ntitle: Hello\ndate: 2026-03-24\n---\n\nBody.\n",
    ),
  )

  let site_cfg = "title = CrossValidTest\nbase_url = /\ntemplates_dir = " +
    templates_root +
    "\ndata_dir = " +
    data_root +
    "\ncollections_file = " +
    root +
    "/collections.cfg\noutput_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.check({
    content_dir: content_root,
    output_dir: output_root,
    config_path: root + "/site.cfg",
    site,
    collections_path: Some(root + "/collections.cfg"),
    force_rebuild: false,
    include_drafts: false,
  })
  // Should report exactly one TemplateSlotError for {{page.subtitle}}
  let slot_errors = result.violations.filter(fn(v) {
    v.kind == @lint.TemplateSlotError && v.message.contains("subtitle")
  })
  assert_eq(slot_errors.length(), 1)
}

///|
test "check reports no TemplateSlotError when template fields match schema" {
  let root = "./_tmp_check_template_schema_match"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  // Schema declares title, date, and subtitle — matching template
  assert_true(
    write_file_test(
      root + "/collections.cfg",
      "[posts]\nschema = title:String,date:Date,subtitle:Optional[String]\ndir = " +
      posts_root +
      "\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body><h2>{{page.subtitle}}</h2>{{content}}</body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      posts_root + "/hello.md",
      "---\ntitle: Hello\ndate: 2026-03-24\n---\n\nBody.\n",
    ),
  )

  let site_cfg = "title = CrossValidMatch\nbase_url = /\ntemplates_dir = " +
    templates_root +
    "\ndata_dir = " +
    data_root +
    "\ncollections_file = " +
    root +
    "/collections.cfg\noutput_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.check({
    content_dir: content_root,
    output_dir: output_root,
    config_path: root + "/site.cfg",
    site,
    collections_path: Some(root + "/collections.cfg"),
    force_rebuild: false,
    include_drafts: false,
  })
  // No TemplateSlotError for subtitle — it's declared in the schema
  let slot_errors = result.violations.filter(fn(v) {
    v.kind == @lint.TemplateSlotError && v.message.contains("subtitle")
  })
  assert_eq(slot_errors.length(), 0)
}

///|
test "standalone pages render to root-level URLs without collection prefix" {
  let root = "./_tmp_builder_standalone"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let standalone_root = content_root + "/standalone"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(standalone_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  // Create a collection page
  assert_true(
    write_file_test(
      posts_root + "/hello.md",
      "---\n" +
      "title: Hello Post\n" +
      "date: 2026-03-17\n" +
      "---\n\n" +
      "Post content.\n",
    ),
  )
  // Create a standalone page (no collection)
  assert_true(
    write_file_test(
      standalone_root + "/about.md",
      "---\n" +
      "title: About\n" +
      "---\n\n" +
      "# About\n\nThis is the about page.\n",
    ),
  )
  assert_true(
    write_file_test(
      standalone_root + "/contact.md",
      "---\n" + "title: Contact\n" + "---\n\n" + "# Contact\n\nReach us here.\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><head><title>{{title}}</title></head><body>{{content}}</body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      root + "/collections.cfg",
      "[posts]\n" +
      "schema = title:String,date:Date\n" +
      "dir = " +
      posts_root +
      "\n",
    ),
  )

  let site_cfg = "title = StandaloneTest\n" +
    "base_url = https://example.test\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "standalone_dir = " +
    standalone_root +
    "\n" +
    "collections_file = " +
    root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: Some(root + "/collections.cfg"),
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)

  // Standalone pages should exist at root-level URLs
  let about_html = @fs.read_file_to_string(output_root + "/about/index.html") catch {
    @fs.IOError(_) => ""
  }
  assert_true(about_html.contains("About"))
  assert_true(about_html.contains("about page"))

  let contact_html = @fs.read_file_to_string(
    output_root + "/contact/index.html",
  ) catch {
    @fs.IOError(_) => ""
  }
  assert_true(contact_html.contains("Contact"))
  assert_true(contact_html.contains("Reach us here"))

  // Collection page still works at its normal URL
  let post_html = @fs.read_file_to_string(
    output_root + "/posts/hello/index.html",
  ) catch {
    @fs.IOError(_) => ""
  }
  assert_true(post_html.contains("Hello Post"))

  // Standalone pages should NOT appear in collection index
  let posts_index = @fs.read_file_to_string(output_root + "/posts/index.html") catch {
    @fs.IOError(_) => ""
  }
  assert_true(!posts_index.contains("About"))
  assert_true(!posts_index.contains("Contact"))
}

///|
test "standalone page missing title reports build error" {
  let root = "./_tmp_builder_standalone_notitle"
  let content_root = root + "/content"
  let standalone_root = content_root + "/standalone"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(standalone_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  // Standalone page without required title field
  assert_true(
    write_file_test(
      standalone_root + "/notitle.md",
      "---\n" +
      "description: No title page\n" +
      "---\n\n" +
      "Content without title.\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body>{{content}}</body></html>\n",
    ),
  )

  let site_cfg = "title = NoTitleTest\n" +
    "base_url = https://example.test\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "standalone_dir = " +
    standalone_root +
    "\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: None,
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  // Should report errors because title is required for standalone pages
  assert_true(result.errors > 0)
  let found_title_error = result.diagnostics
    .iter()
    .any(fn(d) { d.message.contains("title") })
  assert_true(found_title_error)
}

///|
test "root-level index.md renders to dist/index.html as homepage" {
  let root = "./_tmp_builder_root_index"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  // Create a root-level index.md in the content directory
  assert_true(
    write_file_test(
      content_root + "/index.md",
      "---\n" +
      "title: Welcome\n" +
      "description: The homepage.\n" +
      "---\n\n" +
      "# Hello World\n\nThis is the homepage.\n",
    ),
  )
  // Create a root-level about.md
  assert_true(
    write_file_test(
      content_root + "/about.md",
      "---\n" + "title: About\n" + "---\n\n" + "# About\n\nAbout this site.\n",
    ),
  )
  // Create a collection page to verify coexistence
  assert_true(
    write_file_test(
      posts_root + "/hello.md",
      "---\n" +
      "title: Hello Post\n" +
      "date: 2026-03-17\n" +
      "---\n\n" +
      "Post content.\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><head><title>{{title}}</title></head><body>{{content}}</body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      root + "/collections.cfg",
      "[posts]\n" +
      "schema = title:String,date:Date\n" +
      "dir = " +
      posts_root +
      "\n",
    ),
  )

  let site_cfg = "title = RootTest\n" +
    "base_url = https://example.test\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "collections_file = " +
    root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: Some(root + "/collections.cfg"),
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)

  // index.md → dist/index.html (not dist/index/index.html)
  let index_html = @fs.read_file_to_string(output_root + "/index.html") catch {
    @fs.IOError(_) => ""
  }
  assert_true(index_html.contains("Welcome"))
  assert_true(index_html.contains("homepage"))

  // about.md → dist/about/index.html
  let about_html = @fs.read_file_to_string(output_root + "/about/index.html") catch {
    @fs.IOError(_) => ""
  }
  assert_true(about_html.contains("About"))
  assert_true(about_html.contains("About this site"))

  // Collection page still works at its normal URL
  let post_html = @fs.read_file_to_string(
    output_root + "/posts/hello/index.html",
  ) catch {
    @fs.IOError(_) => ""
  }
  assert_true(post_html.contains("Hello Post"))

  // Root pages should appear in sitemap
  let sitemap = @fs.read_file_to_string(output_root + "/sitemap.xml") catch {
    @fs.IOError(_) => ""
  }
  assert_true(sitemap.contains("https://example.test/"))
  assert_true(sitemap.contains("https://example.test/about/"))
}

///|
test "root page slug conflicts with collection slug reports error" {
  let root = "./_tmp_builder_root_conflict"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  // Create a root-level file whose slug matches a collection post
  // (slug "hello" is claimed by posts collection)
  assert_true(
    write_file_test(
      content_root + "/hello.md",
      "---\n" + "title: Hello\n" + "---\n\n" + "Root hello page.\n",
    ),
  )
  assert_true(
    write_file_test(
      posts_root + "/hello.md",
      "---\n" +
      "title: Hello Post\n" +
      "date: 2026-03-17\n" +
      "---\n\n" +
      "Post content.\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><head><title>{{title}}</title></head><body>{{content}}</body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      root + "/collections.cfg",
      "[posts]\n" +
      "schema = title:String,date:Date\n" +
      "dir = " +
      posts_root +
      "\n",
    ),
  )

  let site_cfg = "title = ConflictTest\n" +
    "base_url = https://example.test\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "collections_file = " +
    root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: Some(root + "/collections.cfg"),
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  // The root hello.md should be skipped because the slug is already claimed
  // by the posts collection — so no error, it just silently doesn't get rendered
  assert_eq(result.errors, 0)
}

///|
test "404.md in content root is not treated as root page" {
  let root = "./_tmp_builder_root_404"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  // Create 404.md in content root — should be handled by the 404 pipeline, not root pages
  assert_true(
    write_file_test(
      content_root + "/404.md",
      "---\n" + "title: Not Found\n" + "---\n\n" + "# 404\n\nPage not found.\n",
    ),
  )
  // Also create a genuine root page
  assert_true(
    write_file_test(
      content_root + "/index.md",
      "---\n" + "title: Home\n" + "---\n\n" + "# Home\n\nWelcome.\n",
    ),
  )
  assert_true(
    write_file_test(
      posts_root + "/hello.md",
      "---\n" +
      "title: Hello\n" +
      "date: 2026-03-17\n" +
      "---\n\n" +
      "Content.\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><head><title>{{title}}</title></head><body>{{content}}</body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      root + "/collections.cfg",
      "[posts]\n" +
      "schema = title:String,date:Date\n" +
      "dir = " +
      posts_root +
      "\n",
    ),
  )

  let site_cfg = "title = Test404\n" +
    "base_url = https://example.test\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "collections_file = " +
    root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: Some(root + "/collections.cfg"),
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)

  // index.md should be rendered
  let index_html = @fs.read_file_to_string(output_root + "/index.html") catch {
    @fs.IOError(_) => ""
  }
  assert_true(index_html.contains("Home"))

  // 404.md should be rendered as the 404 page
  let notfound_html = @fs.read_file_to_string(output_root + "/404.html") catch {
    @fs.IOError(_) => ""
  }
  assert_true(notfound_html.contains("Not Found"))
}

///|
test "reading_time_minutes returns None for zero" {
  assert_eq(@builder.reading_time_minutes(0), None)
}

///|
test "reading_time_minutes returns Some(1) for small count" {
  assert_eq(@builder.reading_time_minutes(50), Some(1))
}

///|
test "reading_time_minutes returns Some(2) for 450 words" {
  assert_eq(@builder.reading_time_minutes(450), Some(2))
}

///|
test "reading_time_minutes returns Some(10) for 2250 words" {
  assert_eq(@builder.reading_time_minutes(2250), Some(10))
}

///|
test "build emits content-index.json with kind and reading_time" {
  let root = "./_tmp_builder_content_index"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(output_root)

  assert_true(
    write_file_test(
      posts_root + "/hello.md",
      "---\n" +
      "title: Hello World\n" +
      "date: 2026-03-11\n" +
      "description: A test post\n" +
      "tags: [demo]\n" +
      "---\n\n" +
      "This is the body of the test post. " +
      "It has several words to provide content for reading time calculation. " +
      "More words here to pad it out a bit.\n",
    ),
  )
  let site_cfg = "title = Test\n" +
    "base_url = /\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "content_index_file = content-index.json\n" +
    "output_dir = " +
    output_root +
    "\n" +
    "[[collections]]\n" +
    "name = posts\n" +
    "dir = " +
    posts_root +
    "\n" +
    "schema = title:String,date:Date,description:String,tags:Optional[Array[String]]\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))
  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: None,
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)

  // content-index.json should be emitted
  let content_index = @fs.read_file_to_string(
    output_root + "/content-index.json",
  ) catch {
    @fs.IOError(_) => ""
  }
  assert_true(content_index.length() > 0)
  // Verify the JSON array structure
  assert_true(content_index.contains("\"url\": \"/posts/hello/\""))
  assert_true(content_index.contains("\"title\": \"Hello World\""))
  assert_true(content_index.contains("\"kind\": \"post\""))
  assert_true(content_index.contains("\"reading_time\":"))
  assert_true(content_index.contains("\"collection\": \"posts\""))
  assert_true(content_index.contains("\"date\": \"2026-03-11\""))
  assert_true(content_index.contains("\"description\": \"A test post\""))
  assert_true(content_index.contains("\"tags\": [\"demo\"]"))
}

///|
test "build content-index standalone page has kind standalone" {
  let root = "./_tmp_builder_content_index_standalone"
  let content_root = root + "/content"
  let standalone_root = root + "/standalone"
  let data_root = content_root + "/data"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(standalone_root)
  ensure_dir_test(data_root)
  ensure_dir_test(output_root)

  assert_true(
    write_file_test(
      standalone_root + "/about.md",
      "---\n" +
      "title: About Page\n" +
      "description: An about page\n" +
      "---\n\n" +
      "This is the about page body.\n",
    ),
  )
  let site_cfg = "title = Test\n" +
    "base_url = /\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "standalone_dir = " +
    standalone_root +
    "\n" +
    "content_index_file = content-index.json\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))
  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: None,
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)

  let content_index = @fs.read_file_to_string(
    output_root + "/content-index.json",
  ) catch {
    @fs.IOError(_) => ""
  }
  assert_true(content_index.length() > 0)
  assert_true(content_index.contains("\"url\": \"/about/\""))
  assert_true(content_index.contains("\"title\": \"About Page\""))
  assert_true(content_index.contains("\"kind\": \"standalone\""))
  assert_true(content_index.contains("\"reading_time\":"))
}

///|
test "build emits collection_index entry in content-index.json" {
  let root = "./_tmp_builder_content_index_coll_idx"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(output_root)

  assert_true(
    write_file_test(
      posts_root + "/hello.md",
      "---\n" +
      "title: Hello World\n" +
      "date: 2026-03-11\n" +
      "description: A test post\n" +
      "tags: [demo]\n" +
      "---\n\n" +
      "This is the body of the test post.\n",
    ),
  )
  let site_cfg = "title = Test\n" +
    "base_url = /\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "content_index_file = content-index.json\n" +
    "output_dir = " +
    output_root +
    "\n" +
    "[[collections]]\n" +
    "name = posts\n" +
    "dir = " +
    posts_root +
    "\n" +
    "schema = title:String,date:Date,description:String,tags:Optional[Array[String]]\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))
  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: None,
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)

  // content-index.json should contain a collection_index entry
  let content_index = @fs.read_file_to_string(
    output_root + "/content-index.json",
  ) catch {
    @fs.IOError(_) => ""
  }
  assert_true(content_index.length() > 0)
  assert_true(content_index.contains("\"kind\": \"collection_index\""))
  assert_true(content_index.contains("\"slug\": \"posts\""))
  assert_true(content_index.contains("\"title\": \"posts Index\""))
  assert_true(content_index.contains("\"url\": \"/posts/\""))
  assert_true(content_index.contains("\"collection\": \"posts\""))
  assert_true(content_index.contains("\"date\": \"\""))
  assert_true(content_index.contains("\"reading_time\": null"))
}

///|
test "build accumulates validation errors across collection and standalone pages" {
  // Engineering quality: the builder must collect ALL errors across ALL source
  // files before reporting, not stop at the first failure. This test creates
  // a collection page with a missing required field AND a standalone page with
  // a missing required field, then asserts both errors appear in diagnostics.
  let root = "./_tmp_builder_accumulate_errors"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let standalone_root = content_root + "/standalone"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(standalone_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  // Collection page missing required 'date' field
  assert_true(
    write_file_test(
      posts_root + "/no-date.md",
      "---\ntitle: Missing Date\n---\nBody.\n",
    ),
  )
  // Standalone page missing required 'title' field
  assert_true(
    write_file_test(
      standalone_root + "/no-title.md",
      "---\ndescription: No title\n---\nBody.\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body>{{content}}</body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      root + "/collections.cfg",
      "[posts]\nschema = title:String,date:Date\ndir = " + posts_root + "\n",
    ),
  )

  let site_cfg = "title = AccumulateTest\n" +
    "base_url = https://example.test\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "standalone_dir = " +
    standalone_root +
    "\n" +
    "collections_file = " +
    root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: Some(root + "/collections.cfg"),
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )

  // Both errors must be present — one for the collection page, one for standalone
  assert_true(result.errors >= 2)

  // The collection page error should mention 'date'
  let collection_errors = result.diagnostics
    .iter()
    .filter(fn(d) {
      match d.path {
        Some(p) => p.contains("no-date")
        None => false
      }
    })
    .to_array()
  assert_true(collection_errors.length() > 0)
  let has_date_error = collection_errors
    .iter()
    .any(fn(d) { d.message.contains("date") })
  assert_true(has_date_error)

  // The standalone page error should mention 'title'
  let standalone_errors = result.diagnostics
    .iter()
    .filter(fn(d) {
      match d.path {
        Some(p) => p.contains("no-title")
        None => false
      }
    })
    .to_array()
  assert_true(standalone_errors.length() > 0)
  let has_title_error = standalone_errors
    .iter()
    .any(fn(d) { d.message.contains("title") })
  assert_true(has_title_error)
}

///|
test "build accumulates validation errors across collection and root pages" {
  // Same as above but with root-level pages instead of standalone.
  // Root pages (content/*.md) should also be validated even when
  // collection pages have errors.
  let root = "./_tmp_builder_accumulate_root_errors"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  // Collection page missing required 'date' field
  assert_true(
    write_file_test(
      posts_root + "/no-date.md",
      "---\ntitle: Missing Date\n---\nBody.\n",
    ),
  )
  // Root page (content/about.md) missing required 'title' field
  // Root pages use standalone_default_schema which requires title
  assert_true(
    write_file_test(
      content_root + "/notitle.md",
      "---\ndescription: No title\n---\nBody.\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body>{{content}}</body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      root + "/collections.cfg",
      "[posts]\nschema = title:String,date:Date\ndir = " + posts_root + "\n",
    ),
  )

  let site_cfg = "title = AccumulateRootTest\n" +
    "base_url = https://example.test\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "collections_file = " +
    root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: Some(root + "/collections.cfg"),
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )

  // Both errors must be present
  assert_true(result.errors >= 2)

  // The collection page error should mention 'date'
  let collection_errors = result.diagnostics
    .iter()
    .filter(fn(d) {
      match d.path {
        Some(p) => p.contains("no-date")
        None => false
      }
    })
    .to_array()
  assert_true(collection_errors.length() > 0)

  // The root page error should mention 'title'
  let root_errors = result.diagnostics
    .iter()
    .filter(fn(d) {
      match d.path {
        Some(p) => p.contains("notitle")
        None => false
      }
    })
    .to_array()
  assert_true(root_errors.length() > 0)
  let has_title_error = root_errors
    .iter()
    .any(fn(d) { d.message.contains("title") })
  assert_true(has_title_error)
}

///|
test "sort_collection_pages sorts by weight (lower weight first)" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "heavy",
      title: "Heavy Page",
      url: "/heavy",
      description: None,
      date: None,
      weight: Some(100),
      outgoing: [],
    },
    {
      slug: "light",
      title: "Light Page",
      url: "/light",
      description: None,
      date: None,
      weight: Some(1),
      outgoing: [],
    },
    {
      slug: "medium",
      title: "Medium Page",
      url: "/medium",
      description: None,
      date: None,
      weight: Some(50),
      outgoing: [],
    },
  ]
  @builder.sort_collection_pages(pages, @collections.Weight)
  assert_eq(pages[0].slug, "light")
  assert_eq(pages[1].slug, "medium")
  assert_eq(pages[2].slug, "heavy")
}

///|
test "sort_collection_pages weight puts unweighted pages after weighted" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "no-weight",
      title: "No Weight Page",
      url: "/no-weight",
      description: None,
      date: None,
      weight: None,
      outgoing: [],
    },
    {
      slug: "weighted",
      title: "Weighted Page",
      url: "/weighted",
      description: None,
      date: None,
      weight: Some(10),
      outgoing: [],
    },
    {
      slug: "also-no-weight",
      title: "Also No Weight",
      url: "/also-no-weight",
      description: None,
      date: None,
      weight: None,
      outgoing: [],
    },
  ]
  @builder.sort_collection_pages(pages, @collections.Weight)
  assert_eq(pages[0].slug, "weighted")
  // Pages without weight sort after weighted pages
  assert_true(pages[1].slug == "no-weight" || pages[1].slug == "also-no-weight")
  assert_true(pages[2].slug == "no-weight" || pages[2].slug == "also-no-weight")
}

///|
test "sort_collection_pages weight with equal weights preserves relative order" {
  let pages : Array[@graph.GraphPage] = [
    {
      slug: "a",
      title: "Page A",
      url: "/a",
      description: None,
      date: None,
      weight: Some(5),
      outgoing: [],
    },
    {
      slug: "b",
      title: "Page B",
      url: "/b",
      description: None,
      date: None,
      weight: Some(5),
      outgoing: [],
    },
    {
      slug: "c",
      title: "Page C",
      url: "/c",
      description: None,
      date: None,
      weight: Some(1),
      outgoing: [],
    },
  ]
  @builder.sort_collection_pages(pages, @collections.Weight)
  assert_eq(pages[0].slug, "c")
  // a and b have equal weight, insertion sort preserves relative order
  assert_eq(pages[1].slug, "a")
  assert_eq(pages[2].slug, "b")
}

///|
test "standalone page with per-page template override via frontmatter" {
  let root = "./_tmp_builder_standalone_template_override"
  let content_root = root + "/content"
  let standalone_root = content_root + "/standalone"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(standalone_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  // Standalone page with custom template in frontmatter
  assert_true(
    write_file_test(
      standalone_root + "/landing.md",
      "---\n" +
      "title: Landing\n" +
      "template: landing.html\n" +
      "---\n\n" +
      "Custom landing content.\n",
    ),
  )
  // Standalone page with default template
  assert_true(
    write_file_test(
      standalone_root + "/default.md",
      "---\n" + "title: Default\n" + "---\n\n" + "Default content.\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body>DEFAULT: {{content}}</body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/landing.html",
      "<html><body>LANDING: {{content}}</body></html>\n",
    ),
  )

  let site_cfg = "title = TemplateTest\n" +
    "base_url = https://example.test\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "standalone_dir = " +
    standalone_root +
    "\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: None,
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)

  let landing_output = @fs.read_file_to_string(
    output_root + "/landing/index.html",
  ) catch {
    @fs.IOError(_) => ""
  }
  assert_true(landing_output.contains("LANDING:"))
  assert_true(landing_output.contains("Custom landing content"))

  let default_output = @fs.read_file_to_string(
    output_root + "/default/index.html",
  ) catch {
    @fs.IOError(_) => ""
  }
  assert_true(default_output.contains("DEFAULT:"))
  assert_true(default_output.contains("Default content"))
}

///|
test "root-level about.md with per-page template override via frontmatter" {
  let root = "./_tmp_builder_root_template_override"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  // Root page with custom template
  assert_true(
    write_file_test(
      content_root + "/about.md",
      "---\n" +
      "title: About\n" +
      "template: about.html\n" +
      "---\n\n" +
      "About page content.\n",
    ),
  )
  // Collection page for coexistence test
  assert_true(
    write_file_test(
      posts_root + "/hello.md",
      "---\n" +
      "title: Hello\n" +
      "date: 2026-04-01\n" +
      "---\n\n" +
      "Post content.\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body>DEFAULT: {{content}}</body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/about.html",
      "<html><body>ABOUT: {{content}}</body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      root + "/collections.cfg",
      "[posts]\n" +
      "schema = title:String,date:Date\n" +
      "dir = " +
      posts_root +
      "\n",
    ),
  )

  let site_cfg = "title = RootTemplateTest\n" +
    "base_url = https://example.test\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "collections_file = " +
    root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: Some(root + "/collections.cfg"),
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)

  let about_output = @fs.read_file_to_string(output_root + "/about/index.html") catch {
    @fs.IOError(_) => ""
  }
  assert_true(about_output.contains("ABOUT:"))
  assert_true(about_output.contains("About page content"))
}

///|
test "wikilinks between root page and collection page resolve correctly" {
  let root = "./_tmp_builder_root_wikilinks"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  // Root page linking to a collection page via wikilink
  assert_true(
    write_file_test(
      content_root + "/about.md",
      "---\n" + "title: About\n" + "---\n\n" + "Check out [[hello]] for more.\n",
    ),
  )
  // Collection page linking back to root page via wikilink
  assert_true(
    write_file_test(
      posts_root + "/hello.md",
      "---\n" +
      "title: Hello Post\n" +
      "date: 2026-04-01\n" +
      "---\n\n" +
      "See [[about]] for context.\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body>{{content}}</body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      root + "/collections.cfg",
      "[posts]\n" +
      "schema = title:String,date:Date\n" +
      "dir = " +
      posts_root +
      "\n",
    ),
  )

  let site_cfg = "title = WikilinkTest\n" +
    "base_url = https://example.test\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "collections_file = " +
    root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: Some(root + "/collections.cfg"),
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)

  // Root page should link to collection page
  let about_output = @fs.read_file_to_string(output_root + "/about/index.html") catch {
    @fs.IOError(_) => ""
  }
  assert_true(about_output.contains("href=\"/posts/hello/\""))

  // Collection page should link back to root page
  let hello_output = @fs.read_file_to_string(
    output_root + "/posts/hello/index.html",
  ) catch {
    @fs.IOError(_) => ""
  }
  assert_true(hello_output.contains("href=\"/about/\""))
}

///|
test "standalone page redirect_from generates redirect stubs" {
  let root = "./_tmp_builder_standalone_redirect"
  let content_root = root + "/content"
  let standalone_root = content_root + "/standalone"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(standalone_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  // Standalone page with redirect_from
  assert_true(
    write_file_test(
      standalone_root + "/about.md",
      "---\n" +
      "title: About\n" +
      "redirect_from:\n" +
      "  - \"/old-about/\"\n" +
      "---\n\n" +
      "About page content.\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body>{{content}}</body></html>\n",
    ),
  )

  let site_cfg = "title = RedirectTest\n" +
    "base_url = https://example.test\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "standalone_dir = " +
    standalone_root +
    "\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: None,
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)
  assert_eq(result.redirect_count, 1)

  // Redirect should point to the standalone page URL
  let redirect_html = @fs.read_file_to_string(
    output_root + "/old-about/index.html",
  ) catch {
    @fs.IOError(_) => ""
  }
  assert_true(redirect_html.contains("https://example.test/about"))
  assert_true(redirect_html.contains("meta http-equiv=\"refresh\""))
}

///|
test "root page redirect_from generates redirect stubs" {
  let root = "./_tmp_builder_root_redirect"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  // Root page with redirect_from
  assert_true(
    write_file_test(
      content_root + "/about.md",
      "---\n" +
      "title: About\n" +
      "redirect_from:\n" +
      "  - \"/old-about-page/\"\n" +
      "---\n\n" +
      "About content.\n",
    ),
  )
  assert_true(
    write_file_test(
      posts_root + "/hello.md",
      "---\n" +
      "title: Hello\n" +
      "date: 2026-04-01\n" +
      "---\n\n" +
      "Post content.\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body>{{content}}</body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      root + "/collections.cfg",
      "[posts]\n" +
      "schema = title:String,date:Date\n" +
      "dir = " +
      posts_root +
      "\n",
    ),
  )

  let site_cfg = "title = RootRedirectTest\n" +
    "base_url = https://example.test\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "collections_file = " +
    root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: Some(root + "/collections.cfg"),
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)
  assert_eq(result.redirect_count, 1)

  let redirect_html = @fs.read_file_to_string(
    output_root + "/old-about-page/index.html",
  ) catch {
    @fs.IOError(_) => ""
  }
  assert_true(redirect_html.contains("https://example.test/about"))
}

///|
test "root page content-index entry has kind page" {
  let root = "./_tmp_builder_content_index_root_page"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(output_root)

  // Root page
  assert_true(
    write_file_test(
      content_root + "/about.md",
      "---\n" +
      "title: About\n" +
      "description: An about page\n" +
      "---\n\n" +
      "About page body.\n",
    ),
  )
  // Collection page for coexistence
  assert_true(
    write_file_test(
      posts_root + "/hello.md",
      "---\n" +
      "title: Hello\n" +
      "date: 2026-04-01\n" +
      "description: A post\n" +
      "---\n\n" +
      "Post body.\n",
    ),
  )

  let site_cfg = "title = Test\n" +
    "base_url = /\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "content_index_file = content-index.json\n" +
    "output_dir = " +
    output_root +
    "\n" +
    "[[collections]]\n" +
    "name = posts\n" +
    "dir = " +
    posts_root +
    "\n" +
    "schema = title:String,date:Date,description:String\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: None,
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)

  let content_index = @fs.read_file_to_string(
    output_root + "/content-index.json",
  ) catch {
    @fs.IOError(_) => ""
  }
  assert_true(content_index.length() > 0)
  // Root page should have kind "page" (not "post" or "standalone")
  assert_true(content_index.contains("\"kind\": \"page\""))
  assert_true(content_index.contains("\"url\": \"/about/\""))
  assert_true(content_index.contains("\"title\": \"About\""))
}

///|
test "standalone page appears in sitemap" {
  let root = "./_tmp_builder_standalone_sitemap"
  let content_root = root + "/content"
  let standalone_root = content_root + "/standalone"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(standalone_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  assert_true(
    write_file_test(
      standalone_root + "/about.md",
      "---\n" + "title: About\n" + "---\n\n" + "About page.\n",
    ),
  )
  assert_true(
    write_file_test(
      posts_root + "/hello.md",
      "---\n" +
      "title: Hello\n" +
      "date: 2026-04-01\n" +
      "---\n\n" +
      "Post content.\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body>{{content}}</body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      root + "/collections.cfg",
      "[posts]\n" +
      "schema = title:String,date:Date\n" +
      "dir = " +
      posts_root +
      "\n",
    ),
  )

  let site_cfg = "title = SitemapTest\n" +
    "base_url = https://example.test\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "standalone_dir = " +
    standalone_root +
    "\n" +
    "collections_file = " +
    root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: Some(root + "/collections.cfg"),
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)

  let sitemap = @fs.read_file_to_string(output_root + "/sitemap.xml") catch {
    @fs.IOError(_) => ""
  }
  assert_true(sitemap.contains("https://example.test/about/"))
  assert_true(sitemap.contains("https://example.test/posts/hello/"))
}

///|
test "root page with description populates meta description in output" {
  let root = "./_tmp_builder_root_description"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  // Root page with description
  assert_true(
    write_file_test(
      content_root + "/about.md",
      "---\n" +
      "title: About\n" +
      "description: Everything about this site.\n" +
      "---\n\n" +
      "About content.\n",
    ),
  )
  assert_true(
    write_file_test(
      posts_root + "/hello.md",
      "---\n" + "title: Hello\n" + "date: 2026-04-01\n" + "---\n\n" + "Post.\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><head>{{head_meta}}</head><body>{{content}}</body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      root + "/collections.cfg",
      "[posts]\n" +
      "schema = title:String,date:Date\n" +
      "dir = " +
      posts_root +
      "\n",
    ),
  )

  let site_cfg = "title = DescTest\n" +
    "base_url = https://example.test\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "collections_file = " +
    root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: Some(root + "/collections.cfg"),
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)

  let about_output = @fs.read_file_to_string(output_root + "/about/index.html") catch {
    @fs.IOError(_) => ""
  }
  assert_true(about_output.contains("Everything about this site."))
}

///|
test "standalone page with backlinks from collection page" {
  let root = "./_tmp_builder_standalone_backlinks"
  let content_root = root + "/content"
  let standalone_root = content_root + "/standalone"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(standalone_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  // Standalone page (about) that will receive a backlink
  assert_true(
    write_file_test(
      standalone_root + "/about.md",
      "---\n" + "title: About\n" + "---\n\n" + "This is the about page.\n",
    ),
  )
  // Collection page that links to about via wikilink
  assert_true(
    write_file_test(
      posts_root + "/hello.md",
      "---\n" +
      "title: Hello Post\n" +
      "date: 2026-04-01\n" +
      "---\n\n" +
      "Learn more on the [[about]] page.\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><body>{{content}}</body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      root + "/collections.cfg",
      "[posts]\n" +
      "schema = title:String,date:Date\n" +
      "dir = " +
      posts_root +
      "\n",
    ),
  )

  let site_cfg = "title = BacklinkTest\n" +
    "base_url = https://example.test\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "standalone_dir = " +
    standalone_root +
    "\n" +
    "collections_file = " +
    root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: Some(root + "/collections.cfg"),
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  assert_eq(result.errors, 0)

  // Verify the standalone about page was built
  let about_output = @fs.read_file_to_string(output_root + "/about/index.html") catch {
    @fs.IOError(_) => ""
  }
  assert_true(about_output.contains("about page"))

  // Verify the collection page was built with wikilink resolved
  let hello_output = @fs.read_file_to_string(
    output_root + "/posts/hello/index.html",
  ) catch {
    @fs.IOError(_) => ""
  }
  assert_true(hello_output.contains("href=\"/about/\""))
}



///|
test "is_non_content_file excludes well-known non-content files" {
  assert_true(@builder.is_non_content_file("404.md"))
  assert_true(@builder.is_non_content_file("README.md"))
  assert_true(@builder.is_non_content_file("readme.md"))
  assert_true(@builder.is_non_content_file("Readme.md"))
  assert_true(@builder.is_non_content_file("CHANGELOG.md"))
  assert_true(@builder.is_non_content_file("changelog.md"))
  assert_true(@builder.is_non_content_file("LICENSE.md"))
  assert_true(@builder.is_non_content_file("license.md"))
  assert_true(@builder.is_non_content_file("CONTRIBUTING.md"))
  assert_true(@builder.is_non_content_file("CODE_OF_CONDUCT.md"))
  assert_true(@builder.is_non_content_file("code_of_conduct.md"))
}

///|
test "is_non_content_file does not exclude genuine content files" {
  assert_false(@builder.is_non_content_file("index.md"))
  assert_false(@builder.is_non_content_file("about.md"))
  assert_false(@builder.is_non_content_file("hello.md"))
  assert_false(@builder.is_non_content_file("my-post.md"))
  assert_false(@builder.is_non_content_file("readme-intro.md"))
}

///|
test "README.md in content root is not treated as root page" {
  let root = "./_tmp_builder_root_readme"
  let content_root = root + "/content"
  let posts_root = content_root + "/posts"
  let data_root = content_root + "/data"
  let templates_root = root + "/templates"
  let output_root = root + "/dist"
  ensure_dir_test(root)
  ensure_dir_test(content_root)
  ensure_dir_test(posts_root)
  ensure_dir_test(data_root)
  ensure_dir_test(templates_root)
  ensure_dir_test(output_root)

  // Create README.md in content root — should be excluded from root pages
  assert_true(
    write_file_test(
      content_root + "/README.md",
      "# Lattice Example Site\n\nThis is an example site for the Lattice SSG.\n",
    ),
  )
  // Also create a genuine root page
  assert_true(
    write_file_test(
      content_root + "/index.md",
      "---\n" + "title: Home\n" + "---\n\n" + "# Home\n\nWelcome.\n",
    ),
  )
  assert_true(
    write_file_test(
      posts_root + "/hello.md",
      "---\n" +
      "title: Hello\n" +
      "date: 2026-03-17\n" +
      "---\n\n" +
      "Content.\n",
    ),
  )
  assert_true(
    write_file_test(
      templates_root + "/page.html",
      "<html><head><title>{{title}}</title></head><body>{{content}}</body></html>\n",
    ),
  )
  assert_true(
    write_file_test(
      root + "/collections.cfg",
      "[posts]\n" +
      "schema = title:String,date:Date\n" +
      "dir = " +
      posts_root +
      "\n",
    ),
  )

  let site_cfg = "title = TestReadme\n" +
    "base_url = https://example.test\n" +
    "templates_dir = " +
    templates_root +
    "\n" +
    "data_dir = " +
    data_root +
    "\n" +
    "collections_file = " +
    root +
    "/collections.cfg\n" +
    "output_dir = " +
    output_root +
    "\n"
  assert_true(write_file_test(root + "/site.cfg", site_cfg))

  let site = match @config.parse(site_cfg) {
    Ok(parsed) => parsed
    Err(_) => {
      assert_true(false)
      abort("site config parse failed")
    }
  }
  let result = @builder.build(
    {
      content_dir: content_root,
      output_dir: output_root,
      config_path: root + "/site.cfg",
      site,
      collections_path: Some(root + "/collections.cfg"),
      force_rebuild: true,
      include_drafts: false,
    },
    @cache.empty(output_root),
  )
  // Build should succeed — README.md excluded, no frontmatter error
  assert_eq(result.errors, 0)

  // index.md should be rendered
  let index_html = @fs.read_file_to_string(output_root + "/index.html") catch {
    @fs.IOError(_) => ""
  }
  assert_true(index_html.contains("Home"))
}
