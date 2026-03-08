///|
/// Frontmatter parsing and typed schema enforcement.
///
/// Design intent: every content file has a frontmatter block delimited by `---`.
/// The parsed result is a typed `FrontmatterValue` tree. Schema validation
/// converts that tree into a user-defined struct, and mismatches are type
/// errors caught at build time, not render time.

/// A raw frontmatter value parsed from TOML-style key-value pairs.
pub enum FrontmatterValue {
  FStr(String)
  FInt(Int)
  FBool(Bool)
  FArray(Array[FrontmatterValue])
  FMap(Map[String, FrontmatterValue])
}

/// A parsed frontmatter block: the raw map plus the remaining document body.
pub struct Frontmatter {
  fields : Map[String, FrontmatterValue]
  body : String
}

/// Parse the leading `---`-delimited block from a file's content.
/// Returns an error string if the delimiter is missing or malformed.
pub fn parse(content : String) -> Result[Frontmatter, String] {
  // TODO: implement TOML-style key-value parsing
  Err("not implemented")
}
