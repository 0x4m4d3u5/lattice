///|
test "complete origins distinguish verbatim filtered duplicated and omitted emissions" {
  let slots = Map([(@template.Content, "abc")])
  for
    (source, expected) in [
      ("前🌱{{content}}", [(7, 3, 6)]),
      ("{{content}}{{content}}", [(7, 0, 3), (7, 3, 6)]),
      ("{{content | lower}}", [(7, -1, -1)]),
      ("{{content}}{{content | upper}}", [(7, 0, 3), (7, -1, -1)]),
      ("omitted", []),
      ("{{#each page.tags}}{{content}}{{/each}}", [(7, 0, 3), (7, 3, 6)]),
    ] {
    let template = match @template.parse_template(source) {
      Ok(value) => value
      Err(_) => abort("invalid fixture")
    }
    let ranges : Array[(Int32, Int32, Int32)] = []
    let result = @template.render_template_with_data(
      template,
      slots,
      @data.empty_store(),
      Map([]),
      Map([("tags", ["a", "b"])]),
      slot_ranges=Map([(@template.Content, [(7, 0, 3)])]),
      rendered_ranges=ranges,
    )
    assert_true(result is Ok(_))
    assert_eq(ranges, expected)
  }
}
