///|
pub(all) struct FragmentChange {
  path : String
  added : Array[String]
  removed : Array[String]
}

///|
pub(all) struct InventoryTargetComparison {
  paths : InventoryComparison
  fragment_changes : Array[FragmentChange]
  fragment_unknown : Array[String]
  fragment_compared : Int
}

///|
/// Called only after ordinary inventory validation; never opens a snapshot path.
fn snapshot_fragment_targets(source : String) -> Result[Map[String, Array[String]?], String] {
  let value = @json.parse(source[:]) catch { _ => return Err("invalid JSON") }
  guard value is Object(fields) && fields.get("entries") is Some(Array(entries)) else { return Err("missing entries") }
  let result : Map[String, Array[String]?] = Map([])
  for entry in entries {
    guard entry is Object(e) && e.get("path") is Some(String(path)) else { return Err("invalid entry") }
    if e.get("status") != Some(Json::string("planned")) || e.get("kind") == Some(Json::string("build_metadata")) || !inventory_is_html(path) { continue }
    match e.get("fragments") {
      None | Some(Null) => result.set(path, None)
      Some(Array(values)) => {
        let ids : Array[String] = []
        let seen : Map[String, Bool] = Map([])
        for value in values {
          guard value is String(id) && id != "" && !id.iter().any(c => c.is_ascii_control()) else { return Err("invalid fragment target for " + Json::string(path).stringify()) }
          if seen.contains(id) { return Err("duplicate fragment target for " + Json::string(path).stringify()) }
          seen.set(id, true)
          ids.push(id)
        }
        ids.sort_by((a, b) => a.lexical_compare(b))
        result.set(path, Some(ids))
      }
      _ => return Err("fragments must be an array or null for " + Json::string(path).stringify())
    }
  }
  Ok(result)
}

///|
/// Preserve the path-only API. Detailed comparison adds reliable target sets on
/// unchanged paths; absent legacy metadata is unknown rather than an empty set.
pub fn compare_inventory_targets(before : String, after : String) -> Result[InventoryTargetComparison, String] {
  let paths = match compare_inventories(before, after) { Ok(value) => value; Err(error) => return Err(error) }
  let old = match snapshot_fragment_targets(before) { Ok(value) => value; Err(error) => return Err("before: " + error) }
  let current = match snapshot_fragment_targets(after) { Ok(value) => value; Err(error) => return Err("after: " + error) }
  let changes : Array[FragmentChange] = []
  let unknown : Array[String] = []
  let mut compared = 0
  for (path, old_ids) in old {
    if !current.contains(path) { continue }
    match (old_ids, current.get(path).unwrap_or(None)) {
      (Some(old_ids), Some(new_ids)) => {
        compared = compared + 1
        let added = new_ids.filter(id => !old_ids.contains(id))
        let removed = old_ids.filter(id => !new_ids.contains(id))
        if !added.is_empty() || !removed.is_empty() { changes.push({ path, added, removed }) }
      }
      _ => unknown.push(path)
    }
  }
  changes.sort_by_key(change => change.path)
  unknown.sort_by((a, b) => a.lexical_compare(b))
  Ok({ paths, fragment_changes: changes, fragment_unknown: unknown, fragment_compared: compared })
}

///|
let inventory_target_notice : String = "Planned HTML file paths and scanner-verified unique fragment targets on common paths, relative to each output root. Missing/unsupported fragment metadata is unknown, not empty. No inferred moves, heading renames, URL/host mapping, content history or external-backlink coverage. No redirects or deletions. Preview snapshots do not prove deployment or future filesystem success."

///|
pub fn format_inventory_target_comparison_json(result : Result[InventoryTargetComparison, String]) -> String {
  let paths = match result { Ok(value) => Ok(value.paths); Err(error) => Err(error) }
  let json = inventory_comparison_json(paths)
  guard json is Object(fields) else { return json.stringify() }
  fields.set("notice", Json::string(inventory_target_notice))
  if result is Ok(value) {
    fields.set("fragments", Json::object(Map([
      ("scope", Json::string("verified_html_targets_v1")),
      ("compared", Json::number(value.fragment_compared.to_double())),
      ("unknown", Json::array(value.fragment_unknown.map(Json::string))),
      ("changes", Json::array(value.fragment_changes.map(change => Json::object(Map([
        ("path", Json::string(change.path)),
        ("added", Json::array(change.added.map(Json::string))),
        ("removed", Json::array(change.removed.map(Json::string))),
      ]))))),
    ])))
  }
  Json::object(fields).stringify()
}

///|
pub fn format_inventory_target_comparison(result : Result[InventoryTargetComparison, String]) -> String {
  let paths = match result { Ok(value) => Ok(value.paths); Err(error) => Err(error) }
  let lines = [format_inventory_comparison(paths).replace_all(old=inventory_diff_notice, new=inventory_target_notice)]
  if result is Ok(value) {
    lines.push("Fragment targets: " + value.fragment_compared.to_string() + " common paths compared, " + value.fragment_unknown.length().to_string() + " unknown")
    for path in value.fragment_unknown { lines.push("fragments unknown " + Json::string(path).stringify()) }
    for change in value.fragment_changes {
      for id in change.removed { lines.push("fragment removed " + Json::string(change.path).stringify() + " #" + Json::string(id).stringify()) }
      for id in change.added { lines.push("fragment added " + Json::string(change.path).stringify() + " #" + Json::string(id).stringify()) }
    }
  }
  lines.iter().join("\n")
}
