///|
test "backlinks list each referring note once across repeated heading targets" {
  let config = publication_fixture("backlink_dedup")
  @fs.remove_file(config.site.templates_dir.unwrap() + "/page.html")
  @fs.write_string_to_file(
    config.content_dir + "/posts/alpha.md",
    "---\ntitle: Garden\ndate: 2026-01-02\n---\n[[Beta.md#Planting|care]] [[beta#Harvest|harvest]] [[BETA|overview]]\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/gamma.md",
    "---\ntitle: Garden\ndate: 2026-01-04\n---\n[[beta]] [[Beta.md#Harvest]]\n",
  )
  @fs.write_string_to_file(
    config.content_dir + "/posts/beta.md",
    "---\ntitle: Beta\ndate: 2026-02-03\n---\n## Planting\n## Harvest\n",
  )
  let result = @builder.build(config, @cache.empty(config.output_dir))
  assert_eq(result.errors, 0)
  let beta = @fs.read_file_to_string(
    config.output_dir + "/posts/beta/index.html",
  )
  assert_true(
    beta.contains(
      "<section class=\"backlinks\" id=\"lattice-backlinks\" tabindex=\"-1\">\n<h2>Backlinks</h2>\n<ul>\n<li><a href=\"/posts/alpha/\">Garden</a></li>\n<li><a href=\"/posts/gamma/\">Garden</a></li>\n</ul>\n</section>\n",
    ),
  )
}
