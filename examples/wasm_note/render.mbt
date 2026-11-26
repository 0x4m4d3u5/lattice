///|
#export_name("render_note")
pub fn render_note(
  source : String,
  source_file : String,
  links_json : String,
) -> String {
  @note.render_note(source, source_file, links_json)
}

///|
/// Search a published content index without filesystem or network services.
#export_name("search_content")
pub fn search_content(
  index_json : String,
  query : String,
  tags_json : String,
  limit : Int,
) -> String {
  @search.search_content(index_json, query, tags_json, limit)
}
