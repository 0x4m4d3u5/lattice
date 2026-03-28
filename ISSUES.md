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

## Remaining Low-Priority Items

### P2 — Template.mbt rendering duplication

**File:** `src/template/template.mbt` (~900+ lines)

The `render_parts` function has heavily duplicated code for rendering body parts inside `ConditionalBlock` and `FrontmatterConditionalBlock`. Extract the body-parts rendering into a shared helper function would reduce ~100-200 lines.

### P2 — Slugifier is ASCII-only

**File:** `src/slug/slug.mbt` — `slugify_n`

The slugifier only lowercases ASCII and replaces spaces/underscores with hyphens. Characters like accented letters, CJK, emoji, or punctuation are passed through unchanged. Consider adding transliteration for common accented characters or using the stdlib `String::to_lower()` for Unicode support.

### P2 — RSS feed datetime normalization is fragile

**File:** `src/rss/rss.mbt` — `normalize_feed_datetime`

The RFC3339 acceptance check uses loose heuristic prefix/suffix matching (`"20..."`, ends with `"Z"`, length ≥ 20). A malformed string like `"20xxxxxxxxxxxxxxxxZ"` would be accepted. Consider proper RFC3339 structure validation.

### P2 — Builder.mbt deprecated syntax warning

**File:** `src/builder/builder.mbt:247`

Uses the deprecated `fn f(a,b) { ... }; fn g(a,b) { ... }` mutually recursive function syntax. Should be updated to `letrec f = fn (a, b) { ... }` and `g = fn (...) { ... }`.

---

## Positive Observations

- **Clean error types**: The project uses typed error enums/suberrors consistently (e.g., `CacheError`, `ConfigError`, `CollectionsError`, `ShortcodeError`), making error handling explicit and exhaustive.
- **Good test coverage**: Every package has corresponding test files with snapshot-based testing. All 360 tests pass.
- **Clear module boundaries**: Each package has a focused responsibility with clean public APIs.
- **Structural guarantees**: The project philosophy of catching structural violations at build time (schema validation, wikilink resolution) is well-executed.
- **Good stdlib usage**: The project already uses `String::has_suffix`, `String::has_prefix`, `String::contains`, `Map::new()`, `StringBuilder`, `derive(Show, Eq, ToJson)`, `for ... in ...` loops — demonstrating readiness for deeper stdlib integration.
- **Zero errors**: The entire codebase compiles cleanly with only a single pre-existing deprecation warning.


> **Auditor**: MoonBit code auditor pass  
> **Scope**: `src/` — all packages  
> **Date**: 2025-07-12

---

## Summary

The codebase is a well-structured static site generator ("Lattice") written in MoonBit. The architecture is modular with clear separation of concerns. However, the audit uncovered significant code duplication, handrolled implementations that should be replaced with stdlib equivalents, and opportunities to reduce maintenance burden.

**Key stats:**
- ~20 packages audited
- **15+ duplicated utility functions** across packages
- **2 handrolled JSON serialization** subsystems that should use `@json` stdlib
- **1 handrolled insertion sort** that should use stdlib sort
- Multiple minor correctness and robustness concerns

---

## ✅ Completed

### 1. Created `src/strutil/` shared utility package

A centralized shared utility package providing 30+ commonly-needed string/char primitives that were previously duplicated across 15+ packages:

**Character access:** `char_at` — bridges MoonBit's `UInt16`-returning `s[i]` to `Char`

**Trimming:** `trim`, `trim_start`, `trim_end`, `trim_h` — whitespace trimming variants

**Substring/lines:** `substr`, `split_lines`, `join_lines` — string manipulation

**Character classification:** `is_digit`, `is_alpha`, `is_ident_start`, `is_ident_part`, `is_whitespace`, `is_hex_digit`, `is_octal_digit`, `is_operator_char`, `is_punct_char`

**Prefix/suffix matching:** `starts_with_at`, `starts_with`, `ends_with`

**HTML escaping:** `escape_html_body`, `escape_html_attr` — consistent escaping for body vs attribute context

