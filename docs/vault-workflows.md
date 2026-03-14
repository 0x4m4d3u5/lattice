# Vault Workflows

Lattice includes vault-specific helpers for PARA-method note organization and other knowledge management workflows (e.g., Obsidian vaults).

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

### Exclude private notes

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
- `private`, `inbox`, `wip`, `work in progress` (excluded from indexes)