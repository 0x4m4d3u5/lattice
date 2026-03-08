///|
/// Content collection schema definitions.
///
/// A Schema declares the required and optional fields for a content collection.
/// Validation runs at build time: missing required fields, type mismatches, and
/// unrecognized fields are all errors surfaced before any HTML is rendered.
///
/// This is the load-bearing structural guarantee: every other SSG discovers
/// these violations at render time or at runtime. Here they are caught at the
/// schema validation step, which runs before the render pipeline begins.

/// Field type constraint.
pub enum FieldType {
  TString
  TInt
  TBool
  TArray(FieldType)
  TOptional(FieldType)
}

/// A single field definition in a schema.
pub struct FieldDef {
  name : String
  field_type : FieldType
  required : Bool
}

/// A content collection schema.
pub struct Schema {
  name : String
  fields : Array[FieldDef]
}

/// A validation error: the field name and what went wrong.
pub struct ValidationError {
  field : String
  message : String
}

/// Validate a parsed frontmatter map against a schema.
/// Returns all errors found (not just the first).
pub fn validate(
  fm : @frontmatter.Frontmatter,
  schema : Schema
) -> Array[ValidationError] {
  // TODO: implement validation
  []
}
