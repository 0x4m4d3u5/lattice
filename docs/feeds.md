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

## Configuration

Feeds use the following site configuration:
- `title`: Used for feed title and author name
- `base_url`: Used to construct absolute URLs for IDs and links
- `feed_limit`: Maximum number of entries to include (optional)

No additional configuration is required—feeds are generated automatically for all collections.
