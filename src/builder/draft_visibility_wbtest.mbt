///|
test "backlinks require a published URL for both source and target" {
  let sources : Array[SourceFile] = [
    {
      path: "posts/alpha.md",
      filename: "alpha.md",
      slug: "alpha",
      content: "---\ntitle: Alpha\n---\nSee [[beta]] and [[hidden-target]].",
      fingerprint: "alpha",
      stamp: 0,
      link_targets: ["beta", "hidden-target"],
    },
    {
      path: "posts/hidden-ref.md",
      filename: "hidden-ref.md",
      slug: "hidden-ref",
      content: "---\ntitle: Hidden Referrer\ndraft: true\n---\nSee [[beta]].",
      fingerprint: "hidden-ref",
      stamp: 0,
      link_targets: ["beta"],
    },
  ]
  let collections : Array[CollectionSources] = [
    {
      definition: {
        name: "posts",
        schema: standalone_default_schema(),
        content_dir: "posts",
        template: None,
        page_size: None,
        sort_order: @collections.DateDesc,
        description: None,
      },
      sources,
    },
  ]
  let urls = Map([("alpha", "/posts/alpha/"), ("beta", "/posts/beta/")])
  let published = build_backlink_index(collections, urls)
  assert_eq(published.length(), 1)
  let refs = published.get("beta").unwrap()
  assert_eq(refs.length(), 1)
  assert_eq(refs[0].url, "/posts/alpha/")
  assert_eq(refs[0].title, "Alpha")
  assert_false(published.contains("hidden-target"))
  urls.set("hidden-ref", "/posts/hidden-ref/")
  urls.set("hidden-target", "/posts/hidden-target/")
  let included = build_backlink_index(collections, urls)
  assert_eq(included.get("beta").unwrap().length(), 2)
  assert_eq(included.get("hidden-target").unwrap()[0].url, "/posts/alpha/")
}
