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
  TString(Int?, Int?) // (minlen, maxlen) — both optional; TString(None, None) accepts any string
  TDate(String?, String?) // (after, before) — both optional; TDate(None, None) accepts any date
  TInt(Int?, Int?) // (min, max) — both optional; TInt(None, None) accepts any integer
  TFloat(Double?, Double?) // (min, max) — both optional; TFloat(None, None) accepts any float
  TBool
  TArray(FieldType)
  TOptional(FieldType)
  TEnum(Array[String])
  TUrl
  TSlug
  TDateTime(String?, String?) // (after, before) — both optional; TDateTime(None, None) accepts any ISO 8601 datetime
  TRef(String?) // optional collection name constraint; None = any collection
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
pub fn field_type_name(ft : FieldType) -> String {
  match ft {
    TString(None, None) => "String"
    TString(Some(minlen), None) => "String(minlen=" + minlen.to_string() + ")"
    TString(None, Some(maxlen)) => "String(maxlen=" + maxlen.to_string() + ")"
    TString(Some(minlen), Some(maxlen)) =>
      "String(minlen=" +
      minlen.to_string() +
      ", maxlen=" +
      maxlen.to_string() +
      ")"
    TDate(None, None) => "Date"
    TDate(Some(after), None) => "Date(after=" + after + ")"
    TDate(None, Some(before)) => "Date(before=" + before + ")"
    TDate(Some(after), Some(before)) =>
      "Date(after=" + after + ", before=" + before + ")"
    TInt(None, None) => "Int"
    TInt(Some(min), None) => "Int(min=" + min.to_string() + ")"
    TInt(None, Some(max)) => "Int(max=" + max.to_string() + ")"
    TInt(Some(min), Some(max)) =>
      "Int(min=" + min.to_string() + ", max=" + max.to_string() + ")"
    TFloat(None, None) => "Float"
    TFloat(Some(min), None) => "Float(min=" + min.to_string() + ")"
    TFloat(None, Some(max)) => "Float(max=" + max.to_string() + ")"
    TFloat(Some(min), Some(max)) =>
      "Float(min=" + min.to_string() + ", max=" + max.to_string() + ")"
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
    TSlug => "Slug"
    TDateTime(None, None) => "DateTime"
    TDateTime(Some(after), None) => "DateTime(after=" + after + ")"
    TDateTime(None, Some(before)) => "DateTime(before=" + before + ")"
    TDateTime(Some(after), Some(before)) =>
      "DateTime(after=" + after + ", before=" + before + ")"
    TRef(None) => "Ref"
    TRef(Some(coll)) => "Ref[" + coll + "]"
  }
}

