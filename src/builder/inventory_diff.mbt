///|
pub(all) struct InventoryComparison {
  added : Array[String]
  removed : Array[String]
  unchanged : Int
  before_warnings : Int
  after_warnings : Int
}

///|
fn inventory_html_paths(
  source : String,
) -> Result[(Map[String, Bool], Int), String] {
  let value = @json.parse(source[:]) catch { _ => return Err("invalid JSON") }
  guard value is Object(fields) && fields.get("version") is Some(Number(1, ..)) else {
    return Err("expected a version 1 publication inventory")
  }
  guard fields.get("ready") is Some(True) else {
    return Err("inventory must be ready, not blocked")
  }
  guard fields.get("output_dir") is Some(String(_)) &&
    fields.get("entries") is Some(Array(entries)) &&
    fields.get("diagnostics") is Some(Array(diagnostics)) else {
    return Err("inventory is missing output_dir, entries or diagnostics")
  }
  let mut warnings = 0
  for diagnostic in diagnostics {
    guard diagnostic is Object(d) &&
      d.get("severity") is Some(String(severity)) &&
      d.get("message") is Some(String(_)) else {
      return Err("invalid inventory diagnostic")
    }
    if severity != "warning" {
      return Err(
        "ready inventory must not contain errors or unknown severities",
      )
    }
    warnings = warnings + 1
  }
  let planned : Map[String, Bool] = Map([])
  let html : Map[String, Bool] = Map([])
  for entry in entries {
    guard entry is Object(e) &&
      e.get("path") is Some(String(path)) &&
      e.get("kind") is Some(String(kind)) &&
      e.get("status") is Some(String(status)) &&
      e.get("reason") is Some(String(_)) else {
      return Err("invalid inventory entry")
    }
    match e.get("source") {
      Some(Null) | Some(String(_)) => ()
      _ => return Err("entry source must be a string or null")
    }
    if !["page", "generated", "static_asset", "build_metadata"].contains(kind) ||
      !["planned", "excluded"].contains(status) {
      return Err("unknown entry kind or status")
    }
    if path.is_empty() {
      return Err("entry path must not be empty")
    }
    if status == "planned" {
      if planned.contains(path) {
        return Err("duplicate planned path: " + Json::string(path).stringify())
      }
      planned.set(path, true)
      let lower = path.to_lower()
      if kind != "build_metadata" &&
        (lower.has_suffix(".html") || lower.has_suffix(".htm")) {
        html.set(path, true)
      }
    }
  }
  Ok((html, warnings))
}

///|
/// Compare two explicit snapshots, never the partial cache/manifest or disk.
pub fn compare_inventories(
  before : String,
  after : String,
) -> Result[InventoryComparison, String] {
  let (old, before_warnings) = match inventory_html_paths(before) {
    Ok(v) => v
    Err(e) => return Err("before: " + e)
  }
  let (current, after_warnings) = match inventory_html_paths(after) {
    Ok(v) => v
    Err(e) => return Err("after: " + e)
  }
  let added : Array[String] = []
  let removed : Array[String] = []
  let mut unchanged = 0
  for (path, _) in current {
    if old.contains(path) {
      unchanged = unchanged + 1
    } else {
      added.push(path)
    }
  }
  for (path, _) in old {
    if !current.contains(path) {
      removed.push(path)
    }
  }
  added.sort_by((a, b) => a.lexical_compare(b))
  removed.sort_by((a, b) => a.lexical_compare(b))
  Ok({ added, removed, unchanged, before_warnings, after_warnings, })
}

///|
let inventory_diff_notice : String = "Planned HTML file paths only (.html/.htm), relative to each output root. No inferred moves, URL/host mapping, content or heading history, external-backlink coverage. No redirects or deletions are performed. Excluded entries, build metadata and non-HTML files are omitted. Preview snapshots do not prove deployment or future filesystem success."

///|
pub fn format_inventory_comparison_json(
  result : Result[InventoryComparison, String],
) -> String {
  let fields : Map[String, Json] = Map([
    ("version", Json::number(1)),
    ("scope", Json::string("planned_html_paths")),
    ("notice", Json::string(inventory_diff_notice)),
  ])
  match result {
    Err(error) => {
      fields.set("ready", Json::boolean(false))
      fields.set("error", Json::string(error))
    }
    Ok(diff) => {
      fields.set("ready", Json::boolean(true))
      fields.set("added", Json::array(diff.added.map(Json::string)))
      fields.set("removed", Json::array(diff.removed.map(Json::string)))
      fields.set("unchanged", Json::number(diff.unchanged.to_double()))
      fields.set(
        "before_warnings",
        Json::number(diff.before_warnings.to_double()),
      )
      fields.set(
        "after_warnings",
        Json::number(diff.after_warnings.to_double()),
      )
    }
  }
  Json::object(fields).stringify()
}

///|
pub fn format_inventory_comparison(
  result : Result[InventoryComparison, String],
) -> String {
  let lines = ["Publication inventory comparison", inventory_diff_notice]
  match result {
    Err(error) => lines.push("Blocked: " + error)
    Ok(diff) => {
      lines.push(
        diff.added.length().to_string() +
        " added, " +
        diff.removed.length().to_string() +
        " removed, " +
        diff.unchanged.to_string() +
        " unchanged paths (contents not compared)",
      )
      lines.push(
        "Snapshot warnings: before=" +
        diff.before_warnings.to_string() +
        ", after=" +
        diff.after_warnings.to_string(),
      )
      for path in diff.removed {
        lines.push("removed " + Json::string(path).stringify())
      }
      for path in diff.added {
        lines.push("added " + Json::string(path).stringify())
      }
    }
  }
  lines.iter().join("\n")
}