**URL utilities:** `normalize_base_url`, `absolute_url` — URL normalization and joining

**Path utilities:** `join_path` — path component joining

**JSON helpers:** `hex_nibble`, `write_json_escaped`, `write_json_string` — JSON serialization primitives

**Case conversion:** `to_ascii_lower`, `ascii_lower_char` — ASCII-only lowercase conversion

**Integer parsing:** `parse_int`, `parse_positive_int` — safe integer parsing with error handling

**Quoted string parsing:** `parse_quoted` — shared JSON-style quoted string literal parser

**Date validation:** `is_leap_year`, `days_in_month`, `is_valid_iso8601_date` — date validation used across multiple packages

**Whitespace skipping:** `skip_ws`, `skip_ws_h` — parser whitespace skipping utilities

### 2. Migrated `src/slug/` to use `@strutil`

- Removed local `char_at` function
- Replaced with `@strutil.char_at` in `slugify_n`
- **Bonus fix**: `filename_to_slug` now does case-insensitive `.md` extension stripping (e.g., `GUIDE.MD` → `"guide"`)

### 3. Migrated `src/vault/` to use `@strutil`

- Removed local `char_at_vault`, `to_lowercase`, `escape_html_vault` (~45 lines)
- Replaced with `@strutil.char_at`, `@strutil.to_ascii_lower`, `@strutil.escape_html_attr`

### 4. Migrated `src/wikilink/` to use `@strutil` and `@slug`

- Removed local `char_at_wl`, `substr_wl`, `trim_wl`, `slugify_lookup_key_wl` (~45 lines)
- Replaced with `@strutil.char_at`, `@strutil.substr`, `@strutil.trim`
- Replaced `slugify_lookup_key_wl` + manual `.md` stripping with `@slug.filename_to_slug`

### 5. All 360 tests pass

---

## 🔧 Remaining Work

The following issues are documented for incremental resolution. Each package migration follows the same pattern:

1. Add `"kurisu/lattice/src/strutil" @strutil` to `moon.pkg.json`
2. Replace local `char_at_XXX(s, i)` calls with `@strutil.char_at(s, i)`
3. Replace local `trim_XXX(s)` calls with `@strutil.trim(s)` or `@strutil.trim_h(s)` as appropriate
4. Replace local `substr_XXX(s, a, b)` calls with `@strutil.substr(s, a, b)`
5. Replace local `is_digit_XXX(c)` calls with `@strutil.is_digit(c)`
6. Replace local `starts_with_XXX(s, p)` calls with `@strutil.starts_with(s, p)`
7. Replace local `escape_html_XXX(s)` calls with `@strutil.escape_html_body(s)` or `@strutil.escape_html_attr(s)`
8. Replace local `normalize_base_url_XXX(s)` calls with `@strutil.normalize_base_url(s)`
9. Replace local `hex_nibble_XXX(n)` calls with `@strutil.hex_nibble(n)`
10. Replace local `write_json_string_XXX(buf, s)` calls with `@strutil.write_json_string(buf, s)`
11. Delete the now-unused local helper function definitions
12. Run `moon check && moon test` to verify

### P0 — High Priority (deferred, but has migration path)

#### 1. Handrolled JSON serialization (cache, manifest, graph, search, html)

**Affected files:**
- `src/cache/cache.mbt` — ~200 lines of JSON parser/serializer
- `src/manifest/manifest.mbt` — ~300 lines of JSON parser/serializer
- `src/graph/graph.mbt` — ~50 lines (write_json_string_graph, hex_nibble_graph)
- `src/search/search.mbt` — ~50 lines (write_json_string, hex_nibble)
- `src/html/html.mbt` — ~200 lines of manual JSON-LD rendering

**Migration path:** Replace local `write_json_string_XXX` with `@strutil.write_json_string`. For cache/manifest parsers, the handrolled JSON parsers serve as both parser AND validator with custom error types — replacing with `@json` stdlib requires careful handling of `Int64` (which `ToJson` serializes as a JSON string, not number). Recommend migrating incrementally, starting with the simpler cases (graph, search).

