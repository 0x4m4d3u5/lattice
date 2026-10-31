# Vault Workflows

Lattice includes vault-specific helpers for PARA-method note organization and other knowledge management workflows (e.g., Obsidian vaults).

Use [`lattice inventory`](publication-inventory.md) to inspect the configured
build's final files and draft/overwrite exclusions without publishing. It includes
static assets and does not interpret vault types as a publication filter. This is
not an automatic vault importer, migration tool or privacy audit.

## Local image attachments

Write `![[diagram.png]]` to embed an image already inside the configured static
asset directory (`content/static` by default). A bare filename must be unique.
For nested files or ambiguous names, use a static-relative path such as
`![[figures/diagram.png]]`, or qualify it with the configured directory name:
`![[static/figures/diagram.png]]`. Paths are case-sensitive; spaces and Unicode
are preserved and URL-encoded in published destinations. The target spelling
becomes escaped alt text. Normal Markdown images remain available when you need
custom alt text or other image syntax.

This supports PNG, JPEG, GIF, WebP, AVIF and BMP attachments on collection,
standalone, root and custom 404 pages. It does not implement note transclusion,
SVG/PDF/audio/video embeds, remote URLs, sizing (`|300`), fragments or parent-path
traversal. Unsupported, missing and ambiguous references fail `check` and
`build` with source locations, including when an old output file still exists.
Code examples, escaped syntax and raw HTML are not treated as embeds. Image
references do not create page backlinks or graph edges.

Resolution uses the existing static asset snapshot and confirms final output
ownership before publication. It does not discover or copy files from elsewhere
in a vault, fetch remote content, or change static publication policy. Static
assets are still copied wholesale, including unreferenced files; this feature is
not a privacy filter. Hidden draft references are excluded unless `--drafts` is
used. Image bytes are preserved, not decoded, sanitized or transformed by the
publisher; browser format support still applies.

The portable `render_note` API has no filesystem. Its supplied link map may
provide explicit destinations using keys such as
`{"![[diagram.png]]":"/static/diagram.png"}`. These must be local root-relative
URLs; absent destinations produce `image_embed` diagnostics. The host is
responsible for supplying genuinely published image assets. Ordinary page-map
keys and the function signature remain unchanged.

## Obsidian callouts

Quoted callouts publish without rewriting your notes:

```md
> [!warning] Check **the evidence**
> Read [[research|the source note]] before drawing conclusions.
>
> - Record limitations.
> - Keep supporting references.

> [!question]- How was this measured?
> This body starts collapsed; readers can expand it with mouse or keyboard.
```

The first quoted line declares the callout. Titles support inline Markdown and
wikilinks; bodies support ordinary blocks, including nested callouts, lists,
headings and code. Omit the title to use the type name. Identifiers are
case-insensitive ASCII letters, digits, hyphens or underscores; custom types
retain their names and use the same neutral reading style in the wiki starter.
This does not import Obsidian themes, icons or plugin-specific behavior.

A `+` or `-` immediately after `]` produces native HTML `details` and
`summary`, initially expanded or collapsed respectively, without JavaScript.
Without a sign the content stays visible. Ordinary quotes and fenced examples
remain unchanged. Callout links still participate in strict validation, and
headings use the document's shared ID numbering. Existing callout shortcodes
remain supported.

## Alternate note names

Enable `wikilink_aliases = true` in the site configuration, then use an `aliases`
array to link to a note by familiar names without changing its
filename or published URL:

```md
---
title: Research
aliases: ["Field Guide", "Research Handbook"]
---
## Evidence
```

Other notes can write `[[Field Guide]]` or
`[[Research Handbook#Evidence|the evidence]]`. Aliases use the same case, spacing
and `.md` normalization as ordinary wikilinks. They apply to collection, standalone
and root notes. Backlinks and graph edges retain the destination's canonical page
identity; aliases do not create extra pages, redirects or duplicate search entries.
With the content index enabled, the bundled [section search](section-search.md)
also finds alternate names and returns the canonical note.

Resolution is disabled by default so existing sites using aliases as ordinary
template metadata retain their behavior. When enabled, declare an array of
non-empty strings, even for a single name. Names containing
wiki delimiters (`#`, `|`, `[` or `]`) or line breaks are rejected. A normalized
name cannot belong to two notes or replace an existing page/collection lookup key.
Repeated spellings on the same note are harmless. Ambiguous or invalid declarations
fail both `check` and `build`, with the declaration's source location.

Aliases do not include drafts in publication. `check` and `build --strict-wikilinks`
validate their destinations and heading fragments against the final output plan;
ordinary build retains its existing broken-link warning policy. Renaming an alias
can break existing references, so run `check` after editing it. There is no automatic
source rewrite, URL redirect or alias-history migration.

## Vault metadata

