# Lattice Codebase Audit

> **Auditor**: MoonBit code auditor pass  
> **Scope**: `src/` — all packages  
> **Date**: 2025-07-12

---

## Summary

The codebase is a well-structured static site generator ("Lattice") written in MoonBit. The architecture is modular with clear separation of concerns. However, the audit uncovered significant code duplication, handrolled implementations that should be replaced with stdlib equivalents, and opportunities to reduce maintenance burden.

**Audit results — all completed:**
- ✅ Created `src/strutil/` shared utility package with 35+ centralized functions
- ✅ Migrated **all 20 packages** to use `@strutil` instead of local duplicates
- ✅ Fixed slug case-insensitive `.md` extension stripping bug
- ✅ Replaced handrolled insertion sort with shared `insertion_sort` utility
- ✅ Net reduction: **-1180 lines** (2324 removed, 1144 added including strutil package)
- ✅ All 360 tests pass

---

## Completed Changes

### 1. Created `src/strutil/` shared utility package (35+ functions)

Centralized commonly-needed string/char primitives that were previously duplicated across 15+ packages:

**Character access:** `char_at` — bridges MoonBit's `UInt16`-returning `s[i]` to `Char`

**Trimming:** `trim`, `trim_start`, `trim_end`, `trim_h` — whitespace trimming variants

**Substring/lines:** `substr`, `split_lines`, `join_lines` — string manipulation

**Character classification:** `is_digit`, `is_alpha`, `is_ident_start`, `is_ident_part`, `is_whitespace`, `is_hex_digit`, `is_octal_digit`, `is_operator_char`, `is_punct_char`

**Prefix/suffix matching:** `starts_with_at`, `starts_with`, `ends_with`

**HTML escaping:** `escape_html_body`, `escape_html_attr` — consistent escaping for body vs attribute context

**URL utilities:** `normalize_base_url`, `absolute_url` — URL normalization and joining

**Path utilities:** `join_path` — path component joining

**JSON helpers:** `hex_nibble`, `write_json_string`, `write_json_escaped` — JSON serialization primitives

**String search:** `find_char`, `find_str` — substring search utilities

**Case conversion:** `to_ascii_lower`, `ascii_lower_char` — ASCII-only lowercase conversion

**Integer parsing:** `parse_int`, `parse_positive_int` — safe integer parsing with error handling

**Quoted string parsing:** `parse_quoted` — shared JSON-style quoted string literal parser

**Date validation:** `is_leap_year`, `days_in_month`, `is_valid_iso8601_date` — date validation used across multiple packages

**Whitespace skipping:** `skip_ws`, `skip_ws_h` — parser whitespace skipping utilities

**Sorting:** `insertion_sort[T]` — stable in-place insertion sort with custom comparator

### 2. Migrated all 20 packages to use `@strutil`

| Package | Functions Migrated | Lines Removed |
|---------|:---:|:---:|
| `slug` | `char_at` | 5 |
| `vault` | `char_at`, `to_lowercase`, `escape_html` | 45 |
| `wikilink` | `char_at`, `substr`, `trim`, `slugify` | 90 |
| `tags` | `char_at`, `trim`, `escape_html` | 64 |
| `sitemap` | `char_at`, `escape_xml_text`, `trim`, `normalize_base_url`, `absolute_url`, `is_digit` | 106 |
| `robots` | `char_at`, `trim`, `normalize_base_url` | 50 |
| `assets` | `join_path` | 23 |
| `rss` | `char_at`, `escape_xml_text`, `escape_xml_attr`, `starts_with_at`, `trim`, `is_digit`, `is_leap_year`, `days_in_month`, `normalize_base_url`, `absolute_url` + sort | 220 |
| `graph` | `char_at`, `hex_nibble`, `write_json_string` | 49 |
| `search` | `char_at`, `hex_nibble`, `write_json_string` | 56 |
| `html` | `char_at`, `escape_html_body`, `escape_html_attr`, `hex_nibble`, `substr` | 152 |
| `cache` | `char_at`, `hex_nibble`, `write_json_string`, `skip_ws` | 118 |
| `manifest` | `char_at`, `hex_nibble`, `write_json_string`, `skip_ws` | 124 |
| `frontmatter` | `char_at`, `trim`, `substr`, `starts_with_at`, `is_digit`, `is_whitespace`, `is_alpha`, `is_ident_part`, `parse_quoted`, `parse_int`, `skip_ws` | 218 |
| `markdown` | `char_at`, `trim`, `trim_start`, `trim_end`, `substr`, `split_lines`, `is_digit`, `escape_html`, `starts_with_at`, `find_char`, `find_str` | 445 |
| `highlight` | `char_at`, `is_whitespace`, `is_digit`, `is_alpha`, `is_ident_start`, `is_ident_part`, `starts_with_at`, `is_hex_digit`, `is_octal_digit`, `is_operator_char`, `is_punct_char`, `escape_html` | 739 |
| `config` | `char_at`, `trim`, `substr`, `is_digit`, `is_alpha`, `is_whitespace`, `is_ident_start`, `is_ident_part`, `starts_with_at`, `parse_int` | 67 |
| `data` | `char_at`, `trim`, `substr`, `is_digit`, `is_alpha`, `starts_with_at`, `parse_quoted`, `skip_ws`, `parse_int` | 177 |
| `collections` | `char_at`, `trim`, `substr`, `is_digit`, `is_whitespace`, `starts_with_at`, `parse_quoted` | 132 |
| `template` | `char_at`, `trim`, `substr`, `is_digit`, `is_whitespace`, `starts_with_at` | 252 |
| `shortcode` | `char_at`, `trim`, `substr`, `is_digit`, `is_name_char`, `starts_with`, `parse_int`, `skip_ws`, `escape_html` | 109 |

