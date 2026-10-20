---
title: The system map
description: How source files, validation and templates fit together to produce the wiki.
toc: true
tags: [Architecture]
---
## Source to page

The source is a set of Markdown notes. Frontmatter describes each note, collections organize related pages, and templates determine their published layout.

1. Read and validate the source.
2. Resolve links against the known pages.
3. Render the final HTML and supporting indexes.

## One published source

The reader uses the same published pages as ordinary links. Search uses the content index to find passages; it does not generate another version of the note.

See [[finding-a-passage]] for how the directory and search support different ways of reading.
