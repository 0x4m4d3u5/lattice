///|
fn page_url(page_number : Int) -> String {
  "/posts/page/" + page_number.to_string() + "/"
}

///|
test "pagination returns one logical page for empty input" {
  let docs : Array[Int] = []
  let pages = paginate(docs, 5, page_url)
  assert_eq(pages.length(), 1)
  assert_eq(pages[0].page_number, 1)
  assert_eq(pages[0].total_pages, 1)
  assert_eq(pages[0].total_items, 0)
  assert_eq(pages[0].documents.length(), 0)
  match pages[0].prev_url {
    None => ()
    Some(_) => assert_true(false)
  }
  match pages[0].next_url {
    None => ()
    Some(_) => assert_true(false)
  }
}

///|
test "pagination normalizes non positive page size to one" {
  let pages = paginate([1, 2, 3], 0, page_url)
  assert_eq(pages.length(), 3)
  assert_eq(pages[0].page_size, 1)
  assert_eq(pages[0].documents.length(), 1)
  assert_eq(pages[1].documents[0], 2)
  match pages[1].prev_url {
    Some(url) => assert_eq(url, "/posts/page/1/")
    None => assert_true(false)
  }
  match pages[1].next_url {
    Some(url) => assert_eq(url, "/posts/page/3/")
    None => assert_true(false)
  }
}

///|
test "pagination splits exact and partial final pages correctly" {
  let pages = paginate(["a", "b", "c", "d", "e"], 2, page_url)
  assert_eq(pages.length(), 3)
  assert_eq(pages[0].documents.length(), 2)
  assert_eq(pages[1].documents.length(), 2)
  assert_eq(pages[2].documents.length(), 1)
  assert_eq(pages[2].documents[0], "e")
  match pages[0].prev_url {
    None => ()
    Some(_) => assert_true(false)
  }
  match pages[0].next_url {
    Some(url) => assert_eq(url, "/posts/page/2/")
    None => assert_true(false)
  }
  match pages[2].next_url {
    None => ()
    Some(_) => assert_true(false)
  }
}

///|
test "pagination exactly fills one page produces single page no nav" {
  let pages = paginate([1, 2, 3], 3, page_url)
  assert_eq(pages.length(), 1)
  assert_eq(pages[0].page_number, 1)
  assert_eq(pages[0].total_pages, 1)
  assert_eq(pages[0].total_items, 3)
  assert_eq(pages[0].documents.length(), 3)
  match pages[0].prev_url {
    None => ()
    Some(_) => assert_true(false)
  }
  match pages[0].next_url {
    None => ()
    Some(_) => assert_true(false)
  }
}

///|
test "pagination one item over page size splits into two pages" {
  let pages = paginate([1, 2, 3, 4], 3, page_url)
  assert_eq(pages.length(), 2)
  assert_eq(pages[0].documents.length(), 3)
  assert_eq(pages[1].documents.length(), 1)
  assert_eq(pages[1].documents[0], 4)
  assert_eq(pages[0].total_pages, 2)
  assert_eq(pages[1].total_pages, 2)
  match pages[0].next_url {
    Some(url) => assert_eq(url, "/posts/page/2/")
    None => assert_true(false)
  }
  match pages[1].prev_url {
    Some(url) => assert_eq(url, "/posts/page/1/")
    None => assert_true(false)
  }
  match pages[1].next_url {
    None => ()
    Some(_) => assert_true(false)
  }
}

///|
test "pagination metadata fields are consistent across all pages" {
  let docs = [1, 2, 3, 4, 5, 6, 7]
  let pages = paginate(docs, 3, page_url)
  assert_eq(pages.length(), 3)
  let mut i = 0
  while i < pages.length() {
    assert_eq(pages[i].total_pages, 3)
    assert_eq(pages[i].total_items, 7)
    assert_eq(pages[i].page_size, 3)
    assert_eq(pages[i].page_number, i + 1)
    i = i + 1
  }
  // First page: no prev, has next
  match pages[0].prev_url {
    None => ()
    Some(_) => assert_true(false)
  }
  match pages[0].next_url {
    Some(_) => ()
    None => assert_true(false)
  }
  // Last page: has prev, no next
  match pages[2].prev_url {
    Some(_) => ()
    None => assert_true(false)
  }
  match pages[2].next_url {
    None => ()
    Some(_) => assert_true(false)
  }
}
