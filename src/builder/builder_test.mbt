///|
fn ensure_dir_test(path : String) -> Unit {
  if not(@fs.path_exists(path)) {
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
test "collection index lookup alias uses numeric prefix directory basename" {
  let collection : @collections.CollectionDef = {
    name: "projects",
    schema: { name: "projects", fields: [] },
    content_dir: "/vault/10 - Projects",
    template: None,
    page_size: None,
    sort_order: @collections.DateDesc,
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
  }
  match @builder.collection_index_lookup_alias(collection) {
    Some(_) => assert_true(false)
    None => ()
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
  assert_true(not(output.contains("default")))
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
  match @template.render_template(tpl, slots) {
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
  assert_true(not(@fs.path_exists(output_root + "/notes/page/2/index.html")))
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

  assert_true(not(@fs.path_exists(output_root + "/posts/page/2/index.html")))
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
  assert_true(not(output.contains("table-of-contents")))
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
  assert_true(not(output.contains("href=\"#setup\"")))
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
  let collections_cfg = "[posts]\nschema = title:String,date:Date,tags:Array[String]\ndir = " + posts_root + "\n"
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
  let collections_cfg = "[posts]\nschema = title:String,date:Date,tags:Array[String]\ndir = " + posts_root + "\n"
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
  let collections_cfg = "[posts]\nschema = title:String,date:Optional[Date],tags:Optional[Array[String]]\ndir = " + posts_root + "\n"
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

