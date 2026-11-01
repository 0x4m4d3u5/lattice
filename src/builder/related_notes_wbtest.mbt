///|
test "related notes require a scalar or flat array Ref schema" {
  let fm = match @frontmatter.parse("---\ntitle: Guide\nrelated: [second, first, second]\n---\nBody") {
    Ok(value) => value
    Err(_) => fail("fixture must parse")
  }
  let schema : @schema.Schema = { name: "notes", fields: [{ name: "related", field_type: @schema.TOptional(@schema.TArray(@schema.TRef(None))), required: false }] }
  assert_eq(authored_related_notes(fm, schema), ["second", "first", "second"])
  let text_schema : @schema.Schema = { name: "notes", fields: [{ name: "related", field_type: @schema.TArray(@schema.TString(None, None)), required: false }] }
  assert_eq(authored_related_notes(fm, text_schema), [])
  assert_eq(related_notes_slot(fm, text_schema), "")
  assert_false(related_ref_type(@schema.TArray(@schema.TArray(@schema.TRef(None)))))
}
