///|
/// SHA-256 of the same UTF-8 encoding used for authored HTML writes.
/// Artifact pairing only: not passage presence, freshness, or authenticity.
fn publication_digest(html : String) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode(html)))
}
