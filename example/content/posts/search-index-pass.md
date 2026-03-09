---
title = Search Index Generation Pass
date = "2024-02-06"
tags = [search, indexing, metadata]
---
# Search Index Pass

The builder emits a `search-index.json` file for lightweight client-side lookup. This makes content discoverable without adding a runtime backend. Validation tooling in [[lint-mode]] ensures the index is built from structurally valid pages.