Vault notes use additional frontmatter fields beyond standard blog posts:

```md
---
title: Research Project
type: Project
status: Active
purpose: Build comprehensive research archive
goal: Centralize all reference materials
source: Obsidian vault
created: 2024-01-15
tags: [research, para]
---
```

## Using vault helpers

The `@vault` module provides functions for working with vault-specific metadata:

### Extract vault metadata

Parse vault fields from frontmatter:

```moonbit
match @frontmatter.parse(source) {
  Ok(fm) => {
    match @vault.extract_vault_metadata(fm) {
      Some(meta) => {
        // meta.note_type, meta.status, meta.purpose,
        // meta.goal, meta.source, meta.created
        ()
      }
      None => ()
    }
  }
  Err(_) => ()
}
```

### Categorize notes

Normalize type field to canonical categories:

```moonbit
let category = @vault.categorize_note(meta)
// Returns: "project", "area", "resource", "archive", "inbox", "template", or "uncategorized"
```

### Check project status

Filter notes by project lifecycle:

```moonbit
if @vault.is_active_project(meta) {
  // Note is active (active, in-progress, doing, ongoinging)
}

if @vault.is_archived(meta) {
  // Note is completed (archived, completed, done, finished)
}
```

### Exclusion helper (not a publication boundary)

`should_exclude_from_index` is a library helper. The current builder does not call it; setting a vault type does not prevent publication. The snippets below demonstrate the helper, not an enforced CLI exclusion policy.

Filter notes that should not appear in public indexes:

```moonbit
if @vault.should_exclude_from_index(meta) {
  // Note is private, inbox, or WIP - skip from public indexes
}
```

### Render metadata badges

Display vault metadata as HTML badges:

```moonbit
let badge = @vault.render_metadata_badge(meta)
// Output: <span class="vault-badge vault-type-project">Project</span>
//          <span class="vault-badge vault-status-active">Active</span>
```

### Generate CSS classes

Create safe CSS class names from categories:

```moonbit
let class = @vault.category_class("My Custom Type")
// Output: "my-custom-type"
```

### Create display labels

Generate user-friendly labels for navigation:

```moonbit
let label = @vault.category_label("project")
// Output: "Projects"
```

## Collection configuration

Vault collections use extended schemas with vault fields:

```cfg
[projects]
schema = title:Optional[String], type:Optional[String], status:Optional[String], purpose:Optional[String], goal:Optional[String], source:Optional[String], created:Optional[String], description:Optional[String], tags:Optional[Array[String]]
dir = ~/notes/research/projects

[areas]
schema = title:Optional[String], type:Optional[String], status:Optional[String], purpose:Optional[String], goal:Optional[String], source:Optional[String], created:Optional[String], description:Optional[String], tags:Optional[Array[String]]
dir = ~/notes/research/areas

[resources]
schema = title:Optional[String], type:Optional[String], status:Optional[String], purpose:Optional[String], goal:Optional[String], source:Optional[String], created:Optional[String], description:Optional[String], tags:Optional[Array[String]]
dir = ~/notes/research/resources

[inbox]
schema = title:Optional[String], type:Optional[String], status:Optional[String], purpose:Optional[String], goal:Optional[String], source:Optional[String], created:Optional[String], description:Optional[String], tags:Optional[Array[String]]
dir = ~/notes/research/inbox
```

## Integration with templates

Use vault helpers in templates by importing `@vault` and calling functions:

```html
<!-- Render metadata badge -->
{{vault_badge}}

<!-- Render category-specific content -->
{{#if is_project}}
  <section class="project-details">
    <p>Purpose: {{vault.purpose}}</p>
    <p>Goal: {{vault.goal}}</p>
  </section>
{{/if}}

{{#if is_area}}
  <section class="area-details">
    <p>Area notes are organized here.</p>
  </section>
{{/if}}
```

## PARA method support

The vault module natively supports the PARA method (Projects, Areas, Resources, Archive):

- **Projects**: Active initiatives with goals and deadlines
- **Areas**: Ongoing responsibilities requiring maintenance
- **Resources**: Reference material, articles, templates
- **Archive**: Completed projects and inactive content

Type field values are normalized automatically:

- "Project"/"project"/"PROJECT" → `project`
- "Area"/"area of focus"/"Domain" → `area`
- "Resource"/"resources"/"reference" → `resource`
- "Archive"/"archived" → `archive`
- "Inbox"/"inbox item"/"capture" → `inbox`
- "Template"/"templates" → `template`

## Status field variants

Common status values are recognized:

**Active projects**:
- `active`, `in-progress`, `doing`, `ongoing`, `in progress`

**Archived projects**:
- `archived`, `completed`, `done`, `finished`

**Private/WIP notes**:
- `private`, `inbox`, `wip`, `work in progress` (recognized by the exclusion helper; not enforced by the builder)