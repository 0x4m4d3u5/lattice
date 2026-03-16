## Architectural Retrospective

### Frontmatter as Types, Not Strings

The core design decision in lattice is that `FrontmatterValue` is an enum (`FStr`, `FDate`, `FInt`, `FBool`, `FArray`, `FMap`), not a raw string map. When we parse frontmatter from a content file, we build a typed tree. Then `Schema.validate()` converts that tree into user-defined structs, and any mismatch — missing required fields, type incompatibility, unrecognized keys — is caught at the schema validation step, which runs **before** any HTML rendering begins.

This is the structural guarantee that differentiates lattice from dynamic SSGs. In Hugo or Astro, `page.title` might be undefined at template render time, and the error emerges as an empty string or a panic. Here, a missing required field is a `ValidationError` surfaced in the build diagnostic stream. The render pipeline never even runs — `process_document()` in `src/builder/builder.mbt` returns early at the schema validation step. The HTML renderer structurally cannot produce output from invalid input.

### Wikilink Resolution as a Build-Time Guarantee

Wikilinks (`[[target]]`) are resolved against the content graph in a two-pass build. Pass 1 collects all source files, computes slugs, and builds the complete page index (`slug → url`). Pass 2 renders each page. The key is that `wikilink.resolve()` returns `(Array[ResolvedWikilink], Array[ResolutionError])`. A link to a non-existent page is a `ResolutionError`, and we surface it as a build diagnostic (a warning in the default CLI, but programmatically a hard error).

The render step only receives a pre-validated `Map[String, String]` mapping target slugs to URLs. The `@markdown.render_with_diagnostics()` function substitutes `[[link]]` syntax with actual `href` attributes using this map. Because the map is complete and validated at the start of pass 2, the HTML renderer structurally cannot produce broken links. Contrast this with Hugo, which silently emits `<a href>` for wikilinks to non-existent pages, turning structural violations into 404s that users discover at runtime.

### The Date Validation Gap

The `FDate` type in the frontmatter enum represents our attempt at a structural guarantee: date fields should be ISO 8601 dates (`YYYY-MM-DD`). But we discovered a gap in the invariant enforcement. The parser initially used `is_iso8601_date`, which only checked format (digits and dashes in the right positions). The result: `2026-13-01` (month 13) was accepted as an `FDate` because the format matched, even though the value is semantically invalid.

The fix came in commit `abd260a` ("fix(frontmatter): validate date ranges in ISO 8601 date parsing"). We switched to `is_valid_iso8601_date`, which validates month 1-12 and day 1-31 (with month-specific day counts). Now invalid dates fall back to `FStr` instead of `FDate`, which fails type validation if the schema declares the field as `TDate`.

This is the honest version of "types catching bugs." The type system didn't catch the bug automatically — the `FDate` type was a promise we made to ourselves, and we initially failed to uphold it in the constructor. The pattern matching in `type_matches()` in `src/schema/schema.mbt` caught that the invariant was violated, but only after we manually closed the gap. The type system creates the pressure; we still have to do the work.

### Eliminating the Dual Rendering Pipeline

The markdown module initially had four rendering functions: `render_inline`, `render_inlines`, `render_block`, and `render_blocks`. These were near-complete duplicates of their `_with_issues` counterparts, with the only difference being that `_with_issues` functions also collected diagnostic information about syntax errors and unsupported features.

No external caller ever used the non-diagnostics versions. They were an artifact of incremental development: first we wrote the simple renderers, then added diagnostics, then never removed the old code. Commit `bc31fe5` ("refactor(markdown): eliminate dual rendering pipeline — engineering quality") collapsed the redundancy. `render_inline` and `render_block` became single-line delegators to their `_with_issues` variants. `render_inlines` and `render_blocks` were deleted entirely. 174 lines removed, all 135 tests passing.

This is what AI-assisted development looks like in practice. The agent spotted the redundancy mid-session and suggested the refactor. The commit message explicitly credits "Co-Authored-By: Claude Sonnet 4.6." We didn't catch the duplication on the first pass — it took a few days of working with the code before the smell became obvious. The retrospectives value is in documenting that the fix happened, not that we never made the mistake.

### Template Cycle Detection

Layout templates can `extend` parent templates via the `{{layout:filename}}` directive. Without cycle detection, `a extends b extends a` is an infinite loop during template resolution. The implementation in `src/template/template.mbt` tracks the extension chain with a visited set in `parse_template_with_includes`. When it encounters a filename already in the visited set, it returns `Err(CycleError("include cycle detected: " + filename))`.

The test suite covers this (`src/template/template_test.mbt:372`). Callers get a typed `TemplateError::CycleError`, not a stack overflow. This is a small detail, but it's the kind of structural property that prevents runtime surprises. A template cycle is a configuration error, not a logical error in the template rendering logic itself.

### AI Tool Usage

Lattice was built with Moon Pilot (Anthropic Claude 4.6 via the dere agency system) running in autonomous 6-hour cycles. The human developer set the rubric priority (functional completeness → engineering quality → explainability) and the core thesis ("structural violations are type errors, not runtime surprises"), then the agent implemented features and committed with detailed messages.

The workflow was: human provides high-level direction, agent implements and tests, human reviews and adjusts. Commit messages were written to be retrospective material — "refactor(markdown): eliminate dual rendering pipeline" rather than "fix render." The dual pipeline refactor is a good example: the agent spotted the issue in a later session than the original implementation, which is exactly the pattern you'd expect from iterative development.

Honest observation: the agent occasionally over-engineered first drafts. The template cycle detection and the frontmatter validation both went through iterations where we simplified the implementation after the initial version worked. This isn't a criticism of the agent — it's what code review is for. The retrospectives value is in documenting that we caught it and fixed it, not that we wrote perfect code on the first try.

### What Types Didn't Solve

The type system eliminates a class of structural errors: missing fields, type mismatches, broken links, configuration cycles. But it doesn't eliminate semantic errors. A post with `published: 2026-13-01` would now fail at schema validation (good). But `published: 2099-01-01` passes validation — the type is `FDate`, structurally valid, but semantically a future-dated post that might be accidentally published if you forget to check date ranges.

Similarly, a wikilink to a page that exists but has been deleted and recreated at a different URL passes resolution, but the backlink index is stale until the next rebuild. The type system catches structural violations, not logical ones in the content workflow.

This isn't a limitation of the type system — it's a reminder that types are a tool, not a panacea. Lattice makes structural integrity a compile-time property. Semantic integrity (valid content, up-to-date backlinks, sensible publication dates) is still a human concern. The thesis holds: we've shifted the boundary between what the compiler catches and what humans catch, but we haven't eliminated the human side entirely.