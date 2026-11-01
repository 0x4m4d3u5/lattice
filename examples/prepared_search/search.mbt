///|
let current : Ref[@search.PreparedSearch?] = { val: None, }

///|
/// Invalidate first, including when replacement fails. One slot, no handle cache.
pub fn replace_index(index : String) -> Bool {
  current.val = None
  match @search.prepare_search(index) {
    Ok(prepared) => {
      current.val = Some(prepared)
      true
    }
    Err(_) => false
  }
}

///|
pub fn clear_index() -> Unit {
  current.val = None
}

///|
pub fn query_index(query : String, tags : String, limit : Int32) -> String {
  match current.val {
    Some(prepared) => prepared.search(query, tags, limit)
    None => "{\"results\":[],\"error\":\"no prepared index\"}"
  }
}
