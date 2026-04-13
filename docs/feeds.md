# RSS/Atom Feeds

Lattice generates Atom 1.0 feeds for each content collection. Feeds are automatically generated during the build process and written to `<collection>/feed.xml` in the output directory.

## Feed Location

For a `posts` collection, the feed is generated at:
```
dist/posts/feed.xml
```

For a `projects` collection:
```
dist/projects/feed.xml
```

## Feed Content

Each feed includes:
- **Feed metadata**: title, ID, link, author, and updated timestamp
- **Entries**: one per page in the collection, sorted by date (newest first)
- **Entry details**:
  - `<title>`: Page title from frontmatter
  - `<id>`: Absolute URL to the page
  - `<link>`: Permalink to the page
  - `<updated>`: Page's normalized RFC3339 timestamp
  - `<published>`: Publication date (same as updated)
  - `<summary>`: Page description from frontmatter (if present)

## Date Handling

Lattice normalizes dates to RFC3339 format for Atom feeds:
- `YYYY-MM-DD` → `YYYY-MM-DDT00:00:00Z`
- Full RFC3339 timestamps are preserved as-is
- Pages without dates are excluded from feed sorting (they appear last)

## Feed Limit

To limit the number of entries in a feed, set `feed_limit` in your site config:

```cfg
feed_limit = 20
```

This limits each collection's feed to the 20 most recent posts. If not specified, all posts are included in the feed.

## Example Feed

```xml
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>My Site (posts)</title>
  <id>https://example.com/</id>
  <link href="https://example.com/" />
  <updated>2024-03-15T00:00:00Z</updated>
  <author><name>My Site (posts)</name></author>
  <entry>
    <title>My Latest Post</title>
    <id>https://example.com/posts/my-latest-post/</id>
    <link href="https://example.com/posts/my-latest-post/" />
    <updated>2024-03-15T00:00:00Z</updated>
    <published>2024-03-15T00:00:00Z</published>
    <summary>A brief description of the post</summary>
  </entry>
</feed>
```

## Linking Feeds

To make feeds discoverable, add `<link rel="alternate">` tags in your `<head>`:

```html
<head>
  <link rel="alternate" type="application/atom+xml" 
        title="Posts Feed" 
        href="/posts/feed.xml" />
</head>
```

This allows feed readers and browsers to auto-discover your site's feeds.

## JSON Feed 1.1

Lattice also generates a [JSON Feed 1.1](https://www.jsonfeed.org/version/1.1/) for each collection, written to `<collection>/feed.json`:

```json
{
  "version": "https://jsonfeed.org/version/1.1",
  "title": "My Site (posts)",
  "home_page_url": "https://example.com/",
  "feed_url": "https://example.com/posts/feed.json",
  "items": [
    {
      "id": "https://example.com/posts/my-post/",
      "url": "https://example.com/posts/my-post/",
      "title": "My Post",
      "content_html": "<p>Hello world</p>",
      "date_published": "2024-03-15T00:00:00Z"
    }
  ]
}
```

When `site_feed_enabled` is true (default), a site-wide feed is also generated at `/feed.xml` and `/feed.json` in the output root, aggregating entries from all collections sorted by date.

## Content Index

Lattice emits a `content-index.json` file at the site root alongside other build artifacts. This provides programmatic access to all site content for JavaScript search clients (Fuse.js, Lunr, etc.) and build pipelines that need to index or query content without parsing HTML.

### Enabling the Content Index

Add to your site config:

```cfg
content_index_file = content-index.json
```

If omitted, the content index is not generated. The filename is configurable so you can name it to match your search client's expectations.

### Entry Schema

Each entry in the JSON array has the following fields:

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Page title from frontmatter |
| `slug` | string | URL-safe slug |
| `url` | string | Relative URL path (e.g., `/posts/hello/`) |
| `tags` | string[] | Tags from frontmatter (empty array if none) |
| `collection` | string | Collection name, or `_standalone` for standalone pages, `_root` for the root page |
| `date` | string | Publication date in `YYYY-MM-DD` format (empty string if none) |
| `description` | string | Meta description from frontmatter (empty string if none) |
| `kind` | string | Page type: `"post"` (collection item with date), `"page"` (collection item without date), `"standalone"` (standalone page), or `"collection_index"` (auto-generated index) |
| `reading_time` | number \| null | Estimated reading time in minutes at ~225 wpm, or `null` if the page has no body text |
| `body` | string | Full stripped plaintext body — HTML tags removed, suitable for full-text search |

### Coverage

The content index covers:
- **Collection items**: all pages in every configured collection (excluding drafts)
- **Standalone pages**: pages in the `standalone_dir`
- **Root page**: the page configured via `root_page`
- **Collection indexes**: the auto-generated index page for each collection (page 1 only)

### Example

```json
[
  {
    "title": "Typed Content Tour",
    "slug": "typed-content-tour",
    "url": "/posts/typed-content-tour/",
    "tags": ["demo", "moonbit"],
    "collection": "posts",
    "date": "2026-03-18",
    "description": "One post that exercises YAML frontmatter and code fences.",
    "kind": "post",
    "reading_time": 1,
    "body": "Typed Content Tour This post is the main inspection target..."
  },
  {
    "title": "About",
    "slug": "about",
    "url": "/about/",
    "tags": [],
    "collection": "_standalone",
    "date": "",
    "description": "Notes on the example site.",
    "kind": "standalone",
    "reading_time": 1,
    "body": "About This Example The purpose of this site is breadth..."
  }
]
```

### Difference from Search Index

Lattice also emits a `search-index.json` (configurable via `search_index_file`) that contains only excerpts. The content index stores the **full plaintext body**, making it suitable for:
- Client-side full-text search (Fuse.js, Lunr, MiniSearch)
- LLM/agent RAG pipelines that need complete page content
- Build-tool integrations that query site content programmatically

Use `search-index.json` for lightweight search suggestions and `content-index.json` when you need complete content.

## Configuration

Feeds and indexes use the following site configuration:
- `title`: Used for feed title and author name
- `base_url`: Used to construct absolute URLs for IDs and links
- `feed_limit`: Maximum number of entries per collection feed (optional)
- `site_feed_enabled`: Generate site-wide `feed.xml` and `feed.json` at the output root (default: true)
- `search_index_file`: Filename for the excerpt-only search index (default: `search-index.json`)
- `content_index_file`: Filename for the full-text content index (omit to disable)

No additional configuration is required—Atom and JSON feeds are generated automatically for all collections. The content index is opt-in via `content_index_file`.
