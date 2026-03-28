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

///|
/// Field type constraint.
pub(all) enum FieldType {
  TString
  TDate
  TInt
  TBool
  TArray(FieldType)
  TOptional(FieldType)
  TEnum(Array[String])
  TUrl
}

///|
/// A single field definition in a schema.
pub(all) struct FieldDef {
  name : String
  field_type : FieldType
  required : Bool
}

///|
/// A content collection schema.
pub(all) struct Schema {
  name : String
  fields : Array[FieldDef]
}

///|
/// A validation error: the field name and what went wrong.
pub(all) struct ValidationError {
  field : String
  message : String
}

// ── helpers ───────────────────────────────────────────────────────────────────

///|
fn field_type_name(ft : FieldType) -> String {
  match ft {
    TString => "String"
    TDate => "Date"
    TInt => "Int"
    TBool => "Bool"
    TArray(inner) => "Array[" + field_type_name(inner) + "]"
    TOptional(inner) => "Optional[" + field_type_name(inner) + "]"
    TEnum(allowed) => {
      let mut result = "Enum["
      let mut i = 0
      while i < allowed.length() {
        if i > 0 {
          result = result + ","
        }
        result = result + "\"" + allowed[i] + "\""
        i = i + 1
      }
      result + "]"
    }
    TUrl => "Url"
  }
}

///|
/// Check whether a parsed value conforms to a field type.
/// TOptional matches the inner type — absence is handled in validate().
fn type_matches(val : @frontmatter.FrontmatterValue, ft : FieldType) -> Bool {
  match ft {
    TString =>
      match val {
        @frontmatter.FStr(_) => true
        _ => false
      }
    TDate =>
      match val {
        @frontmatter.FDate(_) => true
        _ => false
      }
    TInt =>
      match val {
        @frontmatter.FInt(_) => true
        _ => false
      }
    TBool =>
      match val {
        @frontmatter.FBool(_) => true
        _ => false
      }
    TArray(elem) =>
      match val {
        @frontmatter.FArray(items) => {
          let mut ok = true
          let mut i = 0
          while i < items.length() {
            if not(type_matches(items[i], elem)) {
              ok = false
              break
            }
            i = i + 1
          }
          ok
        }
        _ => false
      }
    TOptional(inner) => type_matches(val, inner)
    TEnum(allowed) =>
      match val {
        @frontmatter.FStr(s) => {
          let mut found = false
          let mut i = 0
          while i < allowed.length() {
            if s == allowed[i] {
              found = true
              break
            }
            i = i + 1
          }
          found
        }
        _ => false
      }
    TUrl =>
      match val {
        @frontmatter.FStr(s) =>
          s.length() > 0 &&
          (@strutil.starts_with(s, "http://") ||
            @strutil.starts_with(s, "https://") ||
            @strutil.starts_with(s, "/"))
        _ => false
      }
  }
}

// ── public API ────────────────────────────────────────────────────────────────

///|
/// Validate a parsed frontmatter map against a schema.
/// Returns all errors found — missing required fields, type mismatches,
/// and fields not declared in the schema.
pub fn validate(
  fm : @frontmatter.Frontmatter,
  schema : Schema,
) -> Array[ValidationError] {
  let errors : Array[ValidationError] = []
  // Phase 1: check declared fields
  let mut i = 0
  while i < schema.fields.length() {
    let fdef = schema.fields[i]
    match fm.fields.get(fdef.name) {
      None =>
        if fdef.required {
          errors.push({ field: fdef.name, message: "required field missing" })
        }
      // optional absent fields are fine
      Some(val) => {
        // unwrap Optional for matching — absence is already handled above
        let expected = match fdef.field_type {
          TOptional(inner) => inner
          t => t
        }
        if not(type_matches(val, expected)) {
          // Specialized error message for enum mismatches
          let error_msg = match (expected, val) {
            (TEnum(_), @frontmatter.FStr(s)) =>
              "expected one of " +
              field_type_name(expected) +
              ", got \"" +
              s +
              "\""
            _ =>
              "expected " +
              field_type_name(expected) +
              " but got incompatible value"
          }
          errors.push({ field: fdef.name, message: error_msg })
        }
      }
    }
    i = i + 1
  }
  // Phase 2: detect unrecognized fields
  // Reserved keys are consumed by the lattice builder itself and are never
  // user-schema fields — flagging them as unrecognized would be a false positive.
  let reserved = [
    "toc", "toc_depth", "draft", "template", "redirect_from", "og_image",
  ]
  let valid_fields = Map::new()
  let mut j = 0
  while j < schema.fields.length() {
    valid_fields.set(schema.fields[j].name, true)
    j = j + 1
  }
  let mut k = 0
  while k < reserved.length() {
    valid_fields.set(reserved[k], true)
    k = k + 1
  }
  for key, _ in fm.fields {
    match valid_fields.get(key) {
      None =>
        errors.push({
          field: key,
          message: "unrecognized field not declared in schema",
        })
      _ => () // field is valid
    }
  }
  errors
}
