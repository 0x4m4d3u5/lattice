# Content index for knowledge retrieval

Enable the full-text JSON output in `site.cfg`:

```cfg
content_index_file = content-index.json
```

After `lattice build`, the output directory contains an array of entries with
`title`, `slug`, `url`, `tags`, `collection`, `date`, `description`, `kind`,
`reading_time` and `body`. Use `url` to link a retrieved result back to its page.
The body covers the rendered content, while `search-index.json` carries an
excerpt. These files supply data for a retrieval tool; they do not implement a
search engine or embeddings.

Body extraction removes tags, decodes basic entities and collapses whitespace.
Text-bearing phrasing tags preserve adjacency: `a`, `strong`, `em`, `del`,
`code`, `span`, `sub`, `sup`, `mark`, `abbr`, `kbd`, `b`, `i`, `u`, `s`, `small`,
`cite`, `q`, `dfn`, `data`, `time`, `var`, `samp`, `bdi`, `bdo`, `ruby`, `rt`,
`rp`, `ins`, `label` and `output`. The optional word-break tag `wbr` also
preserves adjacency. For example, `photo**syn**thesis` becomes `photosynthesis`,
`H<sub>2</sub>O` becomes `H2O`, and `<kbd>Ctrl</kbd>+<kbd>C</kbd>` becomes
`Ctrl+C`. Other tags create separators, including paragraph, list, table and
line-break boundaries. Authored spaces around inline markup remain spaces.
The same extraction applies when a page is reused from cache.

This is a simple text extractor, not a complete HTML parser or sanitizer.
Unknown tags create separators, image attributes are not body text, and raw
script/style text is not filtered. The index is generated site content;
draft filtering and vault metadata are not access controls or a privacy boundary.

Run `bash scripts/check-baseline.sh` with the repository-pinned toolchain to
check the CLI's content index alongside rendered pages and link metadata.
