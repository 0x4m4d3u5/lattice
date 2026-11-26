# Public Obsidian vault compatibility pass

Read-only `lattice check` and `lattice inventory` were run against a disposable
checkout of [Jim Briggs's public vault](https://github.com/jimbrig/obsidian_published/tree/0865fce060307cb6aadd041d88e29c864a62e8ef).
All 110 Markdown files under `docs/` were left unchanged. The fixture used
optional string title/author and an optional string-array tags field, accepted
body-only notes, and pointed data and output outside the vault. Nothing was
published.

| Case | Result |
| --- | --- |
| One collection rooted at `docs/` | Inventory planned four authored pages and reported itself ready, with warnings for unresolved links. Strict check rejected seven broken links, but neither diagnosed omission of the other 106 notes. |
| Explicit collection per directory (26) | Check reported 28 duplicate-slug diagnostics, 144 schema diagnostics, 81 dangling-tag diagnostics, and 20 broken-wikilink diagnostics. Inventory was not ready. There were 26 files named `index.md`; other duplicate basenames also occurred. |
| Scalar tags and unlisted frontmatter keys | Rejected. The schema diagnostics include both scalar tags and keys such as `creation date` and `modification date`. These counts are diagnostics, not numbers of affected notes. |
| Folder-qualified wikilinks | Rejected when the target is absent from the flat index. The fixture also checks that `[[folder/note]]` does not accidentally resolve to `folder-note.md`. |
| Unicode and reserved filename punctuation | A separate synthetic regression verifies check, planned output and emitted links for an emoji filename with `%` and a filename with `#`. `#` still introduces a heading fragment in wikilink syntax. |

This is not a successful full build or a retrieval benchmark. It does not
establish support for block references, transclusions, sized embeds, or
case-insensitive Unicode lookup. The largest observed admission issue is
non-recursive discovery combined with a flat slug namespace. Report the
omission explicitly before enabling recursive collection discovery by default.