///|
/// Check whether a parsed value conforms to a field type.
/// TOptional matches the inner type — absence is handled in validate().
fn type_matches(val : @frontmatter.FrontmatterValue, ft : FieldType) -> Bool {
  match ft {
    TString(minlen, maxlen) =>
      match val {
        @frontmatter.FStr(s) => {
          let min_ok = match minlen {
            Some(lo) => s.length() >= lo
            None => true
          }
          let max_ok = match maxlen {
            Some(hi) => s.length() <= hi
            None => true
          }
          min_ok && max_ok
        }
        _ => false
      }
    TDate(after, before) =>
      match val {
        @frontmatter.FDate(s) => {
          let after_ok = match after {
            Some(lo) => s > lo
            None => true
          }
          let before_ok = match before {
            Some(hi) => s < hi
            None => true
          }
          after_ok && before_ok
        }
        _ => false
      }
    TInt(min, max) =>
      match val {
        @frontmatter.FInt(n) => {
          let min_ok = match min {
            Some(lo) => n >= lo
            None => true
          }
          let max_ok = match max {
            Some(hi) => n <= hi
            None => true
          }
          min_ok && max_ok
        }
        _ => false
      }
    TFloat(min, max) =>
      match val {
        @frontmatter.FFloat(n) => {
          let min_ok = match min {
            Some(lo) => n >= lo
            None => true
          }
          let max_ok = match max {
            Some(hi) => n <= hi
            None => true
          }
          min_ok && max_ok
        }
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
            if !type_matches(items[i], elem) {
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
          (
            @strutil.starts_with(s, "http://") ||
            @strutil.starts_with(s, "https://") ||
            @strutil.starts_with(s, "/")
          )
        _ => false
      }
    TSlug =>
      match val {
        @frontmatter.FStr(s) => is_valid_slug(s)
        _ => false
      }
    TDateTime(after, before) =>
      match val {
        @frontmatter.FStr(s) =>
          if !is_valid_iso8601_datetime(s) {
            false
          } else {
            let date_part = datetime_date_part(s)
            let after_ok = match after {
              Some(lo) => date_part > datetime_date_part(lo)
              None => true
            }
            let before_ok = match before {
              Some(hi) => date_part < datetime_date_part(hi)
              None => true
            }
            after_ok && before_ok
          }
        _ => false
      }
    TRef(_) =>
      // TRef structural check: value must be a string (valid slug format).
      // Existence against the page index is validated in validate_refs()
      // during pass 2, after the complete slug index is built.
      match val {
        @frontmatter.FStr(s) => is_valid_slug(s)
        _ => false
      }
  }
}

///|
/// Validate ISO 8601 datetime format: YYYY-MM-DDTHH:MM:SS with optional timezone.
///
/// Accepts:
/// - `2026-03-15T10:30:00Z`
/// - `2026-03-15T10:30:00+05:30`
/// - `2026-03-15T10:30:00-08:00`
/// - `2026-03-15T10:30:00` (no timezone, treated as local)
///
/// Rejects:
/// - `2026-03-15` (date-only, use TDate for this)
/// - `2026-03-15T10:30` (missing seconds)
/// - `not-a-datetime`
fn is_valid_iso8601_datetime(s : String) -> Bool {
  // Minimum length: "YYYY-MM-DDTHH:MM:SS" = 19 characters
  if s.length() < 19 {
    return false
  }
  // Check date part: YYYY-MM-DD (positions 0-9)
  if @strutil.char_at(s, 4) != '-' || @strutil.char_at(s, 7) != '-' {
    return false
  }
  // Check separator T (or space, some frontmatter uses space)
  let sep = @strutil.char_at(s, 10)
  if sep != 'T' && sep != ' ' {
    return false
  }
  // Check time part: HH:MM:SS (positions 11-18)
  if @strutil.char_at(s, 13) != ':' || @strutil.char_at(s, 16) != ':' {
    return false
  }
  // Validate digits in each position
  let digit_positions = [0, 1, 2, 3, 5, 6, 8, 9, 11, 12, 14, 15, 17, 18]
  let mut i = 0
  while i < digit_positions.length() {
    let pos = digit_positions[i]
    if pos >= s.length() {
      return false
    }
    let c = @strutil.char_at(s, pos)
    if c < '0' || c > '9' {
      return false
    }
    i = i + 1
  }
  // Validate month range (1-12)
  let month_1 = @strutil.char_at(s, 5).to_int() - '0'.to_int()
  let month_2 = @strutil.char_at(s, 6).to_int() - '0'.to_int()
  let month = month_1 * 10 + month_2
  if month < 1 || month > 12 {
    return false
  }
  // Validate day range (1-31, same as TDate)
  let day_1 = @strutil.char_at(s, 8).to_int() - '0'.to_int()
  let day_2 = @strutil.char_at(s, 9).to_int() - '0'.to_int()
  let day = day_1 * 10 + day_2
  if day < 1 || day > 31 {
    return false
  }
  // Validate hour range (0-23)
  let hour_1 = @strutil.char_at(s, 11).to_int() - '0'.to_int()
  let hour_2 = @strutil.char_at(s, 12).to_int() - '0'.to_int()
  let hour = hour_1 * 10 + hour_2
  if hour > 23 {
    return false
  }
  // Validate minute range (0-59)
  let min_1 = @strutil.char_at(s, 14).to_int() - '0'.to_int()
  let min_2 = @strutil.char_at(s, 15).to_int() - '0'.to_int()
  let minute = min_1 * 10 + min_2
  if minute > 59 {
    return false
  }
  // Validate second range (0-59)
  let sec_1 = @strutil.char_at(s, 17).to_int() - '0'.to_int()
  let sec_2 = @strutil.char_at(s, 18).to_int() - '0'.to_int()
  let second = sec_1 * 10 + sec_2
  if second > 59 {
    return false
  }
  // Validate optional timezone suffix
  if s.length() == 19 {
    return true // No timezone — valid local time
  }
  let tz_start = 19
  let tz_char = @strutil.char_at(s, tz_start)
  if tz_char == 'Z' {
    // Zulu time — must be the last character
    return s.length() == 20
  }
  if tz_char == '+' || tz_char == '-' {
    // Offset: +HH:MM or -HH:MM (total length = 25)
    if s.length() != 25 {
      return false
    }
    if @strutil.char_at(s, 22) != ':' {
      return false
    }
    // Validate offset hour digits (0-23)
    let off_h1 = @strutil.char_at(s, 20).to_int() - '0'.to_int()
    let off_h2 = @strutil.char_at(s, 21).to_int() - '0'.to_int()
    let off_hour = off_h1 * 10 + off_h2
    if off_hour > 23 {
      return false
    }
    // Validate offset minute digits (0-59)
    let off_m1 = @strutil.char_at(s, 23).to_int() - '0'.to_int()
    let off_m2 = @strutil.char_at(s, 24).to_int() - '0'.to_int()
    let off_min = off_m1 * 10 + off_m2
    if off_min > 59 {
      return false
    }
    return true
  }
  // Unknown suffix
  false
}

///|
/// Extract the date prefix (YYYY-MM-DD) from an ISO 8601 datetime string.
/// Used for bounds comparison — compares the date portion only, consistent
/// with how TDate bounds work. This is intentionally imprecise for timezone
/// edge cases (a datetime at 23:00+05:30 is a different UTC date than its
/// local date), but for content management (event dates, publish dates),
/// local date comparison is the expected behavior.
fn datetime_date_part(s : String) -> String {
  if s.length() >= 10 {
    @strutil.substr(s, 0, 10)
  } else {
    s
  }
}

///|
/// Check whether a string is a valid URL slug.
/// Valid slugs are non-empty and contain only ASCII lowercase letters,
/// digits, and hyphens.
fn is_valid_slug(s : String) -> Bool {
  if s.length() == 0 {
    return false
  }
  let mut i = 0
  let mut ok = true
  while i < s.length() {
    let c = s[i]
    let is_lower = c >= 97 && c <= 122
    let is_digit = c >= 48 && c <= 57
    let is_hyphen = c == 45
    if !(is_lower || is_digit || is_hyphen) {
      ok = false
      break
    }
    i = i + 1
  }
  ok
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
        if !type_matches(val, expected) {
          // Specialized error message for enum and slug mismatches
          let error_msg = match (expected, val) {
            (TString(minlen, maxlen), @frontmatter.FStr(s)) => {
              // Construct a length constraint description for the error message.
              // Truncate the actual value to ~30 chars for actionability.
              let display = if s.length() > 30 {
                @strutil.substr(s, 0, 30) + "..."
              } else {
                s
              }
              let constraint = match (minlen, maxlen) {
                (Some(lo), Some(hi)) =>
                  "minlen=" + lo.to_string() + ", maxlen=" + hi.to_string()
                (Some(lo), None) => "minlen=" + lo.to_string()
                (None, Some(hi)) => "maxlen=" + hi.to_string()
                (None, None) => "" // unreachable: TString(None,None) matches everything
              }
              "expected String with " +
              constraint +
              ", got length " +
              s.length().to_string() +
              ": \"" +
              display +
              "\""
            }
            (TEnum(_), @frontmatter.FStr(s)) =>
              "expected one of " +
              field_type_name(expected) +
              ", got \"" +
              s +
              "\""
            (TSlug, @frontmatter.FStr(s)) =>
              "expected a URL slug (lowercase alphanumeric and hyphens), got: \"" +
              s +
              "\""
            (TRef(_), @frontmatter.FStr(s)) =>
              "expected a valid slug reference, got: \"" + s + "\""
            (TDateTime(after, before), @frontmatter.FStr(s)) =>
              // If the value isn't even a valid datetime, say so.
              // Otherwise, construct a temporal range description.
              if !is_valid_iso8601_datetime(s) {
                "expected ISO 8601 datetime (YYYY-MM-DDTHH:MM:SS[Z|+HH:MM]), got: \"" +
                s +
                "\""
              } else {
                let range = match (after, before) {
                  (Some(lo), Some(hi)) => "after " + lo + " and before " + hi
                  (Some(lo), None) => "after " + lo
                  (None, Some(hi)) => "before " + hi
                  (None, None) => "" // unreachable
                }
                "expected DateTime " + range + ", got: " + s
              }
            (TDateTime(_), @frontmatter.FDate(s)) =>
              "expected ISO 8601 datetime (YYYY-MM-DDTHH:MM:SS[Z|+HH:MM]), got date-only value: " +
              s
            (TDate(after, before), @frontmatter.FDate(s)) => {
              // Construct a temporal range description for the error message.
              // "expected Date after 2020-01-01, got: 2019-12-31"
              let range = match (after, before) {
                (Some(lo), Some(hi)) => "after " + lo + " and before " + hi
                (Some(lo), None) => "after " + lo
                (None, Some(hi)) => "before " + hi
                (None, None) => "" // unreachable: TDate(None,None) matches everything
              }
              "expected Date " + range + ", got: " + s
            }
            (TInt(min, max), @frontmatter.FInt(n)) => {
              // Construct a range description for the error message.
              // "expected Int in range [1, 100], got: 0"
              let range = match (min, max) {
                (Some(lo), Some(hi)) =>
                  "[" + lo.to_string() + ", " + hi.to_string() + "]"
                (Some(lo), None) => "[" + lo.to_string() + ", ∞)"
                (None, Some(hi)) => "(-∞, " + hi.to_string() + "]"
                (None, None) => "" // unreachable: TInt(None,None) matches everything
              }
              "expected Int in range " + range + ", got: " + n.to_string()
            }
            (TFloat(min, max), @frontmatter.FFloat(n)) => {
              // Construct a range description for the error message.
              // "expected Float in range [0.0, 5.0], got: -1.0"
              let range = match (min, max) {
                (Some(lo), Some(hi)) =>
                  "[" + lo.to_string() + ", " + hi.to_string() + "]"
                (Some(lo), None) => "[" + lo.to_string() + ", ∞)"
                (None, Some(hi)) => "(-∞, " + hi.to_string() + "]"
                (None, None) => "" // unreachable: TFloat(None,None) matches everything
              }
              "expected Float in range " + range + ", got: " + n.to_string()
            }
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
    "toc", "toc_depth", "draft", "template", "redirect_from", "og_image", "weight",
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

///|
/// Cross-reference validation for TRef fields.
///
/// This runs in pass 2, after the complete slug→collection page index is built.
/// For each schema field of type TRef(coll?), checks that the field value (a slug)
/// exists in the page index. If coll is Some(collection), also checks that the
/// referenced slug belongs to the specified collection.
///
/// Returns an array of validation errors for broken references.
pub fn validate_refs(
  fm : @frontmatter.Frontmatter,
  schema : Schema,
  page_index : Map[String, String], // slug → collection name
) -> Array[ValidationError] {
  let errors : Array[ValidationError] = []
  let mut i = 0
  while i < schema.fields.length() {
    let fdef = schema.fields[i]
    // Extract the inner type from TOptional wrappers
    let inner_type = match fdef.field_type {
      TOptional(inner) => inner
      t => t
    }
    match inner_type {
      TRef(expected_coll) =>
        match fm.fields.get(fdef.name) {
          None => () // field absent — fine for optional, handled by validate()
          Some(val) =>
            match val {
              @frontmatter.FStr(slug) =>
                match page_index.get(slug) {
                  None =>
                    errors.push({
                      field: fdef.name,
                      message: "TRef: references unknown slug '" + slug + "'",
                    })
                  Some(coll_name) =>
                    match expected_coll {
                      Some(expected) =>
                        if coll_name != expected {
                          errors.push({
                            field: fdef.name,
                            message: "TRef: references slug '" +
                            slug +
                            "' from collection '" +
                            coll_name +
                            "' but expected '" +
                            expected +
                            "'",
                          })
                        }
                      None => () // any collection is fine
                    }
                }
              _ => () // non-string values caught by type_matches in validate()
            }
        }
      TArray(TRef(expected_coll)) =>
        // Array-of-refs: each element is a slug that must exist in the page index.
        // This is the TArray(TRef(...)) case — a field like related_posts = ["a", "b"]
        // where each element is cross-checked against the slug→collection map.
        match fm.fields.get(fdef.name) {
          None => () // field absent — fine for optional, handled by validate()
          Some(val) =>
            match val {
              @frontmatter.FArray(items) => {
                let mut j = 0
                while j < items.length() {
                  match items[j] {
                    @frontmatter.FStr(slug) =>
                      match page_index.get(slug) {
                        None =>
                          errors.push({
                            field: fdef.name,
                            message: "TRef: " +
                            fdef.name +
                            "[" +
                            j.to_string() +
                            "]: unknown slug '" +
                            slug +
                            "'",
                          })
                        Some(coll_name) =>
                          match expected_coll {
                            Some(expected) =>
                              if coll_name != expected {
                                errors.push({
                                  field: fdef.name,
                                  message: "TRef: " +
                                  fdef.name +
                                  "[" +
                                  j.to_string() +
                                  "]: references slug '" +
                                  slug +
                                  "' from collection '" +
                                  coll_name +
                                  "' but expected '" +
                                  expected +
                                  "'",
                                })
                              }
                            None => () // any collection is fine
                          }
                      }
                    _ => () // non-string elements caught by type_matches in validate()
                  }
                  j = j + 1
                }
              }
              _ => () // non-array values caught by type_matches in validate()
            }
        }
      _ => () // not a TRef field
    }
    i = i + 1
  }
  errors
}