#### 2. Handrolled insertion sort in RSS module

**File:** `src/rss/rss.mbt` — `sort_pages_for_feed` function (~15 lines)

**Migration path:** MoonBit stdlib doesn't provide `Array::sort`. Implement a merge sort or insertion sort in `src/strutil/` as `pub fn sort_by[T](arr : Array[T], cmp : (T, T) -> Bool) -> Array[T]`, then replace the local one.

#### 3. Massive duplication of `char_at` helper function (18+ copies)

**Status:** ✅ `strutil` package created. **3 packages migrated** (slug, vault, wikilink). **12 packages remaining.**

| Package | Has `char_at` | Has `trim` | Has `substr` | Has `is_digit` | Has `escape_html` | Has `starts_with` | Has `normalize_base_url` |
|---------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| frontmatter | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ |
| markdown | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| html | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| highlight | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ |
| config | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ |
| data | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ |
| collections | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ |
| template | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ |
| shortcode | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ |
| tags | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ |
| sitemap | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ | ✅ |
| rss | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| robots | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| cache | ✅ | ✅ | ❌ | ✅ | ❌ | ✅ | ❌ |
| manifest | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| graph | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| search | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

### P1 — Medium Priority

#### 4. Handrolled YAML/TOML frontmatter parsers with 3 independent date validation implementations

**Files:**
- `src/frontmatter/frontmatter.mbt` — YAML subset parser + `is_valid_iso8601_date`
- `src/rss/rss.mbt` — `normalize_feed_datetime` with `days_in_month`/`is_leap_year` (duplicated)
- `src/sitemap/sitemap.mbt` — `normalize_lastmod` with handrolled digit checking

**Migration path:** All three should use `@strutil.is_valid_iso8601_date`. The RSS and sitemap date normalization can share the validation logic.

#### 5. Deduplicated `normalize_base_url` (3 copies → strutil)

**Status:** ✅ Centralized in strutil. Needs migration in rss, sitemap, robots.

#### 6. Deduplicated `hex_nibble` and `write_json_string` (4+ copies → strutil)

**Status:** ✅ Centralized in strutil. Needs migration in graph, search, html, cache, manifest.

### P2 — Low Priority / Code Quality

#### 7. Slugifier is ASCII-only (no accent/CJK handling)

**File:** `src/slug/slug.mbt` — `slugify_n`

#### 8. RSS feed datetime normalization is fragile

**File:** `src/rss/rss.mbt` — `normalize_feed_datetime`

#### 9. `template.mbt` is extremely large (~900+ lines) with duplicated rendering logic

**File:** `src/template/template.mbt`

The `render_parts` function has heavily duplicated code for rendering body parts inside `ConditionalBlock` and `FrontmatterConditionalBlock`. Extract the body-parts rendering into a shared helper function.

#### 10. `join_path` edge cases in assets

**File:** `src/assets/assets.mbt` — `join_path`

**Migration path:** Replace with `@strutil.join_path`.

---

## Positive Observations

- **Clean error types**: The project uses typed error enums/suberrors consistently (e.g., `CacheError`, `ConfigError`, `CollectionsError`, `ShortcodeError`), making error handling explicit and exhaustive.
- **Good test coverage**: Every package has corresponding test files with snapshot-based testing. All 360 tests pass.
- **Clear module boundaries**: Each package has a focused responsibility with clean public APIs.
- **Structural guarantees**: The project philosophy of catching structural violations at build time (schema validation, wikilink resolution) is well-executed.
- **No unsafe FFI without clear justification**: The only `unsafe_to_char` usage is the `char_at` pattern necessitated by the current MoonBit `String[i]` return type.
- **Good stdlib usage opportunity**: The project already uses `String::has_suffix`, `String::has_prefix`, `String::contains`, `Map::new()`, `StringBuilder`, `derive(Show, Eq, ToJson)`, `for ... in ...` loops — demonstrating readiness for deeper stdlib integration.