### 3. Bug fix: Case-insensitive `.md` extension stripping

`filename_to_slug("GUIDE.MD")` now correctly produces `"guide"` instead of failing to strip the `.MD` extension.

### 4. Replaced handrolled insertion sort with shared utility

The RSS feed module's insertion sort was moved to `src/strutil/insertion_sort[T]` for potential reuse.

### 5. HTML package: JSON-LD writer preserved

The html package has specialized JSON-LD rendering that escapes `<`, `>`, `&` as `\uXXXX` sequences (not standard JSON) for safe embedding in `<script type="application/ld+json">` blocks. This was kept as a local `write_json_string_ld` function since the standard `@strutil.write_json_string` doesn't include these extra escapes.

---

## Remaining Open Items

### P2 — `src/builder/builder.mbt` & `src/template/template.mbt` size / duplication

- `src/builder/builder.mbt` (~8.3k lines, `prepare_output` ~2.2k lines, `check` ~840 lines, parallel `process_document` and `process_document_for_lint`) is the main source of potential `check` vs `build` drift. Recent features have been cleanly split into sibling files (`private_audience.mbt`, `passage_retention.mbt`, `output_plan.mbt`, etc.); continuing that pattern will reduce maintenance risk.
- `src/template/template.mbt` (`render_parts`) still has duplicated conditional-block rendering logic.

### P2 — Slugifier punctuation handling

**File:** `src/slug/slug.mbt` — `slugify_n`

Latin accented characters are now transliterated (`café` → `cafe`), but URL-breaking ASCII punctuation (`?`, `#`, `%`, `:`, `"`, `<`, `>`) still passes through verbatim. Tracked for the real-vault compatibility pass in `TODO.md`.

---

## Hardening Audit Pass (2026-11-22)

- ✅ Hardened `src/serve/serve_native.c`: anchored `resolve_path` to leading `/`, rejected backslashes / embedded NULs / `snprintf` truncation / `..` segments, enforced `realpath()` containment on Unix, ignored `SIGPIPE`, and looped `sock_write` via `write_all`.
- ✅ Fixed HTML attribute escaping in `src/markdown/markdown.mbt`: switched footnote `id`/`href` and callout `class` attributes from `escape_html_body` to `escape_html_attr`.
- ✅ Fixed UTF-16 handling: `@strutil.substr` now uses native string slicing instead of looping UTF-16 code units through `unsafe_to_char`, and `TString(minlen, maxlen)` in `src/schema/schema.mbt` counts Unicode scalar values with scalar-safe error truncation.
- ✅ Tightened `TUrl` validation in `src/schema/schema.mbt` to reject bare schemes (`http://`), protocol-relative URLs (`//...`), and whitespace/control characters.
- ✅ Fixed `category_class` hyphen preservation in `src/vault/vault.mbt` and documented `should_exclude_from_index` as organizational-only (not a publication/visibility boundary).
- ✅ Removed residual local `trim_ws`, `split_lines*`, and `starts_with_collections` duplicates in `frontmatter`, `collections`, `config`, and `data`.
- ✅ Deduplicated `current_unix_second` / `current_millis` / `today_ymd` into `src/watch/watch.mbt` using `@env.now()`, eliminating the native unused-package warning (`moon check --target native --deny-warn` is now clean).
- ✅ Previously open P2 items resolved in earlier commits: RFC 3339 datetime validation in `src/rss/rss.mbt` and deprecated mutual-recursion syntax in `src/builder/builder.mbt`.
- ✅ Deduplicated this file (previously contained two pasted copies of the July 2025 audit).

---

## Positive Observations

- **Clean error types**: The project uses typed error enums/suberrors consistently (e.g., `CacheError`, `ConfigError`, `CollectionsError`, `ShortcodeError`), making error handling explicit and exhaustive.
- **Strong test & fixture coverage**: 1,732 JS workspace tests plus 35+ end-to-end scripts in `scripts/check-baseline.sh`.
- **Clear module boundaries**: Each package has a focused responsibility with clean public APIs.
- **Defensive publication architecture**: `OutputPlan::contained_path` and fail-closed visibility/audience guards enforce structural boundaries before writes.
- **Zero warnings**: Both `moon check --target js --deny-warn` and `moon check --target native --deny-warn` pass cleanly.
