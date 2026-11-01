# Author-selected related notes

A collection can opt into reader recommendations with a typed frontmatter field
named `related`:

```ini
[notes]
dir = content/notes
schema = title:String,related:Optional[Array[Ref[notes]]]
```

```yaml
---
title: A reading guide
related: [design-notes, publishing-guide]
---
```

The bundled wiki reader shows a quiet **Related notes** section, labeled
“Selected by the author.” Custom page templates can place `{{related_notes}}`
verbatim wherever the section belongs. No JavaScript is needed. Templates that
omit the slot do not show recommendations. Do not apply text filters to this
HTML slot or wrap it in a conditional container: its final contents are resolved
against publication ownership after template rendering, and can be empty.

Supported schema types are `Ref`, `Ref[collection]`, and a flat `Array` of either,
optionally wrapped in `Optional`. A scalar reference selects one note. A field
with another type is not a recommendation contract. The field remains subject
to normal schema validation: use canonical slugs, not wikilink aliases, titles,
URLs, or fragments. Missing slugs and wrong-collection references produce the
existing source diagnostics; they are not silently repaired.

Recommendations preserve authored order. Repeated canonical destinations and
self-links are removed. Hidden drafts and pages whose canonical output is
replaced by generated or static content are omitted. `--drafts` includes draft
recommendations when it includes their pages. Titles and URLs come from the
published destination, with normal HTML escaping. Missing/empty metadata or a
list with no available destinations produces no section. A later destination
title edit, draft change or output replacement is reflected on rebuild;
cached and forced builds produce the same reader output. Renaming a referenced
slug requires updating its typed references; validation reports the old slug.

These are editorial suggestions, not citations or automatic similarity scores.
They do not add body links, backlinks, graph edges, or retrieval evidence. An
explicit wikilink in the body still participates in those existing features.
No embeddings or external service is involved. Standalone/root notes do not
currently have this collection-schema opt-in.
