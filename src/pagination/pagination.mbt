///|
/// Typed pagination model for index-style pages.
pub struct PaginatedIndex[T] {
  page_number : Int
  total_pages : Int
  page_size : Int
  total_items : Int
  documents : Array[T]
  prev_url : String?
  next_url : String?
}

///|
/// Split a document list into typed pages.
///
/// - `page_size <= 0` is normalized to `1`.
/// - Empty document lists still produce one logical page.
pub fn[T] paginate(
  documents : Array[T],
  page_size : Int,
  page_url_for : (Int) -> String,
) -> Array[PaginatedIndex[T]] {
  let effective_page_size = if page_size > 0 { page_size } else { 1 }
  let total_items = documents.length()
  let total_pages = if total_items == 0 {
    1
  } else {
    // Subtract before dividing: adding page_size can overflow for valid Int sizes.
    1 + (total_items - 1) / effective_page_size
  }

  let pages : Array[PaginatedIndex[T]] = []
  let mut page_number = 1
  while page_number <= total_pages {
    let start = (page_number - 1) * effective_page_size
    // Bound the end before adding so a partial final page cannot overflow.
    let end_pos = if effective_page_size >= total_items - start {
      total_items
    } else {
      start + effective_page_size
    }

    let page_documents : Array[T] = []
    let mut i = start
    while i < end_pos {
      page_documents.push(documents[i])
      i = i + 1
    }

    let prev_url = if page_number > 1 {
      Some(page_url_for(page_number - 1))
    } else {
      None
    }
    let next_url = if page_number < total_pages {
      Some(page_url_for(page_number + 1))
    } else {
      None
    }

    pages.push({
      page_number,
      total_pages,
      page_size: effective_page_size,
      total_items,
      documents: page_documents,
      prev_url,
      next_url,
    })
    page_number = page_number + 1
  }

  pages
}
