///|
test "inventory captures unique emitted targets and excludes inert or duplicate IDs" {
  assert_eq(inventory_html_fragments("<h2 id='alpha'>A</h2><a name='legacy'></a><a id='both' name='both'></a><template><h2 id='hidden'>H</h2></template><!-- <h2 id='comment'> -->"), Some(["alpha", "both", "legacy"]))
  assert_eq(inventory_html_fragments("<h2 id='same'>A</h2><div id='same'></div><h3 id='other'>B</h3>"), Some(["other"]))
  assert_eq(inventory_html_fragments("<p>No emitted targets</p>"), Some([]))
  assert_eq(inventory_html_fragments("<div id='a&unknown;'>A</div>"), None)
  assert_eq(inventory_html_fragments("<a name='a  b'></a>"), None)
  assert_eq(inventory_html_fragments("<a name='a b'></a>"), None)
  assert_eq(inventory_html_fragments("<div id='a&#32;&#32;b'></div>"), None)
  assert_eq(inventory_html_fragments("<div id=' leading'></div>"), None)
  assert_eq(inventory_html_fragments("<a name='&#128;'></a>"), None)
  assert_eq(inventory_html_fragments("<a name='&#x80;'></a>"), None)
  assert_eq(inventory_html_fragments("<a name='€'></a>"), Some(["€"]))
  assert_eq(inventory_html_fragments("<noscript><h2 id='conditional'>C</h2></noscript>"), None)
}

///|
test "inventory target comparison preserves legacy unknown versus known empty" {
  let legacy = "{\"version\":1,\"ready\":true,\"output_dir\":\"dist\",\"diagnostics\":[],\"entries\":[{\"path\":\"index.html\",\"kind\":\"page\",\"status\":\"planned\",\"source\":null,\"reason\":\"planned\"}]}"
  let known = legacy.replace_all(old="\"reason\":\"planned\"", new="\"reason\":\"planned\",\"fragments\":[\"old\"]")
  let empty = known.replace_all(old="[\"old\"]", new="[]")
  let unknown = match compare_inventory_targets(legacy, known) { Ok(value) => value; Err(error) => fail(error) }
  assert_eq(unknown.fragment_unknown, ["index.html"])
  assert_eq(unknown.fragment_compared, 0)
  let diff = match compare_inventory_targets(known, empty) { Ok(value) => value; Err(error) => fail(error) }
  assert_eq(diff.paths.unchanged, 1)
  assert_eq(diff.fragment_compared, 1)
  assert_eq(diff.fragment_changes[0].removed, ["old"])
  let old_api = match compare_inventories(known, empty) { Ok(value) => value; Err(error) => fail(error) }
  assert_eq(old_api.unchanged, 1)
  assert_eq(old_api.added, [])
}
