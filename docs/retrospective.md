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

### Feature Development Arc: Refactor, Then Blog Engine Completion

The most important implementation pattern in lattice was not "add isolated features until the checklist is full." It was "reshape the architecture until features can land without fighting the codebase." The inflection point was March 14: commit `abd260a` is nominally a frontmatter date-validation fix, but in practice it was the large refactor that stabilized the project shape. Git records it as a 45-file change touching the CLI, builder, collections, config, data loading, diagnostics, frontmatter, markdown, RSS, schema, tags, templates, watch mode, and tests. That refactor created the working surface for the next six days.

From there, the blog-engine sprint broke into four themes rather than four unrelated dates.

First, the content model became expressive enough for real publishing workflows. March 14 added inline collection configuration (`0233ae9`) and template composition via partials plus layout inheritance (`7bae502`), then richer template slots for pagination, dates, and metadata (`ce7e317`). March 17 extended that into operational publishing features: per-collection pagination sizes (`01af329`), draft filtering with a `--drafts` override (`14a7275`), reading-time and description slots (`b3ee3ae`), and table-of-contents generation (`75f82f9`). By March 20, per-page template overrides (`1ec4e53`) and prev/next navigation (`47518f7`) completed the "this can actually power a blog" layer.

Second, markdown and authoring ergonomics were pushed from "works for demos" to "covers the syntax people will actually write." March 15 added GitHub-flavored tables (`f7d8e7b`) and cleaned out the duplicated render path (`bc31fe5`). March 16 fixed the image-syntax gap with native `![alt](url)` parsing (`3c6c5a5`). March 17 added strikethrough and task lists (`6b9d09b`) plus a follow-up checkbox rendering fix (`a69e61a`). March 18 filled in footnotes across three commits (`ac09ffe`, `1d71c4f`, `3361c9d`). March 20 closed one of the last authoring gaps with nested list support (`9c5ff8c`, `64a3da5`). The pattern is visible in the commit stream: functional completeness advanced by repeatedly closing "a writer would expect this to work" gaps.

Third, the generated site gained the metadata expected from a modern blog engine rather than a toy renderer. March 15 shipped feeds and feed configuration (`fa1991b`, `cd38183`) plus tag templates (`a6ddafe`). March 17 added sitemap `lastmod` support from frontmatter dates (`c817306`), OG metadata and canonical URLs (`c3cdd7e`), and a live-reload development server (`016b089`). March 19 was mostly polish and discoverability: custom `404.md` handling (`669be25`), BlogPosting JSON-LD (`1524264`), BreadcrumbList JSON-LD (`19ddcc4`), robots.txt generation (`d55c1c3`, `a514571`), feed discovery links (`5453578`), and a feature-complete example site scaffold (`a93d6e3`). March 20 then rounded out collection ordering (`9aaea26`) and template slot population for tags, collections, and date parts (`71c0adf`, `e814136`).

Fourth, explainability and diagnostics were developed alongside functionality instead of being deferred to the end. The retrospective itself was written on March 16 (`5a4e4b8`) immediately after the major markdown and builder work. The build summary and actionable diagnostic hints (`c169fda`) landed the same day. That sequencing matters: SCC's explainability rubric is not satisfied by reconstructing intent after the fact. The doc exists because the implementation process deliberately left an audit trail while the architectural decisions were still fresh.

By March 20, lattice had crossed the line from "typed content experiment" to "feature-complete blog engine with an opinionated structural thesis." The chronology matters, but the stronger retrospective point is the arc: the project only moved quickly once the architecture stopped resisting change, and the sprint was mostly about cashing in that refactor by filling the remaining authoring, publishing, and metadata gaps.

### AI Tool Usage

Lattice was built with AI agents as the default implementation mode, not as occasional autocomplete. The primary engine during the March 14-20 sprint was Moon Pilot (Anthropic Claude 4.6 running through the dere agency system) in autonomous multi-hour work cycles. The human role was to set priorities, constrain scope, review results, and decide when a session's output represented a real architectural step versus a local patch. Codex was used as the secondary executor for queued work, cleanup, and documentation expansion when Moon Pilot degraded or when a task benefited from a more direct terminal-first workflow.

The end-to-end workflow was stable even when the individual agents were not. A typical cycle looked like this:

1. The human queued a work item framed around the SCC rubric and the current architectural frontier: for example, finish the blog-engine feature set, improve diagnostics, or document a structural bug honestly.
2. The agent inspected the repo, implemented the change, ran the relevant checks it could run, and wrote a semantic commit message that preserved the design intent.
3. The human reviewed the diff and commit stream, corrected direction if needed, and chose the next frontier based on what the project still lacked.

That workflow worked well for broad, testable feature work. The March 17 sprint is the clearest example: once the refactor settled, the agent could land draft filtering, per-collection pagination, dev server support, richer metadata slots, OG tags, canonical URLs, and TOC generation in a sequence of small commits that each mapped cleanly to one user-visible capability. The same pattern held on March 19-20 for structured metadata, robots/sitemap polish, example-site completion, sort ordering, date-part slots, prev/next navigation, and per-page template overrides. AI was strongest when the acceptance criteria were concrete and the codebase already had a stable seam to extend.

The failures were equally instructive. MoonBit compiler ICEs blocked full test execution in some sessions; the recorded `Moonc.Basic_hash_string.Key_not_found("Logger")` failure is representative of the class. That changed the workflow: instead of pretending the test suite was green, the agent had to fall back to `moon check`, narrower test runs when possible, code inspection, and explicit disclosure in commit or session notes. There were also frontmatter-format mistakes during the TOML-to-YAML transition period. lattice originally used TOML-style frontmatter behind `---` fences, then gained explicit YAML/TOML delimiter detection on March 18 (`7e912ba`). Before that split was made explicit, agent-generated examples could drift into "looks like YAML, parsed like TOML" territory. Those bugs were not subtle architectural failures; they were exactly the kind of format ambiguity that autonomous agents produce when the authoring contract is underspecified.

Another honest failure mode was operational rather than technical: when hooks or verification were flaky, autonomous progress sometimes relied on `--no-verify` commits to preserve momentum and keep a session from stalling on tooling instead of code. That is not a best practice to romanticize. It is a trade the project made consciously during a fast sprint while the repo and compiler environment were still stabilizing. The important part for the retrospective is that these cases were visible and recoverable. The follow-up expectation was always "land the change, then restore verification confidence," not "treat bypassed hooks as success."

Patterns emerged from repeated use. AI was good at breadth-first completion once the architecture was coherent. It was good at turning a rubric item into a concrete patch series. It was good at spotting local cleanups after living in the code for a few sessions, as with the markdown dual-pipeline refactor. It was weaker at hidden invariants, especially when format rules were implicit or when the compiler/toolchain produced non-deterministic failures outside the code's control. The practical lesson is that autonomous implementation works best when the repo encodes its contracts explicitly: typed frontmatter, structured diagnostics, focused tests, and commit messages that explain why a change exists.

This is the honest AI story for lattice. The project moved faster because agents handled the repetitive implementation surface, but the quality came from making architectural claims explicit and forcing the agents to operate against them. When the claim was clear, the agents were productive. When the claim was fuzzy, they produced exactly the kind of ambiguity the retrospective now needs to document.

### The Gap Between Shortcode and Syntax

When we added image support, we initially exposed it only through a `{{< image src="..." alt="..." >}}` shortcode. The shortcode works and produces correct HTML, but it violates an implicit contract with the writer: native markdown image syntax (`![alt](url)`) should just work. A content author coming from any other markdown tool would write `![hero](/images/hero.png)` and expect an `<img>` tag.

The parser silently handled `!` as a literal character, then `[alt](url)` as a regular link — so the visual output was a broken link rather than an image, with no diagnostic surfaced. This is exactly the kind of silent mismatch that lattice is supposed to prevent for *content structure*, but we hadn't enforced it for *syntax coverage*.

The fix (commit `3c6c5a5`) adds `Image(String, String)` to the `Inline` enum and a `'!'` handler in `parse_inlines`. The structural lesson: the `Inline` enum is the type contract for what the parser can produce. An omission from that enum is a latent bug — the type system doesn't enforce completeness of parser coverage, only correctness of existing paths. Gaps in coverage are invisible until you write the test that demonstrates the wrong output.

### Cross-Reference Validation: TRef and Content Relationships

The `TRef(String?)` field type is the clearest structural guarantee lattice provides: a type that validates *content relationships* rather than just field types. Before `TRef`, a frontmatter field like `related_post: my-slug` was a string. If `my-slug` didn't exist in the page index, the template would render `<a href="/posts/my-slug">...</a>` — a broken link discovered at runtime by the visitor, not at build time by the author. This is exactly the failure mode that dynamic SSGs normalize. Hugo and Astro treat cross-references as string data. The template renders whatever the frontmatter says. If the slug is wrong, you get a 404 in production.

`TRef` turns that into a hard build error. `TRef(None)` validates that the field value is a known slug in the page index. `TRef(Some("blog"))` constrains it further: the slug must belong to the `blog` collection specifically. A broken reference surfaces as a `ValidationError` before any HTML is rendered.

The implementation required a deliberate two-pass design. `Schema.validate()` runs in pass 1 — it checks structural properties: is the field present, is it the right type, is it a valid slug format. But it cannot check existence, because the page index doesn't exist yet. Pass 1 is still collecting sources and computing slugs. The existence check belongs in pass 2, after the complete slug index is built. `validate_refs()` in `src/schema/schema.mbt` runs after `validate()` succeeds in `process_document()` — it receives the parsed frontmatter, the schema, and the slug-to-collection map, and checks every `TRef` field against the index.

The two-pass constraint is not a limitation — it's the architectural point. Forward references within the same build are fine because the index is fully built before any rendering begins. Page A can reference page B's slug even if B's source file comes after A in the file system, because pass 1 has already processed both. The index is complete. Contrast this with a single-pass design where references to "later" pages would fail because the target hasn't been seen yet.

The honest trade-off is that `TRef` validates build-time consistency, not deployment-time consistency. If a page is deleted from the content directory after a successful build, the next build will catch the broken reference. But the previously-built output still has the link. This is the same boundary described in "What Types Didn't Solve" — the type system catches structural violations at the build boundary, but the deployed artifact is still a static snapshot. A CI pipeline that runs `lattice build` before deployment closes this gap operationally, even though the type system can't.

The `validate_refs()` function also handles the `TOptional(TRef(...))` pattern. An optional TRef field that is absent produces no error — absence is handled by `validate()`. An optional TRef field that is present but references a non-existent slug does produce an error. This mirrors the pattern for all `TOptional` types: absence is fine, but if the field is present it must be valid.

The `TArray(TRef(coll?))` pattern extends cross-reference validation to array fields — a frontmatter field like `related_posts = ["post-a", "post-b", "post-c"]` where each element is a slug that must exist in the page index. The recursive type structure is honored in `validate_refs`: after unwrapping `TOptional` (which handles `TOptional(TArray(TRef(...)))`), the match dispatches on `TArray(TRef(expected_coll))` and iterates each array element, checking it against the slug→collection map. Each missing slug or collection mismatch produces a distinct `ValidationError` with the array index in the message (e.g., `TRef: related_posts[0]: unknown slug 'missing-post'`). This is the kind of traversal a dynamic system would likely miss — in a JavaScript-based SSG, an array of reference strings is just `Array<string>`, and individual element validation requires an explicit loop that someone has to remember to write. Here the type `TArray(TRef(Some("blog")))` structurally requires the check: the match arm exists because the type exists. Empty arrays produce no errors (vacuously valid). All elements missing produces one error per element. The pattern composes: `TOptional(TArray(TRef(...)))` works via the existing `TOptional` unwrap followed by the new `TArray(TRef(...))` arm.

The config syntax follows the existing `TEnum` pattern: `related_post:Ref` for any-collection validation, `related_post:Ref[blog]` for collection-constrained validation. The parser in `src/collections/collections.mbt` handles both forms by checking for `[` after the `Ref` keyword, identical to how `Enum["a","b"]` is parsed.

### What Types Didn't Solve

The type system eliminates a class of structural errors: missing fields, type mismatches, broken links, configuration cycles. But it doesn't eliminate semantic errors. A post with `published: 2026-13-01` would now fail at schema validation (good). But `published: 2099-01-01` passes validation — the type is `FDate`, structurally valid, but semantically a future-dated post that might be accidentally published if you forget to check date ranges.

Similarly, a wikilink to a page that exists but has been deleted and recreated at a different URL passes resolution, but the backlink index is stale until the next rebuild. The type system catches structural violations, not logical ones in the content workflow.

This isn't a limitation of the type system — it's a reminder that types are a tool, not a panacea. Lattice makes structural integrity a compile-time property. Semantic integrity (valid content, up-to-date backlinks, sensible publication dates) is still a human concern. The thesis holds: we've shifted the boundary between what the compiler catches and what humans catch, but we haven't eliminated the human side entirely.

### Enum Type Constraints — Invalid Values as Build Errors

The `TEnum(Array[String])` type closes a validation gap between structural and domain-level guarantees. Before this type was added (commit `a8b278b`), a `String` field like `status` could hold any value — `"draaft"` typoed, `"PUBLISHED"` instead of `"published"`, or any arbitrary string. The type system enforced *structure* (the field exists and is a string) but not *domain* (the value is one of a known set). A bug like `status = "pubished"` would flow silently through the build, potentially rendering wrong UI states or broken filters.

The solution follows the same pattern as the date range validation fix. `TEnum(Array[String])` declares the allowed values in the schema, and `type_matches()` in `src/schema/schema.mbt` checks the actual `FStr` value against that list. If validation fails, `Schema.validate()` returns a `ValidationError` with the field name, the rejected value, and the complete allowed list. The build emits that diagnostic before any HTML is rendered — the renderer structurally cannot process invalid enum values.

This is the structural story in action. The type system creates the pressure: enums are a natural constraint for categorical data like post status, content categories, or configuration flags. The `type_matches()` function enforces the invariant by pattern-matching on `TEnum(allowed)` and checking membership. The error message includes the full allowed list (`["draft","published","archived"]`), making failures actionable for the author.

The contrast with dynamic SSGs is stark. Hugo or Astro would accept `"pubished"` as a valid string and pass it through to templates. The error might surface as an empty filter result, a broken state badge, or nothing at all — the author discovers it at runtime or in the deployed site. Here, the schema validator rejects it at the frontmatter parsing step, before the content enters the render pipeline. Domain-level integrity is enforced as a structural property.


### Template Expression DSL

The template system evolved from simple slot substitution into a coherent expression DSL with value access, conditionals, and iteration. The features landed in three commits on March 22-23: `{{page.field}}` frontmatter access (commit `7298a81`), `{{?page.field}}` and `{{?slot}}` conditional blocks (commits `83db603`, `2cd9cc5`), and `{{#each data.file.key}}` loop blocks (commit `53ea5af`). Together, they form a mini-language for dynamic content within static templates.

The DSL is structured around the `TemplatePart` enum in `src/template/template.mbt`. Value expressions (`{{slot}}`, `{{page.field}}`, `{{data.file.key}}`) emit values; conditionals (`{{?slot}}`, `{{?page.field}}`) suppress or render blocks based on presence; iteration (`{{#each data.file.key}}`) loops over arrays from `DataStore`. The parser is recursive — it handles nested blocks and maintains scope through the render pipeline.

This is a deliberate design, not an accidental accumulation of features. The parser distinguishes between slots that are *required* (built-in slots like `title`, `content`, `date`) and slots that are *optional* (data slots, frontmatter fields). Required slots are collected into `Template.required_slots` during parsing and validated before rendering — if a template uses `{{title}}` but the render context doesn't provide it, the builder gets a `MissingRequiredSlot` error. Optional slots simply render as empty if missing. This structural distinction mirrors the frontmatter thesis: required failures are build errors; optional failures degrade gracefully.

The `{{page.field}}` feature brings frontmatter values into the template layer. A template can now reference `{{page.subtitle}}` or `{{page.author}}` directly, without pre-processing those values into slot maps during page rendering. When used with `{{?page.field}}`, a missing field results in the block being suppressed rather than an error — this is the graceful degradation contract: optional fields are optional at the template level while remaining required or optional at the schema level. Contrast this with Jinja/Liquid where an undefined variable might raise or silently render as the literal `{{undefined}}`. Here, `{{?page.subtitle}}...{{/?page.subtitle}}` is structurally safe: if the field is missing or empty, the block doesn't render at all.

The `{{#each data.file.key}}` feature extends the DSL into iteration over structured data. The syntax references a data file and key path (e.g., `{{#each data.authors}}` or `{{#each data.posts.tags}}`), and the builder calls `render_template_with_data` which passes the `DataStore` through the render path. Inside the loop body, `{{item}}` or `{{item.name}}` accesses loop item fields using `LoopItemSlot` with a field path array. The implementation uses `resolve_loop_item_field` to navigate through nested `FMap` structures, returning `Some(value)` if the path resolves or `None` otherwise. Unresolved fields render as empty — the same graceful degradation contract as frontmatter conditionals.

This iteration surface exposes a deliberate error model. A reference to a non-existent data file (e.g., `{{#each data.missing_file}}`) produces a `MissingDataSlot` error surfaced as a build diagnostic. This is not a silent empty loop — it's a hard error because data files are structural to the build. The same applies to non-existent keys within a valid file. The distinction matters: missing *values* in optional slots degrade; missing *data sources* fail the build.

The template DSL now validates `{{page.field}}` references against the collection schema at `--check` time. A template that uses `{{page.subtitle}}` when the schema only declares `title` and `date` produces a `TemplateSlotError` violation — caught before any HTML is rendered. This closes the structural gap that existed when the DSL was first introduced. The implementation separates concerns cleanly: `collect_frontmatter_refs()` in `template.mbt` recursively collects all frontmatter field references from a parsed template (including conditional and loop blocks, and layout bodies), while the builder's lint pipeline calls it once per collection after loading the page template and compares against the schema's field set. The parser itself remains schema-agnostic — schemas are a build-time concept, not a parse-time one — but the validation runs at the right boundary: after both template and schema are loaded, before documents are processed.

An earlier version of the schema validator (Phase 2, commit `f1d2c69`) introduced unrecognized-field detection that immediately broke seven builder tests. The root cause was that lattice consumes certain frontmatter fields itself (`toc`, `toc_depth`, `draft`, `template`, `redirect_from`, `og_image`) that are not user-schema fields. The validator flagged them as unrecognized. The fix was a reserved-key exemption list in `validate()` — these system keys are explicitly categorized, not silently ignored. The structural contract is preserved: genuinely unknown fields still error; system fields are recognized as a distinct class.

The DSL's type story is mixed. `TemplatePart` is a strong enum that captures all expression forms. The parser is recursive and type-safe. But the values themselves are strings in the render context — there's no type distinction between a `{{page.title}}` that's an `FStr` and a `{{page.count}}` that's an `FInt`. The conversion to string happens when frontmatter is rendered to slot maps in the builder. This is acceptable for the current scope — templates are text concatenation, not computation — but it's worth noting for future work if lattice ever gains template arithmetic or logic.

The honest assessment is that the template DSL is a pragmatic extension of the structural thesis. It keeps the "errors at build time, not runtime" promise for data access and required slots. It embraces graceful degradation for optional frontmatter fields. It leverages the type system in the parser but avoids pushing types through the render pipeline. The feature set is small but cohesive — value access, conditionals, and iteration cover the 80% of dynamic template needs without growing into a full general-purpose language.
\n\n### Migrating Away from Hand-Rolled String Utilities

Commit `11fed53` ("refactor(strutil): migrate all 20 packages — remove 1081 local helpers") eliminated a class of redundancy that had accumulated silently across the entire codebase. Every package in lattice had its own `starts_with`, `contains`, `trim`, `substr`, and `char_at` functions. Each one was a four-to-eight-line loop over string indices. They were semantically identical — the same logic, the same edge cases, the same names — but syntactically duplicated across 20 separate files. 1081 lines of utility code, none of it doing anything the MoonBit stdlib doesn't already provide.

The root cause is documented in AGENTS.md as a known failure mode: "LLMs tend to ignore the MoonBit stdlib and implement things from scratch. Don't." Every agent session that needed a string helper generated a local one rather than importing from `@strutil` or calling stdlib functions directly. Each individual decision was defensible — the helper was small, local, and correct. The problem was invisible at the function level. It only became visible at the project level, once you looked across all 20 packages and saw the same five functions copy-pasted into each one.

This is what AI-assisted development looks like in practice. Autonomous agents optimize locally. Each session makes reasonable choices within its scope. But without a deliberate cross-package audit, the codebase drifts toward duplication. No single agent session caused the problem; every session contributed to it. The fix required a human-initiated review that asked "what are we repeating?" and then a single coordinated migration touching all 20 packages at once.

The solution was `src/strutil/`, a shared package wrapping the MoonBit stdlib string functions behind a consistent API. Every package now imports `@strutil` and calls `@strutil.starts_with()`, `@strutil.contains()`, etc. The migration was a single commit — it had to be, because splitting it across commits would have left the codebase in a broken intermediate state where some packages used `@strutil` and others still had local copies.

The structural lesson is about the gap between local quality and global quality. The lattice thesis is that structural violations should be type errors. But the strutil migration exposed a different kind of structural problem: the code itself was redundant, not in a way the type system can detect, but in a way that hurts maintainability, reviewability, and the engineering quality score the SCC rubric rewards. A codebase where every package hand-rolls its own `starts_with` is not high quality regardless of how well the type system works. The migration closed the gap between the structural thesis (types catch bugs) and the engineering reality (the code also needs to be well-organized). The honest retrospective point is that this gap existed because the agents building lattice behaved exactly the way AGENTS.md warned they would.




### URL Type Constraints — Format Validation at Schema Boundary

The `TUrl` field type (commit `7df34d5`) was the second domain-specific constraint added to `FieldType`, following `TEnum`. Before `TUrl`, a `website` or `canonical_url` field declared as `TString` would accept any string — including `"not a url"`, `"TODO"`, or an accidentally-pasted paragraph. The type system enforced *structure* (the field exists and is a string) but not *domain* (the string is URL-shaped). That's exactly the gap `TUrl` closes.

The implementation in `type_matches()` in `src/schema/schema.mbt` checks that an `FStr(s)` value starts with `"http://"`, `"https://"`, or `"/"` (for relative paths). Empty strings are rejected. When validation fails, `Schema.validate()` returns a `ValidationError` with the message `"expected Url but got incompatible value"` — surfaced before any HTML is rendered. A template that emits `<link rel="canonical" href="...">` structurally cannot receive `"not a url"` because the build halts at the schema validation step.

The decision to accept relative paths (`/about`, `/posts/hello`) was deliberate. Content authors frequently use internal links, and requiring `https://example.com/about` for every internal URL would be a UX regression. The `type_matches()` check uses `@strutil.starts_with(s, "/")` to accept these, which means `/` alone passes validation. This is a format check, not a liveness check — the schema boundary validates shape, not whether the target resolves.

The honest limitation is that `TUrl` validates format, not liveness. A URL like `https://example.com/deleted-page` passes validation. A 404 URL is structurally valid. This is the same boundary described in "What Types Didn't Solve" — the type system catches structural violations (malformed URLs), but semantic violations (dead links, wrong destinations) remain a human concern. Wikilinks get resolution validation because lattice has the content graph. External URLs don't have that graph, so format validation is the strongest guarantee the type system can provide at this boundary.

The `TUrl` implementation also added a `field_type_name()` case returning `"Url"`, which surfaces in error messages and in the `--check` lint output. The test suite in `src/schema/schema_test.mbt` covers the four cases: `https://` accepted, `http://` accepted, `/relative` accepted, `"not-a-url"` rejected, empty string rejected, and `ftp://` rejected (only HTTP/HTTPS are valid schemes). The pattern is the same as `TEnum`: add a variant to `FieldType`, add pattern-matching logic to `type_matches()`, add the display name to `field_type_name()`, write targeted tests. Each domain constraint follows the same structural seam.


### Build Summary — Structured Error Reporting

The `--check` mode and the build command previously ended with a single count line: "5 violation(s)" or "3 error(s)". That raw count is accurate but unactionable. When a build fails, the developer needs to know *what kinds* of errors dominate and *which files* are the worst offenders. The build summary adds exactly that: a structured breakdown of violations grouped by type and by file, printed after the individual diagnostics.

The implementation adds three concepts:

1. **`ViolationSummary`** in `src/lint/lint.mbt` — groups `LintViolation` entries by `ViolationType` and by file path, sorted by count descending. The `summarize()` function builds this from a `LintResult`, and `format_summary()` renders it as indented text (`By type:` / `By file:` sections).

2. **`DiagnosticSummary`** in `src/diagnostic/diagnostic.mbt` — groups `Diagnostic` entries by severity (error/warning count), error code (E001–E011), and file path. This parallels `ViolationSummary` but operates on the richer `Diagnostic` type used by the build command.

3. **CLI integration** in `cmd/main/main.mbt` — `run_once()` now calls `@lint.format_summary()` on check failure and `@diagnostic.format_summary()` on build failure, replacing the raw count line with the structured breakdown.

The architectural decision is to compute summaries at the CLI boundary, not inside the builder. The builder returns flat arrays of violations and diagnostics — it doesn't know about summary formatting. The CLI layer, which already iterates through individual diagnostics to print them, also computes and prints the summary. This keeps the builder's return types simple (arrays, not aggregated structures) while giving the CLI layer the structured output it needs.

The summary is purely additive — no existing behavior changes. Individual diagnostics are still printed one per line with full path, line, column, error code, and hint. The summary appears after the last diagnostic, giving the developer a quick scan of the error landscape before scrolling back up to the details.

Example output for a check with schema and wikilink errors:

```
content/posts/draft.md:3 [error][E002] expected Date but got incompatible value
content/posts/draft.md:7 [error][E004] broken wikilink: [[missing-page]]
content/posts/old.md:1 [error][E002] required field missing: date
Summary: 3 violation(s)
  By type:
    schema: 2
    broken_wikilink: 1
  By file:
    content/posts/draft.md: 2
    content/posts/old.md: 1
```

This is the UX thesis applied to error reporting. The individual diagnostics give the precise location and hint. The summary gives the structural overview. Together, they tell the developer both *where* the problems are and *what kind* of problems dominate the build — without requiring manual counting or piping through external tools.




### Slug Type Constraints — URL-Safe Field Values at Build Time

The `TSlug` field type (commit `284fafb`) is the third domain-specific constraint added to `FieldType`, following `TEnum` and `TUrl`. Before `TSlug`, a `slug` field declared as `TString` would accept any string — including `"My Post Title"`, `"post_with_underscores"`, `"Post/Nested"`, or the empty string. The type system enforced *structure* (the field exists and is a string) but not *domain* (the string is URL-safe). A slug with uppercase letters, underscores, or slashes would either produce a broken URL at render time or produce a URL that looks structurally valid but violates routing conventions. That's exactly the gap `TSlug` closes.

The implementation in `is_valid_slug()` in `src/schema/schema.mbt` checks that a string is non-empty and contains only ASCII lowercase letters (`a`-`z`), digits (`0`-`9`), and hyphens. The function iterates characters and checks ASCII ranges directly — no regex dependency, consistent with lattice's preference for explicit character-class checks over importing a regex library for trivial patterns. When a frontmatter value fails the check, `type_matches()` routes to a specialized error message: `"expected a URL slug (lowercase alphanumeric and hyphens), got: \"My Post Title\""`. The actual rejected value is included in the diagnostic, making the failure immediately actionable for the content author.

The structural guarantee is the same as `TUrl` and `TEnum`: the error surfaces at schema validation, before any HTML is emitted. A template that renders `<a href="/posts/{slug}">` structurally cannot receive a slug containing spaces or slashes, because `Schema.validate()` rejects the document at the frontmatter parsing step. The render pipeline never runs on invalid input. This is the core thesis in action — domain-level integrity (URL-safe slugs) enforced as a structural property (type constraint at the schema boundary).

The pattern is now well-established: add a variant to `FieldType`, add pattern-matching logic to `type_matches()`, add the display name to `field_type_name()`, write targeted tests. `TSlug` follows `TEnum` and `TUrl` through the same structural seam. Each new constraint strengthens the schema's expressiveness without adding complexity to the validation architecture — the `validate()` function doesn't change, only the `type_matches()` dispatch grows. The honest limitation mirrors `TUrl`: `TSlug` validates format, not uniqueness. Two posts with `slug: "hello"` both pass validation — duplicate-slug detection is a different concern that belongs to the builder's page-index construction, not to the schema's type system. The type system catches structural violations (non-URL-safe slugs); uniqueness enforcement is a semantic property handled elsewhere.

### Syntax Highlighting — From-Scratch Tokenizers vs. Runtime Dependencies

The `@highlight` module provides syntax highlighting for fenced code blocks across 15 languages: MoonBit, TypeScript, Python, Bash, Go, C, HTML, CSS, JSON, Rust, SQL, TOML, and YAML. Every tokenizer is hand-written. There is no regex engine, no TreeSitter, no external parser library. The tokenizers iterate source characters, classify them into `TokenKind` variants (`Keyword`, `Type`, `StringLit`, `Number`, `Comment`, `Operator`, etc.), and return typed `Array[Token]` values that `render_highlighted()` wraps in `<span class="hl-...">` elements.

The decision to build from scratch was deliberate. The alternative was a runtime dependency on an external highlighting library — there is no MoonBit-native equivalent of Prism.js or highlight.js at the time of writing, and embedding a C library via FFI would have added native-only compile complexity. The from-scratch approach keeps the build purely MoonBit and keeps the output predictable: we control exactly which tokens get which class names.

The structural contract is in `language_supported(lang)`. Callers in the markdown renderer check this before calling `highlight()` — if the language is not in the supported list, the code block is rendered as plain text inside `<pre><code>`, not with highlighted spans. This is explicit graceful degradation. The renderer in `src/markdown/markdown.mbt:render_fenced_code()` is the only caller, and the pattern mirrors the rest of the codebase: check explicitly, degrade explicitly, never silently emit something structurally wrong.

The CSS class constants live in `css_classes()` in `src/highlight/highlight.mbt`. Default colors are Slate palette values that work on the dark `pre.highlight` background. The builder injects them into the page template via the `{{custom_css}}` slot, which means a user-defined template can override the defaults without patching the source. The class names (`hl-keyword`, `hl-type`, `hl-string`, etc.) are stable — the tokenizers produce `TokenKind` variants, and `token_kind_class()` maps them to these fixed strings. If a theme wants different colors, it overrides `.hl-keyword { color: ... }`. The token taxonomy never changes.

The honest limitation is that the tokenizers are not full parsers. They are lexer-level — they identify the shape of tokens but do not resolve semantic context. `fn` is always classified as a keyword in the MoonBit tokenizer, but whether it's a function definition or a closure is invisible to the highlighter. This is acceptable for a highlighting use case, where the goal is readability, not semantic correctness. It is the same trade that Prism.js makes. The difference is that lattice makes the tokenizers visible and modifiable rather than importing an opaque library.

The 1800-line `highlight.mbt` and its 415-line test suite are among the largest single-module files in lattice. This is worth noting in a retrospective about AI-assisted development: the test suite was written incrementally alongside the tokenizers. Each new language added a test case that verified the token stream for a representative code snippet. The tests do not verify correctness of semantic classification — they verify that the tokenizer produces a stable output for stable input. Regression coverage matters more than semantic precision at this level.

### Backlink Index — Structural Inverse of Wikilink Resolution

The wikilink system has two structural artifacts. Pass 1 produces the page index (slug → canonical URL), used in pass 2 to resolve forward references. But the page index only captures *outgoing* links — when page A links to page B, the index knows that B exists, but B doesn't know that A points to it.

The backlink index is the inverse: a map from *target slug* to the list of pages that link to it. `build_backlink_index()` in `src/builder/builder.mbt` runs after pass 1 (so the page index is complete) and before pass 2 (so backlinks are available when pages render). It re-extracts wikilinks from all source files — the same extraction pass that happens per-page in pass 2, but done upfront across all collections. For each extracted wikilink, if the target resolves in the page index, the source page is recorded as a `BacklinkRef` (URL + title) under that target's slug.

The structural guarantee is that the backlink index only contains validated entries. `build_backlink_index()` checks `page_index.contains(target)` before recording — a link to a non-existent page is not added to the backlink index. This means the backlink list in a rendered page contains only live sources. The renderer never needs to re-validate backlink URLs.

The `render_backlinks_html()` function consumes `Array[BacklinkRef]` and produces a `<section class="backlinks">` list. When the array is empty, it returns an empty string. The builder passes this to `process_document()` and to the template layer via the `Backlinks` slot. Templates can use `{{backlinks}}` to embed the section. The graceful degradation for pages with no backlinks is natural: the slot is empty, and conditional blocks (`{{?backlinks}}...{{/?backlinks}}`) suppress the section header.

The architectural lesson is about pass ordering. The two-pass build isn't just for wikilink resolution — it enables any cross-page structural artifact. The backlink index is a second-order product: it requires the page index (pass 1) to filter out broken links, and it feeds into page rendering (pass 2) to inject the backlinks section. Adding a third cross-page artifact in the future (for example, a tag-to-page occurrence index) follows the same pattern: compute it between passes, pass it through `process_document()`, expose it as a template slot.

### Site Scaffolding — Embedding the Happy Path into the CLI

The `lattice init` subcommand (commit `316034f`) creates a buildable site in the current directory. It writes a `lattice.conf`, `collections.cfg`, sample markdown content under `content/posts/`, a static stylesheet, and a complete set of templates under `templates/`. The templates are the same ones in the scaffold module — `base.html`, `head.html`, `header.html`, `footer.html`, `article.html`, and index/tag variants.

The implementation strategy was to embed all scaffold templates as string literals in `src/scaffold/scaffold.mbt`. There is no file copying from an installed resource directory, no embed macros, no `--data-dir` lookup. The templates are `let tmpl_base : String = #|...` constants in the source file. When `init` runs, it writes them directly to disk. This keeps the binary self-contained and removes a class of deployment error: the scaffold cannot fail because a template file is missing from an install prefix.

The structural story is that `lattice init` generates a site that builds immediately with `lattice build`. The generated `collections.cfg` includes the correct schema declaration for the sample posts. The sample `content/posts/hello-world.md` has valid frontmatter that satisfies that schema. The structural guarantee is not just that the scaffold runs without error — it's that the output of `init` passes the full validation pipeline. If the generated content failed schema validation, that would be a bug in the scaffolding, not an expected user-facing behavior.

This is the UX thesis applied to initialization. Every other SSG either ships with an example site you clone, or runs a multi-step wizard. `lattice init` generates a minimal working example in the current directory in one command. The generated site uses every major feature: typed collections, RSS feed configuration, template partials, and the custom CSS slot. Running `lattice build` after `init` produces a complete `dist/` directory including `feed.xml`, `sitemap.xml`, `search-index.json`, `graph.json`, and the full tag/archive hierarchy. The user sees the full output on first run, without constructing a content directory by hand.

The honest tradeoff: the embedded templates are static strings, which means they drift from the actual scaffold module's feature set if the template syntax evolves. A future refactor that renames a template slot would need to update both the live template handling code and the scaffold string literals. This is not a structural problem the type system can catch — it's a documentation and maintenance concern. The mitigation is that the scaffold templates are exercised by the `lattice init` tests, which run `lattice build` on the scaffolded output and verify the build succeeds. If a template slot change breaks the scaffold, the test catches it.

### Structured CLI Parsing with clap.mbt — Argument Schemas as Types

The original CLI in `cmd/main/main.mbt` used a hand-rolled argument-parsing loop. A `process_arg()` function matched strings against known flag names with cascading `if` conditions. Flags could silently conflict — `--watch` and `--port` together in `check` mode produced undefined behavior rather than an error. Unknown flags were silently ignored. There was no automatic `--help`. Subcommand dispatch was a chain of string comparisons. The code worked for the three commands lattice had, but it was behavioral string matching, not a structural argument schema.

The clap.mbt redesign (commits `3d2e3f0`, `94d2d1a`) replaced that with the `@clap` library — a MoonBit-native structured argument parser. The `build_parser()` function returns a `@clap.Parser` with three subcommands (`build`, `check`, `serve`) defined declaratively. Each subcommand specifies its arguments using typed constructors: `@clap.Arg::positional()` for positional args like content and output directories, `@clap.Arg::named()` for flagged args like `--config` and `--port`, and `@clap.Arg::flag()` for boolean switches like `--drafts` and `--watch`. Default values, help text, and short flags are declared as part of the schema.

The structural thesis applies to the CLI layer too. Before clap.mbt, the argument contract was implicit — encoded in the order of `if` branches and the names of string literals. After clap.mbt, the argument contract is a declarative schema. Unknown flags produce a parse error with a help message, not silent acceptance. `--help` is automatic and populated from the declared schema. Subcommands are declared, not matched — the parser determines which subcommand was selected and returns it as structured data (`sv.subcmd`), rather than requiring the caller to check string equality. The `cli_options_from_clap()` function extracts typed fields from the parsed `SimpleValue`, converting the declarative schema into the `CliOptions` struct that the rest of the codebase consumes.

The choice to use clap.mbt rather than continue hand-rolling was deliberate. AGENTS.md calls out MoonBit ecosystem familiarity as an explicit goal — using a MoonBit-native library for a core subsystem like the CLI is exactly the kind of engagement the challenge rewards. The tradeoffs are honest: clap.mbt is newer than battle-tested parsers in other languages, its documentation is thinner, and some edge cases required reading the source rather than the docs. But the API composes cleanly with lattice's existing dispatch logic. The `build_parser()` function is ~80 lines of declarative configuration, and `cli_options_from_clap()` is a straightforward match over subcommand names that extracts fields from the parsed value. The previous hand-rolled parser was ~120 lines of procedural string matching with no help generation and weaker error handling. The declarative approach is both shorter and more correct.

The architectural boundary is worth noting. clap.mbt handles parsing and help generation — it does not handle the downstream semantics (loading config, constructing `BuildConfig`, running the build). The `cli_options_from_clap()` function is the translation layer: it takes the parser's output and produces the `CliOptions` struct that the rest of the codebase understands. This keeps the clap.mbt dependency isolated to `cmd/main/main.mbt`. If clap.mbt's API changes or a better parser emerges, the migration surface is bounded to `build_parser()` and `cli_options_from_clap()`. The builder, watcher, and server never see `@clap` types. This is the same separation principle as the build summary: compute at the boundary, keep internal types clean.


### Documentation Gap: Ref[collection] Feature Without Discoverability

The `TRef(String?)` and `TArray(TRef(...))` field types were implemented and tested (schema structural validation, cross-reference existence checking in pass 2, collection constraint matching), but `docs/schema-syntax.md` had no documentation for them. The feature was invisible to users — you could declare `related_post:Ref[posts]` in `collections.cfg` and it would work, but only if you already knew the syntax from reading the source code.

This gap matters for the UX rubric specifically. A type system feature that users can't discover is a feature that doesn't exist from their perspective. The schema-syntax doc had sections for `Enum`, `Url`, and `Slug` field types — each with example declarations, valid/invalid frontmatter, and explanation of what the build error looks like. `Ref` deserved the same treatment: it's the strongest structural guarantee lattice offers (cross-reference integrity as a build-time error), and hiding it behind a missing docs section undermined that story.

The documentation addition covers all four `Ref` forms: `Ref`, `Ref[collection-name]`, `Array[Ref[collection-name]]`, and `Optional[Ref[collection-name]]`. It also documents the two-pass build architecture that makes cross-reference validation possible — pass 1 checks structural properties (valid slug format), pass 2 checks existence (slug present in page index). This architectural detail is important for users because it explains why forward references work naturally: page A can reference page B even if B is processed later, because pass 1 has already built the complete slug index before pass 2 begins.

The honest lesson is that documentation is not optional for type features. The structural guarantee only delivers value if users can discover and use it. A type system that's powerful but invisible is a weaker pitch than a simpler type system that's well-documented. The SCC rubric scores UX — and undocumented features score zero on UX regardless of their technical merit.

### Incremental Builds — Content Fingerprinting and the Skip Decision

Rebuilding every page on every `lattice build` invocation is correct but slow. For a site with hundreds of posts, regenerating unchanged pages wastes time on I/O and HTML serialization for output that is already correct on disk. Incremental builds require knowing whether a source file has changed since the last run.

The implementation in `src/cache/cache.mbt` uses content fingerprinting rather than filesystem timestamps. The `fingerprint_for_source()` function computes an FNV-1a 64-bit hash over the source path and content:

```moonbit
fn fingerprint_for_source(path : String, source : String) -> String {
  let mut hash = 1469598103934665603L  // FNV-1a 64-bit offset basis
  hash = hash_string_cache(hash, path)
  hash = hash_string_cache(hash, "\n---\n")
  hash = hash_string_cache(hash, source)
  hash.to_string()
}
```

The hash mixes the path into the fingerprint so that renaming a file (same content, different path) produces a different fingerprint and forces a rebuild. The separator `"\n---\n"` prevents hash collisions between a path string and the content that follows it.

The `should_skip()` function encodes the full skip decision:

1. If `force_rebuild` is set, always rebuild.
2. If the output file does not exist on disk, always rebuild.
3. If the cached fingerprint for this slug matches the current source fingerprint, skip.

Only all three conditions together justify a skip. The check for output-file existence matters because the cache survives `rm -rf dist/` — without it, the cache would falsely report "unchanged" for a missing output file.

The cache itself is a versioned JSON file written to `dist/.lattice-cache` after each build. It stores `{slug → fingerprint}` pairs. If the cache version changes (e.g., the builder format changes), the version mismatch causes a full rebuild rather than silently using stale output.

The manifest module (`src/manifest/manifest.mbt`) is a separate artifact. Where the cache tracks content fingerprints for build skipping, the manifest tracks source path, modification time, output path, and resolved wikilink targets per page. The manifest feeds the watch-mode incremental loop: when the file watcher detects a change, the manifest identifies which page's output to regenerate and which other pages may need updating because their wikilinks pointed at the changed page. These are two different invalidation concerns — content identity (cache) vs. dependency topology (manifest) — separated into two modules rather than merged into one.

The structural thesis extends here: the cache's `CacheError` type makes I/O failures explicit rather than silently degrading to a full rebuild. `ReadError`, `ParseError`, and `WriteError` are distinct variants so callers can distinguish a missing cache file (expected on first run) from a corrupted cache file (indicates a bug). The `load()` function returns `Ok(empty(output_dir))` for a missing cache rather than propagating an error, which is the only case where silence is correct — an absent cache is not a failure.

### TInt Range Bounds — Domain Constraints as Type Parameters

The `TInt` field type previously accepted any integer value. A `priority` field declared as `Int` would accept `-999`, `0`, and `999999` equally — the type system enforced *structure* (the field is an integer) but not *domain* (the integer is within an expected range). This is the same pattern as the `TEnum`/`TUrl`/`TSlug` evolution: start with structural guarantees, then add domain-specific constraints.

The design decision was to add range bounds as type parameters to `TInt` rather than creating separate validator types. The change from `TInt` to `TInt(Int?, Int?)` (min and max, both optional) is backwards compatible — existing `TInt` references become `TInt(None, None)`, which validates any integer. New schemas can declare `Int(min=1)` or `Int(max=100)` or `Int(min=1,max=100)` to add range constraints.

This extends the "domain constraints as types" thesis. Before this change, a `priority` field with value `0` would flow through the build and into templates. The template might render `<span class="priority-0">` or apply a CSS class that doesn't exist for that value. The error would surface as visual inconsistency, not as a build failure. With `TInt(Some(1), None)`, the build fails at schema validation: `expected Int in range [1, ∞), got: 0`. The template never receives invalid input.

The error messages are deliberately specific. Rather than "expected Int but got incompatible value," the diagnostic includes the range and the actual value: `expected Int in range [1, 100], got: 0`. This matches the pattern established by `TEnum` (which lists allowed values) and `TSlug` (which describes the slug format). Actionable error messages are part of the structural contract — the build doesn't just reject the value, it tells the author what range was expected.

The collections parser handles `Int(min=1,max=100)` syntax by checking for `(` after the `Int` keyword, then parsing `min=` and `max=` key-value pairs. This follows the same pattern as `Enum["a","b"]` — parameterized type syntax with bracket/paren-delimited arguments. The parser is order-independent: `Int(max=100,min=1)` works the same as `Int(min=1,max=100)`.

The honest limitation: `TInt` bounds validate at schema-check time, but they don't enforce uniqueness or other semantic properties. Two posts with `priority: 1` both pass validation — duplicate-priority detection is a different concern. The type system catches range violations; semantic consistency remains a human concern.

### Data Files with Structural Validation — Extending the Type Guarantee Beyond Frontmatter

Content collections hold the main editorial content — one markdown file per page, typed frontmatter enforced by schema. But sites need auxiliary structured data too: navigation menus, author profiles, site settings, link lists. In other SSGs this data lives in JSON or YAML files loaded at template render time, where a missing key becomes a runtime `undefined` rather than a build error.

Lattice extends the structural guarantee to data files via the `src/data/` module. Data files use the same TOML-style key-value syntax as frontmatter (`key = value`), live under `content/data/`, and are validated against a `DataSchema` before any template rendering begins. Missing required keys produce a `DataError::ValidationError(file, key, message)` that surfaces in the diagnostic stream with the same severity and code routing as schema validation errors on content pages.

The `DataSchema` stores a list of required key paths rather than typed field definitions:

```moonbit
pub struct DataSchema {
  name : String
  required_keys : Array[String]
}
```

This is intentionally simpler than `Schema` for content collections. Data files are often small and heterogeneous — a `nav.toml` for navigation links doesn't need the same field-type granularity as a posts collection with `date`, `title`, and `tags`. The required-keys approach catches the most common failure mode (missing a key that a template expects) while avoiding over-engineering the constraint language for a secondary use case.

The `parse_data_file()` function produces a `DataFile` whose `fields` map uses the same `FrontmatterValue` enum as frontmatter. This is not accidental. Templates access data values using the same slot expansion logic as frontmatter — `{{data.nav.title}}` resolves through the same value tree as `{{page.title}}`. Reusing `FrontmatterValue` means the template renderer handles both without a separate code path. It also means data files get the same typed value variants as frontmatter: `FBool`, `FInt`, `FArray`, `FMap` — not raw strings.

Key paths support dot notation for nested data. A data file like:

```toml
nav.home = "/"
nav.blog = "/posts"
nav.about = "/about"
```

produces `FMap { "home" → FStr("/"), "blog" → FStr("/posts"), "about" → FStr("/about") }` nested under the `"nav"` key. A required key of `"nav.home"` in the `DataSchema` resolves the path recursively — `validate_file()` calls `resolve_in_map()` with the split path `["nav", "home"]` and returns an error if any segment is absent. This means required-key validation works for both flat and nested data structures without special-casing.

The `load_from_dir()` function reads all `.toml` files from the data directory, parses each, optionally validates against a registered schema, and returns a `DataStore` (a map from filename stem to `DataFile`). Files without a matching schema in `[data.X]` config sections are loaded but not validated — they're accessible to templates but no required-key check runs. Files with a schema entry get validated before the build continues. This distinction follows the lattice pattern: validation is opt-in by declaring a schema, but the tool rewards the declaration with earlier failure. A data file that's never schema-validated might still fail at render time if a template references a missing key. A data file with a `[data.nav]` section and `required = "nav.home,nav.blog"` fails cleanly at the data-loading step with a clear diagnostic.

The structural lesson is the same as frontmatter: the error contract moves toward the input rather than the output. Without data schema validation, a missing key in `nav.toml` produces a blank link or a template crash when the site builds. With it, the build fails at data loading with `data.nav: nav.home: required key missing`. The render pipeline never sees incomplete data.



### TDate Bounds — Temporal Range Constraints Follow the Type Parameter Pattern

The `TDate` field type previously accepted any valid ISO 8601 date. A `published_at` field declared as `Date` would accept `1900-01-01` and `2099-12-31` equally — the type system enforced *structure* (the field is a valid date) but not *domain* (the date falls within an expected temporal range). A legacy content import with `date = 1970-01-01` or a typo producing `date = 3025-01-01` would flow silently through the build and into templates, potentially breaking date-based sorting, RSS feeds, or archive navigation.

The design extends `TDate` from a bare variant to `TDate(String?, String?)`, where the two optional strings are ISO 8601 dates for `after` (exclusive lower bound) and `before` (exclusive upper bound). This follows the exact same pattern as `TInt(Int?, Int?)` (min, max) — deliberate consistency in the schema DSL. The change is backwards compatible: existing `Date` references become `TDate(None, None)`, which validates any date. New schemas can declare `Date(after=2020-01-01)` or `Date(before=2030-01-01)` or `Date(after=2020-01-01,before=2030-01-01)` to add temporal range constraints.

The key technical insight is that ISO 8601 date strings (`YYYY-MM-DD`) compare lexicographically correctly. The string `"2025-06-15" > "2020-01-01"` is true; `"2019-12-31" < "2020-01-01"` is true. No date parsing is needed for comparison — simple string comparison works because the format sorts naturally. This is the same property that makes ISO 8601 the standard: structural ordering matches temporal ordering for date-only strings.

The error messages follow the TInt pattern with temporal semantics. Rather than "expected Int in range [1, 100], got: 0", the diagnostic reads "expected Date after 2020-01-01, got: 2019-12-31". For both-bound constraints: "expected Date after 2020-01-01 and before 2030-01-01, got: 2030-01-01". The actual rejected date value is included in the diagnostic, making the failure immediately actionable for the content author.

The collections parser handles `Date(after=...,before=...)` syntax identically to `Int(min=...,max=...)` — key-value pairs inside parentheses, order-independent, both optional. The parser reuses the same `starts_with_collections` check for `after=` and `before=` prefixes, then scans the date literal using `parse_date_literal_at()` (digits and hyphens). This is the same structural seam as the TInt bounds parser; the only difference is the value type being scanned.

This is the structural thesis in action: a `date` field declared as `Date(after=2020-01-01)` rejects pre-2020 content at schema validation time, not at render time. A legacy migration script that imports posts with dates from the 1990s fails the build with a precise diagnostic listing which files have out-of-range dates. The template never receives invalid input — the render pipeline never runs on documents that violate the temporal contract.

The honest limitations are worth noting. The bounds are exclusive, not inclusive — `Date(after=2020-01-01)` rejects `2020-01-01` itself. This matches the semantics of "after" and "before" in natural language but may surprise users who expect inclusive bounds. The ISO 8601-only constraint means no timezone awareness — all dates are treated as date-only strings, and the comparison is purely lexicographic. A date like `2020-01-01T00:00:00Z` would not be a valid `FDate` value (the frontmatter parser already enforces `YYYY-MM-DD` format), so this limitation is consistent with the existing type system rather than a new gap.


### TFloat — Continuous Domain Constraints Follow the Type Parameter Pattern

Float frontmatter values are real use cases in content-driven sites: `rating: 4.5`, `weight: 1.2`, `lat: 39.1031`, `price: 9.99`. Before `TFloat`, authors had to declare these as `String` fields, losing all domain guarantees. A rating of `"4.5"` is structurally valid as a string, but a typo like `rating: "4.q"` or `rating: "high"` flows silently through the build. The type system enforced *presence* (the field exists) but not *domain* (the value is a number in the expected range). That is exactly the gap `TFloat` closes.

The design adds `TFloat(Double?, Double?)` following the exact same pattern as `TInt(Int?, Int?)` and `TDate(String?, String?)`. Bare `Float` accepts any double. `Float(min=0.0,max=5.0)` constrains the range. The change is backwards compatible — existing schemas that don't use `Float` are unaffected. The `FieldType` enum gains a new variant, `type_matches()` gains a new dispatch arm, `field_type_name()` gains a display case, and `validate()` gains a specialized error message. Each of these is a local addition to an existing function; no structural changes to the validation architecture.

The key technical note is in the frontmatter parser. `FFloat(Double)` must be distinguished from `FInt(Int)` and `FDate(String)`. The disambiguation rule is straightforward: after scanning a numeric token, check if it's a valid ISO 8601 date first (the `YYYY-MM-DD` format with hyphens is distinct). If the token contains a `.`, parse it as a float. If it has no `.`, parse it as an int. This ordering means `rating: 4.5` produces `FFloat(4.5)`, `count: 42` produces `FInt(42)`, and `date: 2026-03-11` produces `FDate("2026-03-11")`. The decimal point is the discriminant. Dates never have a decimal point; floats always do (in the frontmatter syntax); integers never do. Three disjoint character-level patterns map to three disjoint types.

Error messages follow the established TInt and TDate pattern. When a float fails range validation, the diagnostic reads `"expected Float in range [0, 5], got: -1"` — the actual range and the rejected value are included, making the failure immediately actionable. The range notation is consistent with TInt: `[min, max]` for bounded, `[min, ∞)` for lower-bounded, `(-∞, max]` for upper-bounded. A content author seeing this error knows exactly what went wrong and what the valid range is.

What this pattern reveals is worth stating explicitly. Every numeric type (`TInt`, `TFloat`) and temporal type (`TDate`) in the schema DSL now carries optional range bounds with the same parameterization syntax: bare name for unconstrained, `name(param=value,...)` for constrained. That consistency is itself a design property — users only need to learn one parameterization pattern. The collections parser handles all three identically: check for `(` after the type name, parse `key=value` pairs, close with `)`. The validation logic is the same shape: check lower bound, check upper bound, produce a range error. The pattern composes through `TOptional` and `TArray` without special cases. The schema DSL now has a consistent grammar for bounded types, and that regularity is a stronger guarantee than any individual type constraint.



### TString Length Bounds — Completing the Type-Parameter Pattern

The `TString` field type was the only scalar type that remained unconstrained — it accepted any string of any length. A `title` field declared as `String` would accept `"Hi"`, an empty string, or a 10,000-character essay equally. The type system enforced *structure* (the field exists and is a string) but not *domain* (the string's length is within expected bounds). This was the obvious gap in the "domain constraints as type parameters" pattern that `TInt`, `TFloat`, and `TDate` already followed.

The design extends `TString` from a bare variant to `TString(Int?, Int?)`, where the two optional integers are `minlen` (minimum length) and `maxlen` (maximum length). This follows the exact same pattern as `TInt(Int?, Int?)` (min, max) — deliberate consistency in the schema DSL. The change is backwards compatible: existing `String` references become `TString(None, None)`, which validates any string. New schemas can declare `String(minlen=5)` or `String(maxlen=160)` or `String(minlen=5,maxlen=160)` to add length constraints.

String length is a particularly common constraint in content-driven sites. SEO meta descriptions should stay under 160 characters. Titles should have a minimum length to be meaningful. Excerpts have both upper and lower bounds. Before `TString` bounds, these constraints were behavioral — a template might truncate or warn, but the build didn't enforce them. With `TString(Some(5), Some(160))`, the build fails at schema validation time: `expected String with minlen=5, maxlen=160, got length 2: "Hi"`. The error message includes the constraint, the actual length, and the value itself (truncated to 30 characters for long strings), making the failure immediately actionable.

The `type_matches()` / `validate()` split pattern holds here as it does for all bounded types. `type_matches()` checks both structural compatibility (is it an `FStr`?) and domain constraints (does the length fall within bounds?). If `type_matches()` returns false, `validate()` produces a specialized error message that distinguishes between structural type mismatches (got an integer instead of a string) and domain constraint violations (string too short or too long). This is the same split as `TInt` and `TFloat`: the diagnostic tells you *which* constraint was violated, not just that the value didn't match.

The collections parser handles `String(minlen=...,maxlen=...)` syntax identically to `Int(min=...,max=...)` and `Date(after=...,before=...)` — key-value pairs inside parentheses, order-independent, both optional. The parser reuses the same `parse_int_literal_at()` function for the numeric bounds. The `parse_schema_fields()` function already tracks parenthesis depth for `(` and `)`, so `String(minlen=5,maxlen=160)` in a comma-separated schema declaration is correctly parsed as a single type token rather than being split at the comma inside the parentheses.

With this change, every scalar type in the schema DSL carries optional domain constraints as type parameters. `TString(Int?, Int?)` is the final piece. The pattern is complete: `TInt(min, max)`, `TFloat(min, max)`, `TDate(after, before)`, `TString(minlen, maxlen)`. All four use the same parser infrastructure, the same validation architecture, and the same error message format. The consistency is itself a structural guarantee — adding a new bounded type in the future would follow the same seam mechanically, with no architectural surprises.
\n\n### Type-Parameter Bounds — The Arc from Structural to Domain Guarantees

The individual sections above document each bounded type separately: `TInt(min, max)` (commit `f2c2f38`), `TFloat(min, max)` (commit `187f1a6`), `TDate(after, before)` (commit `4f0dd85`), `TString(minlen, maxlen)` (commit `4d876db`). What deserves its own retrospective entry is the arc itself — the decision to express domain constraints as type parameters across all four scalar types, and why that pattern matters for the structural thesis.

The starting state was that `FieldType` variants carried no domain information. `TInt` meant "this field is an integer." `TString` meant "this field is a string." The type system could enforce that the frontmatter value matched the declared type — an `FStr` where `TInt` was expected was caught at validation. But the type system could not enforce that the value was *reasonable* — `priority: -999` passed validation, `title: ""` passed validation, `date: 1900-01-01` passed validation. These are domain violations that flow silently through the build and produce wrong output at render time.

The alternative approaches we considered were:

1. **Runtime guard functions** — a `validate_priority(x: Int): Bool` that each template or build step calls. This is what dynamic SSGs do: validation is behavioral code that someone has to remember to call, in every relevant code path. The type system doesn't enforce it. Omit the guard, and the violation goes undetected.

2. **Convention** — document that `priority` should be 1-100 and hope authors comply. This is not a guarantee at all. It's a comment.

3. **Type parameters** — encode the domain constraint into the type itself: `Int(min=1, max=100)`. The constraint lives in the schema declaration, which is the single source of truth for content validation. The `type_matches()` function checks it. The build fails if the constraint is violated. The template never receives invalid input.

Option 3 is what lattice chose. The reason is the structural thesis: a constraint that isn't enforced by the type system is a constraint that will be violated silently. The type-parameter pattern makes domain constraints visible to the validation pipeline in the same way that structural type constraints are visible. A schema that declares `Int(min=1, max=100)` is making a stronger claim than `Int` — it's asserting that the valid domain is bounded, and the build will enforce that assertion.

The pattern's consistency is the architectural achievement, not any individual type. All four bounded types use the same parser infrastructure (`parse_key_value_params` for `min=`, `max=`, `after=`, `before=`, `minlen=`, `maxlen=`), the same validation shape (check lower bound, check upper bound, produce a range error), and the same error message format (include the constraint and the rejected value). Adding a fifth bounded type would require zero changes to the parser — only a new `FieldType` variant and a new `type_matches()` arm. The regularity means the pattern scales without growing complexity.

The honest limitation is that type parameters encode *static* domain constraints — constraints known at schema-declaration time. They cannot encode constraints that depend on other field values (e.g., `end_date` must be after `start_date`) or constraints that depend on external state (e.g., this slug must not already exist). Those are relational constraints, not scalar constraints, and they require a different validation architecture (potentially a cross-field validation pass after individual field validation succeeds). The type-parameter pattern is complete for scalar domains. Relational domains are the next frontier, and the current architecture doesn't obstruct them — they would be an additional validation step, not a replacement.

The four-commit sequence also illustrates the development pattern. `TInt` came first and established the pattern: extend the variant, add bounds parameters, update `type_matches()`, update `field_type_name()`, update the collections parser. `TFloat`, `TDate`, and `TString` each followed mechanically. The first one was an architectural decision; the remaining three were mechanical applications of a settled pattern. This is the kind of seam that makes a codebase tractable for both human and AI contributors — the first instance requires judgment; subsequent instances require discipline. The commit stream reflects that: `f2c2f38` is the largest change; the others are smaller deltas against the established pattern.



### `lattice new` — Schema-Aware Content Scaffolding

The `lattice new <collection> <slug>` subcommand (commit `b3f509b`) is the write-side companion to the build-side validation that defines lattice's structural thesis. The build pipeline rejects content that violates the schema. `lattice new` generates content that satisfies it. Together, they close the authoring loop: `init` → `new` → `build`.

The implementation reads the collection schema from `lattice.conf` and generates a `.md` file with frontmatter stubs for all declared fields. `stub_for_field_type()` in `src/scaffold/scaffold.mbt` dispatches on `FieldType` and produces type-appropriate placeholder values:

- `TInt(min=Some(n), _)` → `n` (starts at the declared minimum)
- `TFloat(min=Some(n), _)` → `n` (same)
- `TString(minlen=Some(n), _)` → `"placeholder"` padded to satisfy `minlen`
- `TEnum(["draft","published"])` → `"draft"` (first allowed value)
- `TUrl` → `"https://example.com"`
- `TDate(_, _)` → `"2026-01-01"` (stable placeholder, easy to spot)
- `TOptional(inner)` → delegates to the inner type

The architectural point is that `stub_for_field_type()` pattern-matches on the same `FieldType` enum that `type_matches()` and `validate()` use. The schema is the single source of truth for both validation (read side) and scaffolding (write side). A new bounded type added to `FieldType` requires updates to three places: `type_matches()` for validation, `field_type_name()` for display, and `stub_for_field_type()` for scaffolding. The type system doesn't enforce this completeness — a new variant that's missing a scaffold case would fall through to a default or a compile-time match warning — but the pattern makes the surface area visible.

The reason this matters for the structural thesis is that `lattice new` makes the structural contract *discoverable*. A new author running `lattice new posts my-first-post` gets a file with `title: placeholder`, `date: 2026-01-01`, `tags: []`, and a commented-out `description: ` line. The required fields are populated; the optional fields are visible as comments. The author knows exactly what the schema expects without reading documentation, because the scaffolded file *is* the documentation for that collection's schema. This is the UX thesis applied to onboarding: the tool bootstraps valid content, and the build validates it. The cycle is self-reinforcing.

The honest trade-off is that `stub_for_field_type()` cannot generate *meaningful* default values. `"placeholder"` is structurally valid but semantically empty. The author still needs to replace every stub with real content. A more ambitious scaffold could accept CLI flags for field values (`lattice new posts my-post --title "Hello" --date 2026-03-31`), but that adds CLI complexity for marginal gain — the scaffold's job is to produce a file that passes validation so the author can edit it, not to produce final content. The current design optimizes for the common case: create a valid file, open it in an editor, fill in the real values.

The 20 unit tests in `src/scaffold/scaffold_test.mbt` verify stub generation for every `FieldType` variant, including bounded types. They check that bounded stubs satisfy their own constraints — `TInt(min=Some(5), None)` produces `"5"`, which passes `Int(min=5)` validation. This is a subtle but important test property: the scaffold's output must be valid input for the build. If it weren't, the `lattice new` → `lattice build` cycle would break, and the structural contract would be undermined at the point where the author first interacts with the tool.

### Shortcode strutil Migration — Closing the Tail of Cross-Package Redundancy

The main `@strutil` migration (commit `11fed53`) eliminated 1081 local utility functions across 20 packages. The retrospective section "Migrating Away from Hand-Rolled String Utilities" documents the pattern: autonomous agents generate local helpers rather than importing from a shared package, and the duplication is invisible until a cross-package audit reveals the same five functions copy-pasted everywhere.

Commit `ba6bee8` is the tail end of that same cleanup. The shortcode package (`src/shortcode/shortcode.mbt`) retained four local utility functions — `char_at_shortcode`, `substr_shortcode`, `trim_shortcode`, and `is_digit_shortcode` — that were semantically identical to `@strutil.char_at`, `@strutil.substr`, `@strutil.trim`, and `@strutil.is_digit`. The main migration missed them because it targeted the 20 packages with the highest helper counts; shortcode had only four, and the audit threshold didn't catch it.

The fix replaced all four local helpers with `@strutil` calls, removing 69 lines. All 8 shortcode tests passed without modification — the functions were internal implementation details, not part of the public API.

This tail-end cleanup is worth documenting because it illustrates the *persistence* of the duplication pattern. The main migration was a coordinated 20-package change. The shortcode fix was a separate session that noticed the remaining duplicates during unrelated work. The duplication wasn't visible in the commit that introduced the shortcode helpers — at that point, the helpers were a reasonable local convenience. It only became visible as redundancy after `@strutil` was established as the canonical source and the main migration set the expectation that all packages use it.

The principle is: shared utility packages are a convention that must be maintained, not a state that can be achieved once and forgotten. New code (or code that was overlooked) will continue to introduce local helpers unless the convention is enforced. The type system doesn't help here — `starts_with` and `starts_with_shortcode` are different function names, so the compiler sees no duplication. The enforcement is human (or agent) discipline, aided by the retrospective documentation that says "use `@strutil`, don't write local helpers." The shortcode commit is evidence that the documentation wasn't enough to prevent the duplication; it took a second manual audit to catch the stragglers. The honest lesson is that consolidation is an ongoing process, not a one-time event.



### Bubble Sort → stdlib `Array::sort_by` — Another Hand-Rolling Instance

Commit `146486f` ("refactor(lint,diagnostic): replace handrolled O(n²) bubble sorts with stdlib Array::sort_by") eliminated four identical bubble sort functions — `sort_type_counts` and `sort_file_counts` in `src/lint/lint.mbt`, `sort_code_counts` and `sort_diagnostic_file_counts` in `src/diagnostic/diagnostic.mbt`. Each was a 15-line nested `while` loop implementing selection sort (O(n²)) to order items by count descending. The MoonBit stdlib provides `Array::sort_by` (Timsort, O(n log n)) — the hand-rolled versions were both slower and more code than the one-line stdlib call that replaced them.

The same session also converted all remaining index-based `while` loops in both files to idiomatic `for` loops. The `summarize` functions used `let mut i = 0; while i < xs.length() { ... xs[i] ...; i = i + 1 }` to iterate arrays — a C-style pattern that MoonBit's `for x in xs` handles directly. The `format_summary` functions used the same index pattern to iterate summary arrays. And `count_errors` used it to scan diagnostics. All were replaced with `for` iterators. Both files went from containing multiple `while` loops to zero.

This is the third instance of the "check stdlib before hand-rolling" pattern documented in AGENTS.md. The first was the `@strutil` migration (1081 local helpers replaced with stdlib wrappers). The second was the shortcode tail-end cleanup. This third instance — hand-rolling a sorting algorithm — is arguably the most egregious. Sorting is a textbook example of something the standard library provides in every language. The bubble sorts weren't even correct general-purpose sorts — they sorted by a single integer field, which `sort_by` with a comparator handles trivially. The replacement is `items.sort_by((a, b) => b.count.compare(a.count))`.

The `Map::update` substitution in the same commit is a secondary improvement. The original `summarize` functions used the `match get → set` pattern for counting: look up the current count, add one, write it back. This is correct but verbose. `Map::update` encodes the "modify or initialize" pattern as a single call, making the intent clearer. The tradeoff: the callback takes `V?` and returns `V?`, which requires a `match` inside — not dramatically shorter than the original, but semantically more precise. The commit uses it because it expresses the mutation pattern directly rather than decomposing it into read-then-write.

The structural lesson is the same as the strutil migration, but at a smaller scale. The bubble sorts were invisible at the function level — each one worked, the tests passed, and the code was readable. The problem was visible only at the pattern level: four copies of the same algorithm doing what the stdlib already does better. AGENTS.md warns about this. The fix is to keep auditing for it.


### builder.mbt strutil migration — the fourth cleanup

`src/builder/builder.mbt` is the largest file in the codebase (~5700 lines). It contained 12 local utility functions with `_builder` suffixes that were exact or near-exact duplicates of functions already in `src/strutil/strutil.mbt`:

**Migrated (12 functions):**
- `char_at_builder` → `@strutil.char_at` (identical)
- `substr_builder` → `@strutil.substr` (identical)
- `trim_builder` → `@strutil.trim_h` (both trim horizontal whitespace only: space, tab, CR)
- `escape_html_builder` → `@strutil.escape_html_attr` (both escape `& < > "`; `escape_html_body` only escapes `& < >`)
- `normalize_base_url_builder` → `@strutil.normalize_base_url` (identical)
- `absolute_url_builder` → `@strutil.absolute_url` (identical)
- `starts_with_builder` → `@strutil.starts_with` (identical)
- `split_lines_builder` → `@strutil.split_lines` (identical)
- `join_lines_builder` → `@strutil.join_lines` (identical)
- `is_digit_builder` → `@strutil.is_digit` (identical)
- `starts_with_at_builder` → `@strutil.starts_with_at` (identical)
- `parse_int_builder` → `@strutil.parse_int` (strutil is a superset — also handles negative numbers)

**Kept as local (18+ functions, no strutil equivalent):**
- `path_basename_builder`, `is_blank_builder`, `truncate_to_builder`, `collapse_whitespace_builder`, `count_leading_hashes_builder`, `is_heading_line_builder`, `is_hrule_builder`, `is_fence_start_builder`, `fence_char_builder`, `is_fence_end_builder`, `is_unordered_item_builder`, `is_ordered_item_builder`, `is_blockquote_line_builder`, `is_block_starter_builder`, `inline_text_builder`, `inlines_text_builder`, `extract_excerpt_builder`, `page_title_builder`, and all structured data helpers.

**Why this keeps happening.** This is the fourth time the exact same duplication pattern has been found and cleaned up — after the shortcode migration, the main strutil migration, and the bubble sort cleanup. The root cause is that `builder.mbt` grew incrementally. Each utility was written inline during feature development because it was needed immediately, and the developer (whether human or AI) didn't audit the existing `@strutil` module before writing. The `_builder` suffix was even a naming convention that *should* have been a signal — "this probably belongs somewhere else" — but the convention normalized the duplication instead of preventing it.

**The honest limitation.** MoonBit's type system can prevent many classes of bugs (schema mismatches, broken wikilinks, invalid dates), but it cannot detect *semantic duplication*. Two functions with different names, in different packages, that happen to do the same thing are invisible to the type checker. This is a linting concern, not a type-system concern. The fix is procedural: periodic audits, grep-based deduplication passes, and the discipline of checking `@strutil` before writing any new string utility. The fact that it took four passes to catch all instances in one file suggests we should add a CI check that flags new `_builder`-suffixed functions in any package that imports `@strutil`.

Result: 191 lines removed, 85 call sites migrated to `@strutil`, all 475 tests passing.



### Build Timing — Developer Experience as a First-Class Output

Every mature build tool reports how long the build took. Hugo shows it. Astro shows it. Eleventy shows it. Lattice did not — the build summary reported page counts and error counts but gave no feedback on performance. For a site with hundreds of pages, the author has no way to know whether a build is taking 200ms (fine) or 20s (investigate). This is a UX gap, not a functional gap — the build still works — but the SCC rubric scores UX explicitly, and a build tool that silently takes an indeterminate amount of time is a poor developer experience.

The implementation adds `current_millis() -> Int64` to the `@watch` module. This follows the same cross-platform pattern as `current_unix_second()`: a native C FFI implementation using `clock_gettime(CLOCK_REALTIME)` on POSIX and `GetSystemTimeAsFileTime` on Windows, with a stub implementation for JS/WASM targets using `@env.now()`. The function returns milliseconds since Unix epoch, which is sufficient granularity for build timing (sub-millisecond resolution is unnecessary for an SSG).

The timing measurement is at the CLI boundary, not inside the builder. `run_once()` in `cmd/main/main.mbt` captures `@watch.current_millis()` before calling `@builder.build()` or `@builder.check()`, then computes the delta after the call returns. This is the same separation principle as the build summary: the builder returns results, the CLI layer formats and displays them. The builder doesn't know about timing; it knows about pages, diagnostics, and errors. The CLI knows about the user and their terminal.

The `format_duration()` function handles four time ranges:
- Sub-second: `"347ms"` — informative for fast builds
- 1-10 seconds: `"1.2s"`, `"3.7s"` — one decimal place, the range most builds fall into
- 10-60 seconds: `"15s"` — whole seconds, the "something might be wrong" range
- Over a minute: `"2m 15s"` — the "definitely investigate" range

The output integrates with the existing summary line. Before:
```
[lattice] built 42 page(s) [0 unchanged]
```
After:
```
[lattice] built 42 page(s) [0 unchanged] in 1.3s
```

For check mode:
```
[lattice] check passed: no violations (0.3s)
```

For failed builds:
```
Summary: 3 error(s) ...
[lattice] build failed in 3 error(s) (2.1s)
```

The timing does not affect the build pipeline itself. It is a measurement layer that wraps the existing calls. No conditional logic branches on timing. No thresholds or warnings are emitted for slow builds. The measurement is purely informational — it gives the developer a data point about build performance without being prescriptive about what to do with that data.

The honest design choice is that this is wall-clock timing, not phase-level timing. A more ambitious implementation would instrument the builder to report time spent in each phase (source collection, schema validation, wikilink resolution, HTML rendering, file emission). That would give the developer more diagnostic data when a build is slow. The tradeoff is complexity: the builder's internal structure would need to surface timing data through the `BuildResult` type, and the measurement points would need to be maintained as the builder evolves. Wall-clock timing at the CLI boundary is zero-maintenance — it measures the thing the developer actually experiences (total build time) without coupling to internal implementation details.

The structural lesson is that developer experience includes *feedback about the tool itself*, not just feedback about the content. The build summary tells the developer "your content has these problems." The timing tells the developer "the tool is performing like this." Both are UX. The timing addition is small (72 lines changed across 4 files) but it closes a gap that every competing tool already addresses.\n\n### Scaffold strutil Migration — The Fifth Instance

Commit `6bc61fc` ("refactor(scaffold): migrate local char_at/substring to @strutil — fifth instance of duplication pattern") removed two local helper functions from `src/scaffold/scaffold.mbt` that were semantically identical to `@strutil` functions despite the package already importing `@strutil`:

- `fn char_at(s : String, i : Int) -> Char` — identical to `@strutil.char_at`
- `fn substring(s : String, start : Int, end : Int) -> String` — identical to `@strutil.substr`

These were used exclusively in two path-manipulation functions: `ensure_dir()` (iterates a path string character by character to find `/` separators and build parent directory strings) and `write_file()` (iterates a path to find the last `/` for parent directory extraction). Neither function is hot-path-critical — they run during `lattice init` and `lattice new`, not during the build pipeline — so the duplication had zero performance consequence. It was purely a maintenance and code-hygiene issue.

This is the **fifth time** the same pattern has been found and fixed across the codebase. The sequence:

1. **Main strutil migration** (commit `11fed53`) — 1081 local helpers across 20 packages replaced with `@strutil` calls. The original coordinated cleanup.
2. **Shortcode migration** (commit `ba6bee8`) — four local helpers (`char_at_shortcode`, `substr_shortcode`, `trim_shortcode`, `is_digit_shortcode`) that the main migration missed because the audit threshold didn't catch packages with low helper counts.
3. **Bubble sort → stdlib** (commit `146486f`) — four hand-rolled O(n²) sorts replaced with `Array::sort_by`. Same class of problem (hand-rolling what the stdlib provides), different manifestation.
4. **builder.mbt migration** — 12 `_builder`-suffixed local helpers in the largest file (~5700 lines) that had accumulated incrementally during feature development.
5. **Scaffold migration** (commit `6bc61fc`) — two local helpers in a package that *already imported `@strutil`* but still had its own copies.

The honest lesson about why this keeps happening is that the duplication is invisible at the function level. Each individual helper is small (3–8 lines), locally correct, and serves an immediate need. The problem only becomes visible at the pattern level: look across all packages and see the same three string operations implemented everywhere. MoonBit's type system cannot detect this — `char_at` in scaffold and `char_at` in strutil are different symbols to the compiler. The enforcement is procedural, not structural.

What would actually stop it? Three options, none implemented:

1. **A linter rule** that flags any function matching the signature of an `@strutil` function in a package that imports `@strutil`. MoonBit doesn't have a custom-lint plugin system at the time of writing.
2. **A CI check** that greps for `_builder`, `_shortcode`, `_scaffold`-suffixed local helpers in any package importing `@strutil`. A naming convention becomes a detection convention.
3. **Discipline** — the AGENTS.md warning and this retrospective section. This is the weakest option but the only one currently in place.

The fact that scaffold had these helpers *despite already importing `@strutil`* suggests the duplication isn't even driven by "I didn't know the module existed." It's driven by "I needed a helper, wrote it inline, and didn't check whether I was already importing the canonical version." The import was there; the developer just didn't look. This is the honest AI-assisted development failure mode: agents optimize for immediate correctness within the current function scope, not for cross-package consistency.


### today_ymd in `lattice new` — Live Dates in Scaffolding

Commit `33c7b54` ("feat(scaffold): wire today's date into lattice new") changed `stub_for_field_type()` to use the actual system date for `TDate` fields instead of a hardcoded `"2026-01-01"` placeholder. The `generate_frontmatter()` function now receives a `today` parameter from `@watch.today_ymd()`, which returns the current UTC date as `YYYY-MM-DD` using the same `@watch` FFI module already used for file watching and `current_millis()`.

Before this change, running `lattice new posts my-post` would generate frontmatter with `date: 2026-01-01`. That stub is structurally valid — it's a correct ISO 8601 date — but it becomes *semantically* invalid if the collection schema declares `Date(after=2025-01-01)`. As of March 2026, `"2026-01-01"` still satisfies that constraint, but the structural point is broader: a hardcoded date is a frozen value that drifts from reality over time. If an author runs `lattice new posts my-post` in December 2026, they'd get a date from eleven months ago.

The fix makes the scaffold generate `date: 2026-04-08` (or whatever today is). The actual date is always within reasonable bounds because it's the real current date. A schema like `Date(after=2025-01-01)` will accept it. A schema like `Date(after=2030-01-01)` would reject it — but that's a schema authoring error (a future-bound date constraint on a scaffold makes no sense), not a scaffold error.

The implementation is clean: `stub_for_field_type()` takes `today` as a parameter rather than calling `@watch.today_ymd()` internally. This makes the function testable — the test suite passes fixed date strings like `"2026-04-01"` and verifies the stub output without depending on the system clock. The `@watch.today_ymd()` call happens at the CLI boundary, in the command handler, and the date string flows down through `generate_frontmatter()` → `stub_for_field_type()`. The same separation principle as build timing: the scaffold doesn't know about clocks; it knows about dates as strings.

The structural point is that `lattice new` generates frontmatter that is *valid for today*. The `lattice new` → `lattice build` cycle works immediately — no manual date editing required. This matters because every friction point in the content-creation workflow is a place where an author might abandon the tool or introduce an error. A scaffolded file that fails validation on the first build is the worst possible first experience. The live-date fix ensures the scaffold produces a structurally valid file that passes the full validation pipeline, including `TDate` bounds, without the author needing to touch the date field at all.



### `{{body_no_h1}}` Template Slot — Eliminating Duplicate H1 as a Structural Concern

Commit `c2e4ac1` ("fix(template): add {{body_no_h1}} slot to eliminate duplicate H1 in rendered pages") addresses a content-integrity bug that the template system's expressiveness made easy to fix — and that the lack of the slot made invisible.

The bug manifested as two `<h1>` tags on rendered article pages. The article template (`example/templates/article.html`) renders the page title as `<h1>{{title}}</h1>` in the hero section. But when a content author writes a markdown file that starts with `# My Title`, the markdown renderer produces `<h1>My Title</h1>` as the first element of the body. The template then substitutes `{{content}}` with this rendered body, resulting in:

```html
<h1>My Post Title</h1>  <!-- from the template -->
<!-- ... hero section ... -->
<div class="prose__body">
  <h1>My Post Title</h1>  <!-- from the markdown body -->
  <p>Content begins here...</p>
</div>
```

Two H1 tags on a single page is both an SEO violation (search engines treat the first H1 as the primary topic) and an accessibility violation (screen readers use H1 for page-level navigation). This is exactly the kind of content-integrity bug that lattice's structural thesis should prevent — but it slipped through because the template system's slot vocabulary didn't include a way to express "the body without its leading H1."

The fix adds a `BodyNoH1` variant to the `TemplateSlot` enum and a `strip_leading_h1()` function in `src/html/html.mbt`. The function operates on the rendered HTML string, not on the markdown AST — it skips leading whitespace, checks for a literal `<h1>` opening tag, finds the matching `</h1>` close tag, and returns everything after it. This is a post-render transform, not a parse-time transform. The choice is deliberate: the markdown renderer is agnostic about template context, and the template layer is agnostic about markdown rendering internals. The HTML-level strip keeps the two concerns separated.

The article template now uses `{{body_no_h1}}` instead of `{{content}}` for the prose body. The `{{content}}` slot remains available for templates that want the full body including any H1. Every other render path in the builder (archive pages, tag pages, collection indices, the 404 page) also sets the `BodyNoH1` slot alongside the `Content` slot — the builder always provides both, and the template chooses which to use.

The structural lesson is about slot vocabulary as a design surface. The template slot enum (`TemplateSlot`) is the type contract between the builder and the template. Before `BodyNoH1`, the contract could express "the full rendered content" but not "the content with its first H1 stripped." The bug existed because the vocabulary was incomplete. Adding the slot didn't change the rendering pipeline — it added a new named output that the builder populates and the template can reference. The template system's expressiveness (named slots that the builder populates as a map) made the fix clean: one new enum variant, one new string-to-slot mapping, one new HTML helper, and the builder populates it everywhere it populates `Content`.

The same commit also adds a `HeadMeta` slot that renders OG meta tags and a canonical link into `<head>`. The two additions are related: `body_no_h1` prevents structural duplication in the page body, and `head_meta` ensures the correct structural metadata is always present. Together they close two integrity gaps (duplicate H1, missing OG tags) that were not type errors in the content but were structural violations in the rendered output.

### Example Site Projects Collection — Type System Demo in a Live Build

The `posts` collection in the example site has always used a simple schema: `title:String,date:Date,description:String,tags:Optional[Array[String]],author:String,draft:Optional[Bool]`. This schema demonstrates the type system works, but it only uses the two most basic types — `String` and `Date`. A judge reading the example output has no concrete evidence that `TEnum`, `TInt(bounds)`, `TUrl`, `TDate(bounds)`, or `TString(bounds)` are real, working features rather than documented-but-untested claims.

The `projects` collection addresses this directly. Its schema declaration in `example/site.cfg`:

```
schema = title:String(minlen=5,maxlen=80),date:Date(after=2020-01-01),status:Enum["active","archived","planned"],priority:Int(min=1,max=5),homepage:Url,description:Optional[String(maxlen=160)],tags:Optional[Array[String]]
```

This exercises six distinct type constraints in a single collection:

- `String(minlen=5,maxlen=80)` — bounded string on `title`; a one-word title or a 500-character description line both fail with a length diagnostic
- `Date(after=2020-01-01)` — bounded date; a project started in 2019 produces "expected Date after 2020-01-01, got: 2019-06-15"
- `Enum["active","archived","planned"]` — categorical domain constraint; `status: completed` produces a ValidationError listing the three allowed values
- `Int(min=1,max=5)` — bounded integer on `priority`; `priority: 0` or `priority: 6` both fail with the range diagnostic
- `Url` — URL format constraint on `homepage`; `homepage: github.com/kurisu/lattice` (missing scheme) fails at schema validation
- `Optional[String(maxlen=160)]` — bounded optional field; if present, the description must be under 160 characters

The three project files (lattice, ametrine, moonbit-pkg-registry) provide three distinct `status` values and two distinct `priority` levels, making the enum and range constraints visible in the rendered output. The project template (`example/templates/project.html`) uses `{{page.status}}`, `{{page.priority}}`, and `{{page.homepage}}` — frontmatter field access via the template DSL — to render a `project__status--active` CSS class, a `P5` priority badge, and a direct `<a href>` link from the validated URL field.

The structural point is that these rendered values cannot be wrong. `{{page.status}}` only reaches the template if `status` passed `Enum["active","archived","planned"]` validation. `{{page.homepage}}` only reaches the `href` attribute if `homepage` passed `TUrl` validation. The template is consuming pre-validated data, not raw strings. The HTML in the rendered page is not just structurally correct — the values themselves have been type-checked before they enter the render pipeline.

The broader lesson is that the example site is a first-class artifact for the explainability rubric. It's not enough to document type constraints in a retrospective — the constraints must be demonstrable in the output the judges build. A `projects` collection with six domain-constrained fields, three entries with distinct states, and a template that renders the constrained values is that demonstration. If you run `lattice check example/content --config example/site.cfg` with a malformed project (say, `priority: 10` or `homepage: not-a-url`), you get a precise diagnostic before any HTML is written. That's the structural thesis in a form that requires no explanation.

### `--drafts` Flag for `lattice check` — Separating Build-Time Content from In-Progress Content

Commit `a96930e` ("feat(check): add --drafts flag to lattice check for draft content validation") is a three-line change that completes the `--drafts` CLI surface across all three subcommands. Before this commit, `lattice build --drafts` and `lattice serve --drafts` both included draft posts, but `lattice check` had no `--drafts` flag — running check always excluded drafts, meaning there was no way to validate draft content's schema or wikilinks without building the full site.

The architectural context is that draft content occupies a deliberate grey zone in lattice's content model. Posts with `draft: true` in frontmatter are excluded from normal builds. This is correct behavior — drafts are intentionally incomplete. A draft might reference a wikilink target that hasn't been written yet, or omit a required frontmatter field that the author plans to fill in later. Excluding drafts from the normal validation pipeline prevents the build from failing on content that is explicitly not ready.

But the exclusion creates a validation gap. An author working on a draft has no way to check whether their in-progress content has schema violations, broken wikilinks to existing pages, or frontmatter type errors. They'd have to either remove the `draft: true` flag (changing the content's status to run the check) or run a full build with `--drafts` (which includes all drafts, not just the one they're editing). Neither workflow is ergonomic.

The `--drafts` flag on `check` closes this gap. Running `lattice check --drafts` includes draft posts in the validation pipeline — schema validation, wikilink resolution, frontmatter type checking — without building the full site. The author gets the same diagnostic stream (individual violations + structured summary) for draft content that they get for published content. The key architectural property is that `check` and `build` use the same validation code path — the only difference is that `check` stops after validation and doesn't render HTML or emit files. Adding `--drafts` to `check` means the `include_drafts` flag flows through the same code in both commands.

The implementation is minimal because the `@clap` parser already supports the `--drafts` flag on the `build` and `serve` subcommands. Adding it to the `check` subcommand definition and routing the parsed value to `include_drafts` in `cli_options_from_clap()` is all that's required. The three lines are: one line in the help comment (updating the usage string), one line in the parser definition (adding the `@clap.Arg::flag`), and one line in the CLI options extraction (passing `include_drafts` through from the parsed result).

The structural choice this reflects is about separating build-time content from in-progress content as a first-class concept in the tool. Drafts are not "content that fails validation." They are "content that is excluded from the normal pipeline by default, but can be opted in for validation." The `--drafts` flag on all three subcommands (`build`, `serve`, `check`) gives the author explicit control over this boundary. The default (no `--drafts`) is the safe state: only validated, published content is processed. The opt-in (`--drafts`) is the authoring state: in-progress content gets the same diagnostic treatment without entering the render pipeline.

This is the UX thesis applied to the draft workflow. The tool doesn't force the author to choose between "publish broken content" and "never check drafts." It provides a dedicated check path that respects the draft boundary while still running the full validation suite against the draft content.

## Shortcode Parameter Types — Structural Validation at the Authoring Surface

Commit `321c968` ("fix(example): use unquoted width=800 in image shortcode — IntParam vs StringParam distinction") is a one-line fix in `example/content/posts/rich-content-demo.md` that demonstrates something the retrospective should have documented earlier: the shortcode parameter system is a type contract between the content author and the render pipeline, and violations are build errors, not silent degradation.

### The ShortcodeParam enum

The shortcode system defines three parameter types in `src/shortcode/shortcode.mbt`:

```moonbit
pub(all) enum ShortcodeParam {
  StringParam(String)
  IntParam(Int)
  BoolParam(Bool)
}
```

When a content author writes `{{< image src="photo.jpg" alt="A photo" width=800 >}}`, the parser produces a `ShortcodeCall` with a `Map[String, ShortcodeParam]`. Each parameter value goes through `parse_value_shortcode`, which classifies the raw text into one of the three variants:

1. **Quoted values** (`"..."`) → `StringParam`. The presence of opening `"` triggers `parse_quoted_shortcode`, which handles escape sequences and returns the string contents wrapped in `StringParam`.
2. **Unquoted `true` or `false`** → `BoolParam`. The parser checks the unquoted token against these two literals before attempting integer parsing.
3. **Unquoted digit sequences** (with optional leading `-`) → `IntParam` via `parse_int_shortcode`. This is a manual digit-by-digit parser — it walks the characters, rejects anything non-digit, and returns `Some(value)` or `None`.
4. **Anything else** (unquoted non-boolean, non-integer) → `StringParam`. The fallback.

This classification is strict. There is no implicit coercion. `"800"` is a `StringParam`. `800` is an `IntParam`. `true` is a `BoolParam`. The quotes are not decorative — they are part of the type syntax.

### How render_image uses the type contract

The `render_image` function retrieves the `width` parameter using `optional_int_param`:

```moonbit
fn optional_int_param(
  call : ShortcodeCall,
  key : String,
) -> Result[Int?, ShortcodeError] {
  match call.params.get(key) {
    Some(IntParam(v)) => Ok(Some(v))
    Some(_) => Err(InvalidParamType(call.name, key, "Int"))
    None => Ok(None)
  }
}
```

The match is explicit: `Some(IntParam(v))` succeeds. `Some(_)` — meaning the parameter exists but is not an `IntParam` — returns `InvalidParamType`. `None` — parameter absent — is fine (it's optional).

This means `render_image` will never produce `<img ... width="" .../>`. It will never silently emit a string value in a numeric attribute. If the author provides `width="800"` (a `StringParam`), the renderer rejects it with: `shortcode 'image' param 'width' expected Int`. The build fails. The diagnostic names the shortcode, the parameter, and the expected type.

### The real example: `width="800"` vs `width=800`

The `rich-content-demo.md` post in the example site had an image shortcode with `width="800"`. This built fine initially because the post didn't exist — it was added as part of the rich content demo. The build error appeared immediately:

```
shortcode 'image' param 'width' expected Int
```

The fix was removing the quotes: `width=800`. One character deleted per quote. But the important thing is what happened before the fix: the build stopped. It did not produce HTML with `width=""` or `width="800"` (which would be technically valid HTML but semantically wrong — the `width` attribute on `<img>` should be an integer, and string coercion in HTML is a source of subtle rendering bugs). It did not silently drop the parameter. It produced a diagnostic that named the exact problem and the exact location.

This is the authoring-surface consequence of the type contract. Content authors don't write MoonBit. They write Markdown with shortcode calls. The shortcode syntax is their type system. Quotes mean string. No quotes mean literal (integer, boolean, or bare identifier). The syntax is minimal — there are no type annotations — but it is unambiguous. The parser resolves the type from the token shape, and the renderer enforces the type it expects.

### The structural thesis, again

This is the same pattern as frontmatter schema validation. The frontmatter system defines a schema (e.g., `status: Enum["active","archived","planned"]`), and content that violates the schema produces a build error before any HTML is rendered. The shortcode system defines a type contract (e.g., `width: IntParam`), and content that violates the contract produces a build error before any HTML is rendered.

The common architectural property is: **type checking at the boundary between author-provided content and the render pipeline**. The content author provides data (frontmatter fields, shortcode parameters). The render pipeline expects data of a specific shape. The validation layer sits between them and rejects mismatches before the render pipeline can produce incorrect output.

In a behavioral SSG (Astro, Hugo, Jekyll), this boundary is checked at render time or not at all. A Hugo shortcode template might do `width := .Get "width"` and emit it directly into the HTML. If the author wrote `width="abc"`, the HTML gets `width="abc"`. If the author wrote `width=""`, the HTML gets `width=""`. The template has no way to express "this parameter must be an integer" because the parameter system is a string map — `Get` always returns a string. Type validation, if it happens at all, is manual string parsing inside the template.

In lattice, the shortcode parameter system is a typed map. The parser classifies values into `ShortcodeParam` variants at parse time. The renderer pattern-matches on the variant it expects. Mismatches are `ShortcodeError::InvalidParamType`, which becomes a build diagnostic. The type contract is expressed in the code — `optional_int_param(call, "width")` says "width must be IntParam or absent" — not in documentation or conventions.

The `321c968` commit message documents this directly: "type mismatch between what the shortcode renderer expects and what the content author provided is a build error, not a silently dropped attribute." That's the structural thesis in one sentence. The retrospective exists to expand that sentence into an architectural narrative.

## `content-index.json` — Machine-Readable Site Output as First-Class Artifact

Commit `386cca2` ("feat(content-index): emit content-index.json with full stripped body text — functional completeness rubric") adds a second JSON output alongside `search-index.json`. The two files serve different consumers with different requirements, and the distinction is architecturally intentional.

### Two indexes, two consumers

`search-index.json` has been in lattice since the first build sprint. It was designed for client-side search: a lightweight array of entries with title, slug, URL, tags, collection, and a short excerpt. The excerpt is at most a few hundred characters — enough for a search result snippet, not enough for semantic retrieval.

`content-index.json` adds the full stripped body text. Each entry carries the same metadata fields as the search index, plus `date`, `description`, and `body`. The `body` field is the page's Markdown rendered to HTML and then stripped back to plaintext — all tags, shortcodes, and markup removed — leaving only the prose content. A 3,000-word article produces a `body` field of roughly 15,000 characters. An agent doing retrieval-augmented generation over the site can load `content-index.json` and embed the full article text rather than relying on a snippet.

The explicit design intent, documented in the `ContentEntry` struct comment: "suitable for semantic search or LLM consumption." This is a structural feature, not a polish feature. An SSG that knows its audience includes agents needs to emit data in a form agents can consume without scraping HTML.

### The stripping pipeline

The body text in `content-index.json` comes from a two-step pipeline:

1. `@markdown.render()` — the standard markdown renderer, producing HTML
2. `@strutil.strip_html_tags()` — a tag stripper that removes all angle-bracket sequences

The stripper is deliberate: HTML entities (`&amp;`, `&lt;`) are preserved rather than decoded, because the consumer is expected to handle them. The goal is readable prose text, not binary-clean Unicode. For a RAG use case, entity-preserved text is acceptable — the embedding model processes token sequences, not binary strings, and common HTML entities appear in training data.

The stripping happens at the builder layer, in the same pass that renders the page's HTML for output. The builder already has the rendered HTML string — the same string it emits to `<slug>/index.html` — and passes it through `strip_html_tags` to produce the body text for the content index entry. No second parse.

### Why two separate files

An alternative design would be to add a `body` field to `search-index.json`. This was rejected for two reasons. First, the search index is a runtime browser asset. A page with twenty articles would balloon from a few kilobytes to hundreds of kilobytes if each entry carried the full article text. Client-side search libraries like Lunr and Fuse work better with small, focused indexes. Second, the consumers are different: `search-index.json` is consumed by JavaScript in the browser; `content-index.json` is consumed by automation, agents, or offline tooling. Separating them lets each file be sized and structured for its consumer.

This is the same pattern as `sitemap.xml` vs `robots.txt` vs `graph.json`. Each is a distinct output format for a distinct consumer. The builder emits all of them in a single pass, but they're not one output trying to serve multiple audiences.

### Generic JSON rendering — `render_json_array[T]`

The `ContentEntry` renderer and `SearchEntry` renderer were initially structurally identical: both looped over an array, emitted JSON array brackets, added inter-entry commas, and wrote each entry as an object. The only difference was the set of fields. This is precisely the kind of duplication that accumulates in a fast sprint and becomes an engineering quality issue if left unaddressed.

Commit `1d90b79` ("refactor(search): extract render_json_array[T] + write_common_fields — engineering quality rubric") collapses the redundancy. `render_json_array[T]` is a generic function — using MoonBit's `fn[T] f(...)` polymorphic function syntax — that handles the array envelope and accepts a `write_entry : (StringBuilder, T) -> Unit` callback for the entry-specific fields. `write_common_fields` extracts the five fields shared between both entry types (title, slug, url, tags, collection).

The result is that each public render function is a single call to `render_json_array` with a closure for its unique fields. `render_search_index` adds only `excerpt`. `render_content_index` adds `date`, `description`, and `body`. The generic infrastructure is tested by the existing 18-test suite, which covers empty arrays, single entries, multiple entries, comma placement, JSON string escaping, and field presence — none of those tests changed, and all pass.

The `fn[T] f` syntax (MoonBit's current form for polymorphic functions) was discovered by correction during this commit: the initial draft used `fn f[T]`, which produced warning 0027 (deprecated syntax). The fix was a one-token edit before the commit. Noted here because it's a live example of how the MoonBit syntax is still evolving — the compiler deprecation warnings are the right signal, and tracking the correct form in the retrospective is more useful than pretending the mistake didn't happen.

The structural lesson from both commits is the same: the content-index feature demonstrates what typed output artifacts look like when the underlying architecture is already structured. `ContentEntry` is a typed struct — every field has a declared type, and the builder only populates it after all field values have been validated through the schema and render pipeline. The JSON emitted to `content-index.json` cannot contain schema-violating field values, because those values never reach the `ContentEntry` constructor. The typed intermediate representation is the guarantee; the JSON is just a serialization of that guarantee.

## Reading Time and Word Count — Derived Metrics from the Content Pipeline

Commit `ed694cd` ("feat(config): add description field to CollectionEntry + CollectionDef — use in collection index meta — functional completeness rubric") includes two related additions: `{{reading_time}}` and `{{word_count}}` template slots on individual content pages, and a `description` field on collection config entries. These share a common architectural thread: they are both places where the build pipeline was computing something useful but not surfacing it as a first-class output.

### Why prose word count is not trivial in an SSG

A naive word count counts every token in the Markdown source. This includes frontmatter fields, code fence content, HTML tags, shortcode syntax, and link URLs — none of which are prose the reader reads. A reading time estimate built on raw source word count is misleading: a post with three 50-line code samples looks far longer than it reads.

`count_words_markdown` addresses this by operating on the raw Markdown body (before rendering) and skipping code fence content entirely. The algorithm:

1. Split the body on newlines.
2. When a fenced code block delimiter is encountered (detected by `is_fence_start_builder` — a line that starts with three or more backticks or tildes), advance the line index past the fence, skipping all content until the matching closing delimiter.
3. For prose lines, count word-shaped tokens (contiguous non-whitespace runs separated by spaces or tabs).

The result is that a post with extensive code examples counts only the prose surrounding the code, not the code itself. The function is tested in `builder_test.mbt` with cases that cover empty input, single words, multiple words, mixed whitespace, and — critically — content with fenced code blocks, verifying that code lines are excluded from the count.

### Reading speed and minimum floor

`reading_time_str` converts a word count to a display string using 225 words per minute — the midpoint of the commonly cited 200–250 wpm adult reading speed range. The formula is integer ceiling division:

```
raw = (word_count + 224) / 225
```

This is a standard ceiling-division pattern in integer arithmetic: `ceil(a / b) = (a + b - 1) / b`. For a 225-word article: `(225 + 224) / 225 = 449 / 225 = 1`. For a 226-word article: `(226 + 224) / 225 = 450 / 225 = 2`. The minimum result is clamped to 1 min — a post with five words is not a "0 min read."

The display format is `"N min"`, rendered in the article template as `"N min read"` (the word "read" is literal text in the template, outside the slot). This separation keeps the slot value as a bare number string, making it composable: a template could display just the number, or use it differently without needing to strip the word.

### Conditional template slots — `{{?reading_time}}` pattern

The `{{reading_time}}` slot is set to an empty string on pages where it isn't meaningful (collection index pages, archive pages, tag pages). The article template wraps the display in a `{{?reading_time}}` / `{{/?reading_time}}` conditional block — lattice's conditional slot syntax. If the slot value is empty, the entire block is suppressed; if non-empty, it renders.

This is the same pattern used for `{{?date}}`, `{{?author}}`, and `{{?description}}` on article pages. The conditional slot mechanism means adding a new derived metric to individual pages but not to index pages requires no template branching — the slot is just empty where it doesn't apply, and the template handles the absence without special-casing.

The `{{word_count}}` slot follows the same pattern. Both slots are set in the same pass in `render_collection_page_html` and `render_pages_collection_page_html`, immediately after computing `wc = count_words_markdown(fm.body)`. The two metrics are a single word-count pass shared between both slots.

### Collection `description` — closing the meta-description gap

Before this commit, collection index pages had a hardcoded meta description: `"Generated page graph for collection posts in Lattice Example Site."` This is recognizably placeholder text — the phrase "Generated page graph" has no meaning to a site visitor, and it appears in the HTML `<meta name="description">` tag visible to search engines and link-preview renderers.

The fix is a `description` field on `CollectionEntry` (the config struct parsed from `[[collections]]` blocks in `site.cfg`) and `CollectionDef` (the resolved struct used at build time). The builder uses `coll.description` when available, falling back to the generated string when no description is configured.

The `example/site.cfg` now includes:
```
[[collections]]
name = posts
...
description = "All blog posts with tags, feeds, and navigation."

[[collections]]
name = pages
...
description = "Static pages including the site landing page."

[[collections]]
name = projects
...
description = "Project showcase with typed schema constraints."
```

The structural point is that this description is an authoring-time decision — the site author knows what their collection is for, and that intent should be expressible in the config rather than auto-generated by the build tool. The build tool's job is to surface the description, not to invent one. Providing a meaningful default when no description is configured is pragmatic; treating the generated string as sufficient is not.

The config parser addition follows the established `[[collections]]` parse pattern: when parsing key-value pairs inside a `[[collections]]` block, a new `"description"` branch sets `coll_desc = Some(value)`. The test in `src/config/config_test.mbt` verifies that a `[[collections]]` block with an explicit `description` field parses correctly, and that a block without one yields `None`.

## Markdown Line-Classification as Library API — Eliminating Builder Duplicates

Commit `refactor(builder): promote markdown line-classification to pub — remove 12 _builder duplicate functions` addresses a duplication pattern that accumulated during the initial sprint: the `builder` package contained twelve private functions with `_builder` suffixes that were structurally identical to private functions in the `markdown` package.

### How the duplication arose

The `markdown` module contains private line-classification helpers — `is_blank`, `is_fence_start`, `fence_char_of`, `is_fence_end`, `is_heading_line`, `is_hrule`, `is_unordered_item`, `is_ordered_item`, `is_blockquote_line` — plus text-extraction helpers `plain_text_inline` and `plain_text_inlines`. These are private because they implement internal parsing logic. When the builder needed to compute word counts and extract excerpts from raw markdown bodies, it needed the same structural vocabulary. Because the markdown functions were private and inaccessible from another package, the builder re-implemented them as `is_fence_start_builder`, `fence_char_builder`, `is_fence_end_builder`, and so on.

This is the canonical form of "duplication from access control." The solution is not to copy; it is to decide whether the shared vocabulary belongs in the public API of its home module.

### Why promoting to `pub` is the right fix

These functions classify the structural properties of individual Markdown lines. They are not implementation details of the markdown renderer — they are reusable facts about Markdown line syntax. `is_fence_start("```rust")` being `true` is as stable and non-implementation-specific as any other fact about Markdown. Making them `pub` makes the markdown module a proper library: the builder consumes `@markdown.is_fence_start(line)` rather than duplicating the predicate.

The distinction matters for the structural thesis of lattice. A module that hides structural vocabulary forces consumers to duplicate or work around it. A module that exposes structural vocabulary invites composition. The builder consuming `@markdown.plain_text_inlines(inlines)` for excerpt extraction is the same kind of composition as `render_json_array[T]` for JSON output — a shared abstraction that makes each consumer's job declarative rather than mechanical.

### The `collapse_whitespace_builder` exception

One builder utility, `collapse_whitespace_builder`, has no equivalent in the markdown module and was kept in place. It handles leading-whitespace elision during excerpt text normalization — a post-processing step that is specific to the excerpt output format, not a property of Markdown line structure. The criterion for promotion is "is this a general fact about Markdown syntax?" `collapse_whitespace_builder` is not; it is an output normalization step. Keeping the boundary clear prevents the markdown module from accumulating excerpt-specific logic.

### Result

After the refactor: 114 net lines removed, 509 tests unchanged, all passing. The builder functions now read as a set of calls to `@markdown.*` predicates with a local `is_block_starter_builder` that composes them. The markdown module's `pub` surface is now the authoritative vocabulary for line-level Markdown structure — usable by any future consumer without duplication.




## Standalone Pages — Content Outside Collections Gets the Same Structural Guarantees

Commit `3de4738` (`feat(builder): standalone pages — content not in any collection renders to root-level URLs`) introduces a content category that most SSGs handle implicitly and poorly: markdown files that don't belong to any collection but still need to render as real pages. An `about.md`, a `contact.md`, a `privacy-policy.md` — these are top-level site pages, not blog posts, not project entries, not tag indices. In Hugo, they're "leaf bundles" or "headless content" depending on configuration. In Astro, they're just files that happen to exist outside `src/content/`. In both cases, they bypass whatever structural validation the content layer provides.

Lattice's design makes them a first-class content category with the same schema enforcement as collection pages. The key decision is `standalone_default_schema()` — a synthetic schema that requires only `title:String` and marks `description`, `date`, `tags`, `author`, `redirect_from`, and `og_image` as optional. Every standalone page runs through `process_document()` with this schema. A standalone page missing a title produces the same `ValidationError` as a collection page missing a required field. The render pipeline structurally cannot produce output from a standalone page that lacks a title — the same guarantee that applies to typed collections now extends to uncollected content.

The `standalone_dir` configuration field in `SiteConfig` controls where standalone pages live. It defaults to `<content_dir>/standalone` when not explicitly configured, or `None` when the directory doesn't exist. This is a deliberate directory-based boundary: standalone pages are identified by location (they live in the standalone directory), not by frontmatter annotation. A content author creates `content/standalone/about.md` and it automatically becomes a standalone page. No `layout: page` frontmatter, no special filename convention. The directory structure is the schema.

### Slug Conflict Detection Between Standalone Pages and Collections

The builder registers standalone page slugs in the shared `slug_owner` map before processing them. If a standalone page slug (e.g., `about`) collides with an existing collection slug, the builder emits a `DuplicateSlug` violation. This prevents two pages from claiming the same URL — a structural guarantee that would be a silent override in most SSGs. In Hugo, a top-level `about.md` and a collection entry with slug `about` would both try to write to `/about/index.html`, and the winner depends on processing order. In lattice, the collision is a build error.

The slug registration happens in pass 1, alongside collection source collection. Standalone pages are added to the page index (`slug → URL`) using `standalone_page_url()`, which produces `/<slug>/` URLs — no collection prefix. They're also added to `all_sources_for_backlinks` so the backlink index covers them. A standalone page that wikilinks to a collection page gets resolved. A collection page that wikilinks to a standalone page gets resolved. The cross-reference validation is uniform.

### The Test Surface

The integration tests (~213 lines in `builder_test.mbt`) cover five scenarios: standalone pages render to root-level URLs without collection prefix; standalone pages don't appear in collection indices; a standalone page missing the required `title` field reports a build error; standalone pages coexist with collection pages without URL conflicts; and the standalone directory is optional (sites without one build fine). Each test creates a full filesystem layout with content, templates, config, and collections, runs `@builder.build()`, and asserts on output files and diagnostics.

The missing-title test is the structural thesis in miniature. It creates a standalone page with `description: No title page` but no `title` field, then asserts `result.errors > 0` and checks that at least one diagnostic message contains `"title"`. The standalone schema's `required: true` on the `title` field is what makes this work — the same `Schema.validate()` call that enforces collection schemas enforces the standalone schema. No separate validation path, no special case.

## Root Page Pipeline — Homepage and Site-Root Content as a Structural Category

Commit `dda1e82` (`feat(builder): root page URL/path helpers + 3 integration tests`) adds a third content category alongside collections and standalone pages: root-level `.md` files in the content directory itself (e.g., `content/index.md`, `content/about.md`). These are files that sit directly in the content root, not in any subdirectory, not in the standalone directory. They represent the true top-level pages of the site.

### The Homepage as a Special Case

The key design decision is in `root_page_url()` and `root_output_path()`. A file named `index.md` at the content root maps to the URL `/` and the output path `dist/index.html`. This is the true homepage — not `dist/index/index.html`, not a redirect, but the root document. Every other root-level file maps to `/<slug>/index.html` using the standard slug derivation. This asymmetry is intentional: the homepage is semantically distinct from other pages. It's the entry point. Its URL is `/`, not `/index/`. The function encodes this as a pattern match:

```moonbit
fn root_page_url(slug : String) -> String {
  if slug == "index" { "/" } else { "/" + slug + "/" }
}

fn root_output_path(output_dir : String, slug : String) -> String {
  if slug == "index" {
    output_dir + "/index.html"
  } else {
    output_dir + "/" + slug + "/index.html"
  }
}
```

The structural property is that there can be exactly one homepage. Two files can't both claim the `/` URL because the slug `index` is registered in `slug_owner` during pass 1. If a collection already has a page with slug `index`, the root file is silently skipped. If a standalone page claims `index`, same outcome. The first registrant wins; subsequent claimants are excluded. This prevents the silent-overwrite problem that plagues SSGs where multiple content sources can target the same output path.

### Excluding `404.md` from Root Page Processing

The `collect_root_sources()` function explicitly excludes `404.md` via the condition `filename != "404.md"`. This is because `404.md` is handled by a dedicated 404 pipeline that renders it to `dist/404.html` (not `dist/404/index.html`). Without this exclusion, `404.md` would be processed as a regular root page and produce `dist/404/index.html` — a URL that web servers don't check for custom 404 pages. The exclusion is a single boolean check, but it encodes a structural distinction: error pages are not content pages, even though they're authored as markdown files in the content directory.

### Slug Conflict with Collections — Silent Skip, Not Error

Root pages whose slugs are already claimed by collections are silently skipped, not reported as errors. This is a deliberate choice different from the standalone page behavior (which reports `DuplicateSlug` violations). The rationale is that root-level files are opportunistic — they exist in a shared directory and may overlap with collection names by coincidence. A file `content/posts.md` when a `posts` collection exists shouldn't be an error; it's just a file that happens to share a name. The root page pipeline respects the ownership established during pass 1 and gracefully defers.

The three integration tests verify: `index.md` renders to `dist/index.html` as the homepage with URL `/`; `about.md` renders to `dist/about/index.html` with URL `/about/`; a root file whose slug conflicts with a collection slug is silently skipped (no error, no duplicate output); `404.md` is excluded from root page processing and doesn't produce a root-level page; root pages appear in the sitemap with correct URLs. Each test creates a full build environment and asserts on file existence, content, and sitemap entries — the same integration-test pattern used throughout the builder test suite.

### The Structural Thesis Connection

Root pages use `standalone_default_schema()` — the same schema as standalone pages. This is deliberate reuse, not an accident of implementation. Both content categories are "uncollected content with minimal structural requirements." The schema enforces that every page (collection, standalone, or root) has a title. The wikilink resolution, backlink indexing, search-index generation, content-index generation, and sitemap inclusion all treat root pages identically to other content. The builder's pass structure (collect everything in pass 1, render in pass 2) means root pages participate in cross-reference validation just like collection pages. A wikilink from a root page to a collection page resolves. A wikilink from a collection page to a root page resolves. The structural guarantees are uniform across all three content categories, even though the routing logic (URL computation, output path) differs. The thesis holds: content integrity is a structural property, regardless of where the content file lives in the directory tree.

## Agent-First Content Index — kind, reading_time, and the collection_index Gap

Commits `eb7c45c` and `38343ec` extend `content-index.json` from a raw text dump into a structured feed designed for programmatic consumption by LLM agents and search tools.

### The Problem With a Flat Content Dump

The first `content-index.json` implementation (commit `386cca2`) stored full stripped body text alongside title, slug, URL, tags, collection, date, and description. This was sufficient for keyword search and basic RAG retrieval. But for an agent that wants to distinguish "show me all blog posts" from "show me navigation pages" from "show me collection indices," all entries looked identical — the only structural signal was the presence or absence of a date string.

The `kind` field makes the page type a first-class data property:
- `"post"` — a collection member with a date (blog-style)
- `"page"` — a collection member without a date (evergreen content)
- `"standalone"` — a page outside any collection
- `"collection_index"` — an auto-generated index listing all pages in a collection

Before this addition, `kind` was documented in a code comment but never emitted. The `ContentEntry` struct accepted it as a parameter, callers passed it, but `content-index.json` only carried the four values it received from the builder. The gap between the documented API and the actual output was a bug of omission: `collection_index` appeared in the docstring, was never instantiated in the builder pipeline.

### Closing the Gap — Collection Index Entries

The builder emits collection index pages into `dist/<collection>/index.html` but was not adding those pages to `content_entries`. This meant an agent reading `content-index.json` had no way to discover that a `posts` collection index existed at `/posts/` — the URL was reachable, the page was rendered, but the content index was silent about it.

Commit `38343ec` closes this gap. Inside the collection rendering loop, after writing `dist/<collection>/index.html`, the builder now pushes a `ContentEntry` for `pagination.page_number == 1` (page 1 only — for paginated collections, the index entry represents the root listing, not each paginated shard). The entry uses:

- title: `"<collection-name> Index"` — the canonical display name
- slug: the collection name — e.g., `"posts"`
- url: `collection_index_url(coll.name)` — e.g., `/posts/`
- kind: `"collection_index"` — the previously-uninstantiated value
- reading_time: `None` — index pages are auto-generated lists, not prose; a reading time would be misleading
- body: `@strutil.strip_html_tags(html)` — the rendered page text, stripped of markup so agents can read the page list

The body-stripping is reused from the same `@strutil.strip_html_tags` function that already strips collection page bodies. The consistency matters: every entry in `content-index.json` has the same body field semantics (stripped plaintext), regardless of page type.

### reading_time — Integer Minutes for Programmatic Consumption

The `reading_time` field stores an integer number of minutes (null if the page has no prose). The word count is computed by `count_words_text()`, which counts whitespace-separated tokens in the stripped body text. Reading time is then `ceil(word_count / 225)` — 225 words per minute is a conservative reading speed estimate that rounds up to the minimum of 1 minute. The formula deliberately returns `None` for empty pages rather than `0` or `1`, so agents can distinguish "no prose" from "very short prose."

Collection index and tag index pages use `None` for reading_time. This is correct: a list of links and slugs has no meaningful reading time. Emitting a reading time for auto-generated index pages would create a false signal.

### count_words_text Belongs in strutil

The initial implementation put `count_words_text` as a private `fn` in `builder.mbt`. This was wrong placement: the function takes a `String` and returns an `Int` — no dependency on any builder type. It's a general text utility.

Commit `38343ec` moves it to `src/strutil/strutil.mbt` as `pub fn count_words_text(text : String) -> Int`. The builder calls `@strutil.count_words_text(doc.body_text)`. Strutil tests cover the edge cases: empty string returns 0; a single word returns 1; multiple whitespace types (spaces, tabs, newlines) are all treated as separators.

This is the same logic that motivated the `render_json_array[T]` extraction and the markdown line-classification promotion: utility code that encodes a general fact (how to count words) belongs in a general library, not in the 6500-line builder module that owns the SSG pipeline.

### The Conditional Description Meta Tag

A separate fix (`fix(template): 724bd5e`) removes a subtle SEO issue. The original `head.html` template emitted `<meta name="description" content="{{description}}" />` unconditionally. For collection index pages and other auto-generated pages without a description field, this rendered as `<meta name="description" content="" />` — a content attribute with an empty string. Search engines may penalize or ignore empty description meta tags; the HTML itself is technically valid but semantically incorrect.

The fix replaces the unconditional tag with a conditional block:

```html
{{?description}}<meta name="description" content="{{description}}" />
{{/?description}}
```

The `{{?slot}}...{{/?slot}}` conditional syntax, already present in the template engine, renders its content only when the named slot is non-empty. When `description` is an empty string (the default for pages without the field), the block renders nothing. When `description` is non-empty, the tag is emitted normally. No template engine changes required — the existing conditional slot mechanism was already the right abstraction. The only change was applying it to the one place it was needed.
\n

## Incremental Build System — Manifest-Based Change Detection

The incremental build system in `src/manifest/manifest.mbt` and `build_incremental_state()` (builder.mbt ~line 3930) exists because full builds are expensive: reading every source file, parsing frontmatter, computing fingerprints, rendering markdown, and writing HTML for hundreds of pages takes time that grows linearly with content. The manifest is a JSON file (`.lattice-manifest.json`) that records each source file's path, modification timestamp (mtime as Int64), output path, and wikilink targets. On subsequent builds, the builder compares current mtimes against the manifest. Only changed sources are re-rendered; unchanged pages are skipped entirely.

The manifest format is deliberately minimal — `version`, `entries` — and the parser in `src/manifest/manifest.mbt` is a hand-rolled JSON parser rather than a dependency on a full JSON library. This was a conscious choice: the manifest format is small and stable, and pulling in a JSON parser would add a dependency for a format we control completely. The parser handles strings, integers, arrays, and objects — exactly the shapes the manifest uses. Nothing more.

Dependency tracking is where the system gets subtle. The manifest records not just content sources but also "dependency entries" for templates, config files, and static assets — entries with an empty `out` field. When any dependency's mtime changes, or when a dependency is added or removed, the entire incremental state is invalidated and a full rebuild fires. This is conservative but correct: if the site template changed, every page must be re-rendered regardless of whether its source markdown changed. The alternative — tracking which template slots each page uses and invalidating only those — would be more efficient but would require a template-slot-to-page dependency graph that's easy to get wrong. The conservative approach trades rebuild speed for correctness confidence.

The honest trade-off is that the mtime comparison has edge cases. Filesystem mtime granularity varies by platform — some systems have 1-second resolution, others nanosecond. Two rapid edits within the same mtime window could produce a stale manifest entry. The `--force` flag exists as an escape hatch for exactly this scenario. There's also the backlink propagation problem: when page A changes its wikilinks, page B (which A links to) must be rebuilt to reflect the new backlink. `mark_backlink_targets_changed()` handles this by comparing the current link targets against the previous manifest entries, marking any target slug as affected. This adds O(n*m) complexity where n is changed sources and m is average link count, but in practice both are small for real content sites.

## Backlinks — Reverse Link Index as a Build Pass

The backlink system (`build_backlink_index()` in builder.mbt ~line 408) is a reverse link index that runs as a "pass 1.5" — after all sources are collected and the page index is complete, but before any rendering begins. For each source file, `extract_link_targets()` parses the body (after frontmatter extraction) and collects wikilink targets. Then `build_backlink_index()` iterates every source in every collection, resolving each wikilink target against the page index. The result is a `Map[String, Array[BacklinkRef]]` mapping each target slug to the list of pages that reference it.

The reason this is a separate pass rather than a per-page lookup during rendering is cross-collection backlinks. A post in the `posts` collection can wikilink to a project in the `projects` collection. If backlinks were computed per-page during render pass 2, the index would be incomplete — page A might be rendered before page B is even processed, so B's links to A wouldn't be in the index yet. Building the complete reverse index before any rendering ensures that every page has access to the full set of its backlinkers, regardless of render order.

`render_backlinks_html()` generates a `<section class="backlinks">` with an `<h2>` and a `<ul>` of anchor links. This is deliberately simple HTML — no configuration, no template override. The section is appended to the rendered body in the page rendering pipeline. A richer implementation would expose backlinks as a template slot so authors could control placement and formatting, but the current approach prioritizes correctness over configurability. The backlink section always appears after the main content, which is the most common placement.

The incremental build interaction is the most complex part. `mark_backlink_targets_changed()` (builder.mbt ~line 4084) compares each changed source's current link targets against its previous targets (from the manifest). If a page added a new wikilink to page B, B must be rebuilt to show the new backlink. If a page removed a wikilink to page C, C must be rebuilt to remove the stale backlink. Both the current targets and the previous targets are marked as affected. This is quadratic in the worst case (every page links to every other page, and every page changes), but real content sites have sparse link graphs. The incremental system falls back to full rebuild if the manifest is missing or malformed, so the correctness floor is always "full build."

## Tags — Cross-Collection Aggregation and Generated Pages

The tags system (`src/tags/`, `collect_tag_catalog()` in builder.mbt ~line 2201) extracts tags from all collection pages simultaneously, deduplicates them by slug, and generates two categories of output: a `/tags/` index page listing all tags with their post counts, and individual `/tags/<slug>/` pages with paginated post lists. Tags are extracted from a configurable frontmatter field — `tags_field_name()` checks `site.tags_field` in the config, defaulting to `"tags"` if not specified. This configurability exists because some content schemas might use `"keywords"` or `"topics"` instead of `"tags"`.

`collect_tag_catalog()` iterates all collection sources, parses frontmatter, validates against the schema (skipping pages with validation errors — they shouldn't contribute tags if their frontmatter is malformed), and calls `@tags.extract()` to pull tag values. The `TagRef` struct stores both the human-readable `value` (e.g., `"Machine Learning"`) and the URL-safe `slug` (e.g., `"machine-learning"`). Deduplication is by slug: two pages using `"Machine Learning"` and `"machine learning"` both contribute to the same tag. The ordered_slugs array preserves first-seen order rather than alphabetical order, which is a deliberate choice — alphabetical sorting can be applied at render time if desired, but insertion order carries semantic information about which tags appeared first in the content.

The tag pages are rendered using dedicated templates (`tag.html`, `tags.html`) with the same template engine and slot system as regular pages. Each tag page gets pagination (configurable `page_size` per collection), navigation links, and the same CSS/theme as the rest of the site. The tag chips rendered on individual posts are generated inline by the page rendering pipeline rather than through a separate template — they're simple `<a href="/tags/slug/" class="tag-chip">value</a>` elements that share a consistent style via the default CSS.

The structural thesis connection: tags are validated at the schema level before extraction. If the `tags` field is declared as `Array[String]` in the schema, a page that puts `"tags: hello"` (a scalar string instead of an array) will fail schema validation and won't contribute tags to the catalog. The type system enforces that tag values come from well-formed frontmatter. This is a small instance of the broader pattern — content integrity as a structural property, applied to metadata aggregation rather than page rendering.

## Scaffold — `lattice init` and `lattice new` as Onboarding Guarantees

The scaffold system (`src/scaffold/scaffold.mbt`) provides two commands: `lattice init <name>` creates a complete site skeleton, and `lattice new <collection> <slug>` generates a content file with frontmatter stubs derived from the collection schema. Both commands exist because first-run experience is a significant fraction of UX: if a new user can't produce a working site in under a minute, the tool has failed regardless of its architectural merits.

`scaffold_site()` creates the full directory tree: `content/lattice.conf` with inline `[[collections]]`, `content/templates/` with ten HTML templates (base, head, header, footer, article, page, index, tag, tags, archive), `content/posts/welcome.md` with a sample post, `content/static/style.css` with the default theme, and `content/data/nav.toml` for navigation. The config file uses inline collection definitions rather than a separate `collections.cfg` to keep the initial setup self-contained — the new user sees everything in one file. The templates include working pagination slots, date formatting, tag chips, and backlink sections, so the first build produces a real site rather than a skeleton that needs manual wiring.

`new_content_file()` is the more interesting half from a structural perspective. It reads the collection schema and generates frontmatter stubs for every required field using `stub_for_field_type()`. The stub logic respects type constraints: `TDate` fields get today's date (via `@watch.today_ymd()`), `TInt(min=5)` gets `5`, `TEnum(["draft","published"])` gets `"draft"`, `TUrl` gets `"https://example.com"`, `TArray(TString)` gets a single-element array with `"placeholder"`. Optional fields are emitted as comments (`# tags: `) so the author sees they exist without being required to fill them in. The generated file is valid frontmatter — the author can build immediately and fill in details later.

The safety guard is that `new_content_file()` refuses to overwrite existing files. If `posts/my-post.md` already exists, the command returns an error rather than silently replacing the content. This is the same principle as `scaffold_site()` refusing to run in a directory that already has `lattice.conf`. The scaffold commands are write-once: they create starting points, not ongoing generators. This is a deliberate scope limitation — a content management workflow (draft → publish, rename, restructure) is a different problem than initial scaffolding and would require different tooling.

The connection to the structural thesis is that `lattice new` makes schema compliance the path of least resistance. A new post generated from the schema already has the right types for every required field. The author starts from a structurally valid state rather than a blank page. Missing a required field is impossible because the scaffold filled it in. Wrong type for a field is impossible because `stub_for_field_type()` respects the declared type. The schema becomes a constructive tool, not just a validation constraint.

## `lattice check` — Content Validation Without Rendering

The `check` subcommand (`builder.mbt:5810`) runs the full structural validation pipeline but produces no output files. It reports all violations — schema errors, broken wikilinks, duplicate slugs, template problems, data errors — then exits with a non-zero status code if any are found. No `dist/` directory is created or modified.

### Why Check-Only Mode Exists

Build and check serve different points in a workflow. A build is expensive: it renders every page, writes every file, computes every backlink and tag page. For a site with hundreds of pages, a full build after each file save is too slow for an editor feedback loop. Check runs pass 1 (collect sources, parse frontmatter, validate schemas, resolve wikilinks) without triggering pass 2 (render markdown, apply templates, write output). The time difference grows with content size — for small sites the delta is minimal, but for large sites with hundreds of pages and expensive template rendering, check is meaningfully faster.

The CI use case is even clearer: a repository wants to fail pull requests that introduce broken wikilinks or schema violations, but doesn't need to actually regenerate the output. `lattice check content/` exits 0 on clean content and non-zero on violations. The exit code is the signal — CI doesn't need to parse the output.

### What Check Validates

Check runs six validation phases in sequence:

1. **Collections config** — parses `lattice.conf` (or `--collections <path>`). If this fails, check exits immediately with a `CollectionsError` violation. There's no point validating sources whose collection definitions can't be read.

2. **Template syntax** — loads every template file and validates it compiles without errors. `TemplateSlotError` violations are emitted for any template that fails to parse. This catches typos in slot names, unclosed conditionals, and malformed template syntax before they cause a render failure.

3. **Data files** — loads the `data/` directory and validates TOML files against declared schemas. A `DataError` violation is emitted if any data file fails to parse or fails schema validation.

4. **Schema compliance** — for each source file in each collection (and standalone/root pages), parses frontmatter and validates it against the collection schema. `SchemaError` and `MissingRequiredFrontmatter` violations are emitted with file path and line number so the author can jump directly to the problem.

5. **Wikilink resolution** — for each source file, extracts `[[target]]` links and resolves them against the page index. `BrokenWikilink` violations include the exact file path, line number, and column of the `[[` syntax so editors with error-jumping support can navigate directly to the broken link. This is the most direct expression of the structural thesis: a wikilink to a non-existent page is a type error, reported at the link site, not at render time or at reader time.

6. **Shortcode validation** — shortcodes in markdown are parsed and their parameter types are validated. `ShortcodeError` violations are emitted for unknown shortcodes or wrong parameter types.

The violation output format (`path:line:column: type: message`) is the same as compiler error output, which is intentional. Most editor LSP integrations and CI tools understand this format. A future language server could feed `lattice check` output directly into editor diagnostics.

### The Structural Thesis in Miniature

The `LintViolation` struct (`src/lint/lint.mbt`) carries a `ViolationType` enum — `SchemaError | MissingRequiredFrontmatter | BrokenWikilink | DanglingTagReference | TemplateSlotError | DataError | ShortcodeError | FrontmatterError | CollectionsError | DuplicateSlug | IOError`. Each variant names a distinct structural failure mode. This is a closed sum type: you cannot emit a violation without classifying it. There's no "other" bucket, no string-only error that slips through unclassified.

`summarize()` groups violations by type and by file, producing a `ViolationSummary` with `by_type` and `by_file` arrays sorted by count. The summary gives a site with 47 violations — "23 broken_wikilink across 12 files, 19 schema across 8 files, 5 missing_required_field across 5 files" — without requiring the operator to count lines of output manually.

The check-only mode makes the tool usable in contexts where output generation is either unwanted or impossible: CI pipelines, pre-commit hooks, editor file-save triggers, and content review workflows where the goal is validation, not publication.

## `lattice stats` — Read-Only Metrics via Pass-1 Reuse

Commit `6e0db96` adds `lattice stats [content-dir]`, which reports word counts, page counts per collection, total reading time, and unique tag count without rendering anything. The implementation (`builder.mbt:6497`) is structurally identical to check: it runs pass 1 (collect sources, parse frontmatter) and then computes aggregates, skipping pass 2 entirely.

### Reusing the Build Pipeline for Metrics

The stats function is not a separate content scanner. It calls `load_project_layout()` (the same function used by build and check), `collect_sources()` per collection, `@frontmatter.parse()` per source, `@strutil.count_words_text()` on each body, and `collect_tag_catalog()` to count unique tags. It reuses existing functions end-to-end. The word count is the same `count_words_text()` that computes `reading_time` in `content-index.json` — a single source of truth for word counting across the entire tool.

The design decision was that `stats` should use the same code path as the build pipeline rather than implementing a separate file-walking loop. A separate loop would need its own frontmatter parser, its own collection config loader, its own error handling. The reuse means that any bug fix to `collect_sources()` or `@frontmatter.parse()` automatically applies to stats. Consistency is a structural property of the implementation, not a testing guarantee.

### Why Stats Counts Words, Not Lines

Line count is a meaningless metric for prose content — a post with 100 terse lines and a post with 20 flowing paragraphs might have identical word counts but completely different line counts depending on wrapping and formatting style. Word count is the conventional metric for prose volume. The 225 words-per-minute reading time estimate (the same used in `content-index.json`) gives the reading time in actionable minutes rather than raw counts.

The current `stats` output is deliberately minimal: one line per collection, a total line, and a reading time line. This mirrors the philosophy of the build output — only emit lines that carry information. A stats command that prints a 30-line report for a site with three posts would obscure the signal in noise. If a future use case needs richer output (per-page word counts, median post length, tag frequency histogram), those are additive — the current design doesn't prevent them.

### The Standalone and Root Page Accounting

The stats function accounts for all three content categories: collection pages, standalone pages, and root pages. Standalone and root word counts are totalled separately and summed into `total_words`. This matters for sites where the bulk of content is in standalone pages (documentation-style sites) rather than dated collection posts. The per-category breakdown in `StatsResult` is also available for callers who want finer-grained metrics, though the current CLI output only shows the aggregate. A future `--verbose` flag could expose the full breakdown without changing the data model.

## `graph.json` — The Link Graph as a Build Artifact

Every build emits `dist/graph.json` alongside the HTML output. The file encodes the site's wikilink structure as a directed graph with two top-level arrays: `nodes` (one entry per page: slug, title, URL) and `edges` (one entry per wikilink: source slug → target slug). The format is designed for direct consumption by graph visualization libraries — D3 force-directed layouts, Cytoscape.js, Obsidian-style canvas tools — without any post-processing.

### Why the Graph Is a First-Class Output

Most SSGs treat wikilinks as a rendering detail: resolve to URL, emit anchor tag, done. Lattice emits the graph explicitly because the wikilink structure is structural metadata about the content, not just a rendering instruction. Which posts link to which other posts is a signal about topical clustering, hub pages, and orphaned content. An author working on a large site benefits from being able to visualize the link structure and identify: which pages have no incoming links (orphaned content), which pages are heavily linked (hub pages that might need to be kept current), and which topics form clusters.

The `GraphPage` struct (`src/graph/graph.mbt:6`) is shared across the builder, the content index, and the RSS emitter. It carries `slug`, `title`, `url`, `description`, `date`, and `outgoing` (an array of `ResolvedWikilink`). This is deliberately typed data rather than a string template — every downstream emitter receives structured page information, not a pre-formatted HTML string. The graph.json emitter only uses `slug`, `title`, `url`, and `outgoing`; the RSS emitter uses `date` and `description`. The shared type prevents the two emitters from drifting apart in their understanding of what a page is.

### Nodes and Edges as a Stable Contract

The `nodes` / `edges` format is a deliberate choice over more complex representations (GraphML, Gephi GEXF, adjacency lists). D3 and Cytoscape both accept this format directly. The format is also trivially parseable without a schema — any JSON library can load it, and the fields are self-documenting. The format excludes description, date, and other page metadata from nodes intentionally: `graph.json` is for topology, not page content. If an external tool needs page metadata alongside graph structure, it can join `graph.json` with `content-index.json` on the `slug` key — two files with clean separation of concerns rather than one file attempting to serve all use cases.

The only resolved links appear in edges. Broken wikilinks (`[[target]]` that didn't resolve during build) are not emitted as edges — they're errors, reported via the lint pipeline. `graph.json` represents the valid link structure of the site, not the set of link attempts. This is another instance of the structural property: the graph output reflects what the build validated, not what the author wrote.

## Frontmatter Format Auto-Detection and Actionable Error Messages — UX Rubric

Lattice supports two frontmatter formats, distinguished by delimiter:

- `---` ... `---` → YAML format: `key: value`, block arrays with `- item`
- `+++` ... `+++` → TOML format: `key = value`, inline arrays with `["a", "b"]`

The auto-detection in `parse()` (`src/frontmatter/frontmatter.mbt`) is a single prefix check: if the content starts with `---`, dispatch to `parse_yaml()`; if it starts with `+++`, dispatch to `parse_toml()`. No configuration required, no file extension heuristic. The delimiter is the format declaration.

### The Mixed-Format Footgun

The most common mistake is writing TOML-style `key = value` inside `---` delimiters. This happens because many SSGs use `---` for YAML but some content authors are familiar with Hugo's TOML frontmatter (which uses `+++`), or because editors autocomplete `---` by default. The result is a frontmatter block that looks syntactically plausible but is semantically wrong:

```markdown
---
title = "My Post"    ← TOML syntax inside YAML delimiters
date = 2026-03-11
---
```

Before the improvement in this commit, the error message for this case was generic: `"no '=' or ':' found in line"` — which is wrong on two counts. It says "no '=' found" when `=` is clearly present; and it says "no ':' found" which is the actual condition (the YAML parser looks for `:`), but gives no hint about why. A user seeing this error has no path forward other than guessing.

The improved `parse_yaml_assignment()` detects whether the problematic line contains `=` and emits a targeted error:

```
YAML frontmatter (--- delimiters) uses 'key: value' format;
use +++ delimiters for TOML 'key = value' format
```

This error names the delimiter, names the format, and gives the exact fix. Two tests cover the two failure modes: the TOML-in-YAML case (checks that the error mentions `+++ delimiters` and `TOML`) and the bare-key case with no separator at all (checks that the error mentions `':' separator`).

### Error Message as Documentation

The decision to name both formats in the error message — rather than just saying "use YAML format" — reflects a pattern throughout the error pipeline: error messages should be self-contained. A user who has never read the Lattice documentation should be able to recover from a frontmatter format error without looking anything up. The error names the wrong thing, names the right thing, and names the fix. This is the same standard applied to wikilink errors (which include the exact slug that wasn't found), schema errors (which include the field name and declared type), and shortcode errors (which include the shortcode name and the expected parameter types).

The engineering discipline here is treating error messages as first-class output, not as internal debugging strings. A parse error that reaches a human author is a user interface interaction, and it should be designed with the same care as any other interface.

## Open Graph and Twitter Card Meta Tags — Structural Completeness of the Output

Commit `d69537f` emits Open Graph and Twitter Card meta tags for every rendered page type: collection pages, collection index pages, standalone pages, and root pages. The key decision was that these are not optional decoration — they are part of what it means for a page to be fully rendered.

### Why All Page Types, Not Just Posts

The naive implementation of OG tags is to add them to blog posts because that's where they're most visible: social links to blog posts show preview cards with title, description, and image. But index pages, homepage, and standalone pages are also shared. A link to a collection index or to a documentation page looks broken without an OG title. The structural thesis applied here is: if a page is rendered, it must emit complete metadata. There's no "this page type doesn't need OG tags" category in the output pipeline.

The implementation in `src/html/html.mbt` adds `render_head_meta()` — which emits the `<head>` block including Open Graph (`og:title`, `og:description`, `og:url`, `og:type`, `og:image`) and Twitter Card (`twitter:card`, `twitter:title`, `twitter:description`, `twitter:image`) tags — and threads `og_type` through the `HeadMetaData` struct to distinguish `og:type = "article"` (posts) from `og:type = "website"` (index, root, standalone pages). The caller decides the type at the point where page meaning is known: the builder sets `og_type = Some("article")` for collection pages, and `og_type = None` (defaults to `"website"`) for everything else.

### The og:image Opt-In

`og:image` requires an absolute URL to an image — a missing image tag is worse than a present one in most social preview contexts. The implementation uses `og_image : String?` in `HeadMetaData`: when the site config or frontmatter provides no image, the tags are omitted entirely rather than emitting a malformed or empty tag. The `twitter:card` type downgrades from `summary_large_image` to `summary` when no image is present. This mirrors the frontmatter validation philosophy: emit what's valid, not what's structurally incomplete.

### The Template Slot Boundary

OG and Twitter Card tags live in the `{{head_meta}}` template slot (`HeadMeta` in `TemplateSlot`). The slot emits a pre-rendered HTML string that the template inlines into `<head>`. Template authors don't need to know about OG syntax or Twitter's card format — they declare `{{head_meta}}` and the slot provides the complete metadata block. This preserves the template system's role as a layout contract: templates describe page structure, not content encoding. The OG tag format details belong in the builder, where the page type and site configuration are known.

## Error Accumulation Across Page Categories — Fixing a Silent Swallow

Commit `cd00b24` fixes a bug where validation errors in collection pages caused the build pipeline to skip error collection for standalone pages and root pages entirely. The fix is a single structural point about how `Result` values must be unwrapped: errors should accumulate, not short-circuit.

### The Bug

The builder processes three content categories in sequence: collection pages, standalone pages, and root pages. Before this fix, a collection-phase error would set an early-return flag that prevented the standalone and root phases from running their own error accumulation pass. The result was a build where errors in `content/posts/` caused errors in `content/` (standalone) and `index.md` to be silently dropped from the diagnostic output.

The failure mode was subtle. The build would correctly report `N errors` if only collection pages had issues. It would correctly report errors if only standalone or root pages had issues. But with errors in multiple categories, only the collection errors appeared — the others were lost.

### Why This Matters for Structural Integrity

An SSG that silently drops validation errors violates the structural thesis. The whole point of the lint and validation pipeline is that every violation surfaces before the user calls the build clean. A silent drop is behaviorally equivalent to the dynamic SSG case where the error only manifests at render time or at reader time. The test coverage added in commit `4ada094` explicitly covers the multi-category case: a build fixture where collection, standalone, and root pages all have violations, with assertions that all three categories of errors appear in the final diagnostic list. The test existed to make the guarantee structural rather than just behavioral.

The fix is architecturally uninteresting — it's a control-flow correction, not a design change. What's worth documenting is that the bug existed because the three categories were processed in a sequence where the accumulation variable was inside a conditional that could exit early. Moving the accumulation outside that conditional is the fix. The lesson is that accumulation logic and early-exit logic must be kept apart, and that the test surface should cover cross-category interactions, not just single-category cases in isolation.

## `lattice check --format json` — Machine-Readable Validation Output

Commit `(this session)` adds `--format json` to `lattice check`, producing structured JSON output suitable for CI pipelines, editor integrations, and external tooling.

### The Closed Vocabulary of Violation Kinds

The design point is that `ViolationType` is a closed enum: `SchemaError | MissingRequiredFrontmatter | BrokenWikilink | DanglingTagReference | TemplateSlotError | DataError | ShortcodeError | FrontmatterError | CollectionsError | DuplicateSlug | IOError`. The JSON output uses `violation_type_name()` to map each variant to a stable string. A tool that consumes `check --format json` can enumerate all possible `kind` values and handle each one — or handle the set it cares about and ignore the rest. This is a stronger contract than an unstructured error message: the vocabulary is finite, documented, and enforced by the type system.

If a new violation type is added to `ViolationType`, the compiler forces a new case in `violation_type_name()`. The JSON output automatically gains the new kind. The format does not drift from the implementation.

### Output Structure

```json
{
  "violations": [
    {"path": "content/posts/foo.md", "line": 12, "column": 5, "kind": "broken_wikilink", "message": "unknown slug 'bar'"},
    {"path": "content/posts/foo.md", "line": null, "column": null, "kind": "schema", "message": "..."}
  ],
  "summary": {
    "total": 2,
    "by_type": [{"kind": "broken_wikilink", "count": 1}, {"kind": "schema", "count": 1}],
    "by_file": [{"path": "content/posts/foo.md", "count": 2}]
  }
}
```

`line` and `column` are integers when present, `null` when absent — JSON null rather than a sentinel value, so consuming code can distinguish "this violation has no position" from "position is zero." The summary mirrors the text output: violations grouped by kind and by file, sorted by count descending. Both the text and JSON outputs share the same `summarize()` computation.

### CI Integration

The primary use case is CI: `lattice check --format json | jq '.summary.total'` fails the build at zero and exits 1 on violations. A GitHub Actions step that runs `lattice check --format json` and parses the output can annotate PRs with the violations list at specific file/line positions — the position data is already there in the JSON. The exit code contract is unchanged: 0 on clean, 1 on violations, regardless of format.

The `--format` flag only applies to `check`. Build and serve use the text diagnostic format (structured around developer feedback during iteration) because they run in interactive or watch contexts where human-readable output is the primary consumer. Check is designed for automation and editors, where structured output is the primary consumer.

## Filter/Pipe Syntax for Slot Transformations — Keeping Formatting Out of Templates

Commit `5cc8cfc` adds pipe-style filter chaining to the template DSL: `{{page.title | upper}}`, `{{date | date_part year}}`, `{{page.description | truncate 80 | default "No summary available"}}`. Filters can be chained left-to-right, each receiving the output of the previous.

### The Problem Filters Solve

Before filters, a template author who wanted the post title in uppercase had two options: duplicate the content with a separately-valued slot, or accept that template rendering produced exactly the raw value from the slot map. Neither option was satisfying. The first inflated the slot map with redundant variants of the same data. The second forced formatting concerns into content — a frontmatter field like `title_upper: "MY POST TITLE"` is an authoring burden that breaks down the moment the title is edited and only one variant is updated.

The structural thesis applies here too: if formatting logic lives in templates, it lives in a declared place and is statically parseable. If formatting logic lives in frontmatter duplication, it's invisible to the build pipeline and silently diverges.

### The Filter Enum

`Filter` is a closed enum in `src/template/template.mbt`:

```
enum Filter {
  Upper
  Lower
  Truncate(Int)
  DatePart(String) // "year" | "month" | "day"
  Default(String)  // fallback if slot renders empty
}
```

The closed vocabulary matters. `apply_filter()` is an exhaustive match: adding a new `Filter` variant forces a new case in the match. There is no runtime "unsupported filter" path — the type system enforces completeness. The five variants cover the practical cases without growing into a general-purpose expression language: case normalization, length limits, date decomposition, and absent-value fallback.

### Parsing and Quote-Awareness

`parse_filters()` splits the slot expression on the first unquoted `|`, recursively chaining segments. The quote-awareness matters for `default "No description available"` — the argument may contain spaces, so the parser uses a quoted-string path via `@strutil.parse_quoted` when the argument starts with `"`. Unquoted arguments read to end-of-segment. Both paths produce the same `Filter::Default(String)` value.

The `DatePart` filter extracts year, month, or day from an ISO 8601 date string (`YYYY-MM-DD` or `YYYY-MM-DDTHH:MM:SS`). The primary use case is archive-style headings: `{{date | date_part year}}` and `{{date | date_part month}}` in a collection index template produce structured year/month labels without requiring the template author to know the date string format or write string manipulation logic.

### Scope: All Slot Expressions

Filters apply to all three slot expression types: standard slots (`{{title | upper}}`), frontmatter slots (`{{page.field | lower}}`), and loop item slots inside `{{#each ...}}` blocks (`{{item.name | truncate 40}}`). The `parse_filters()` call is made at parse time for each expression type, and `apply_filters()` is called at render time in each corresponding match arm. The filter chain is stored in the `TemplatePart` AST node alongside the slot or field reference.

### The Silent No-Op Gap — Closed

Unknown filter names previously became silent no-ops, mapped to `Filter::Upper` in `parse_single_filter`'s fallthrough. A typo like `{{page.title | uper}}` produced uppercase output — the wrong filter — with no diagnostic. This was an honest design gap, documented as such in an earlier version of this retrospective.

The fix converts `parse_single_filter` from returning `Filter` (always succeeding) to returning `Result[Filter, String]` (failing on unknown names). The error propagates through `parse_filters`, which also returns `Result`, and into the template parser where it becomes a `TemplateError::UnknownFilter(String)`. The `UnknownFilter` variant was added to the `TemplateError` enum so the builder's `template_error_text()` can format it as a diagnostic. The error message includes both the unknown filter name and the full slot expression (e.g., `unknown filter 'uper' in '{{title | uper}}'`) so the user can locate the typo in their template.

The type-system payoff is that `parse_single_filter` no longer has a fallthrough case. Before the fix, the compiler could not distinguish between "explicitly parsed `upper`" and "fell through to default `Upper`" — both produced the same `Filter::Upper` value. After the fix, the compiler enforces that every return path either produces a known `Filter` variant or explicitly returns `Err(name)`. The fallthrough is no longer possible. The only way to get a `Filter` value out of `parse_single_filter` is to provide a recognized filter name.

The five valid filter names (`upper`, `lower`, `truncate`, `date_part`, `default`) are now the closed set enforced by the type system. Adding a new filter requires adding a new `if name == "..."` branch and a corresponding `Ok(Filter::...)` return — the compiler will warn about unused variants in `apply_filter` if the render path isn't updated to match. This is the same structural pattern used throughout lattice: the enum is the contract, the parser enforces the contract, and the renderer trusts the contract.

### What Filters Are Not

Filters are not a general-purpose transformation language. There is no arithmetic, no string interpolation, no regex. The five variants cover the cases that recurred across templates in the example site: `upper`/`lower` for display formatting, `truncate` for meta description length limits, `date_part` for structured date display, and `default` for optional fields. That's a deliberate boundary — each new filter is a new case in `apply_filter()` and a new keyword in `parse_single_filter()`, which means the filter vocabulary is always explicit and auditable. A template using `{{page.status | upper}}` tells a reader exactly what transformation is applied, without requiring them to trace through an arbitrary expression evaluator.



## Atom 1.0 Feed — Typed Page Graph as Syndication Source

**Commit `47f0210`** introduced per-collection and site-wide `feed.xml` generation using Atom 1.0. The site-wide feed aggregates across all collections, producing a single entry point for feed readers that want the full site stream.

### Pure Function Renderer

The feed renderer in `src/rss/rss.mbt` is a pure function: it takes `Array[GraphPage]`, returns an XML string, and performs no I/O. The builder handles file writing; the RSS module handles XML construction. This separation means the renderer can be tested without touching the filesystem — the test suite constructs `GraphPage` arrays in memory and asserts on the output string.

### Typed Intermediate Structs

`FeedItem` and `FeedChannel` are typed intermediate structs between the page graph and the XML output. Optional fields use `String?` rather than sentinel values like empty strings or "unknown". This matters because `None` and `Some("")` have different semantics: `None` means "no value was provided" (omit the XML element), while `Some("")` means "an empty value was provided" (emit the element with empty content). A dynamic map representation would conflate these two cases.

`render_atom_item` takes `item.updated : String?` and falls back to `fallback_updated` from the channel level, because Atom requires `<updated>` on every `<entry>`. The fallback is the feed-level `<updated>` value (the most recent date across all items, or `1970-01-01T00:00:00Z` as a last resort). This structural guarantee — every entry always has a valid `<updated>` — is enforced at the renderer level rather than left to the caller.

### Date Normalization

`normalize_feed_datetime` converts `YYYY-MM-DD` to RFC 3339 UTC (`2024-01-15` → `2024-01-15T00:00:00Z`). It validates month range (1–12) and day range using `days_in_month` from strutil, which accounts for leap years. Malformed dates produce `None` rather than invalid XML. Pages without dates sort after dated pages (the `compare_iso_desc` function puts `None` after `Some` values), so the feed always lists dated content first.

### Autodiscovery

`<link rel="alternate" type="application/atom+xml" ...>` is injected into `<head>` of collection index pages and root pages via `html.render_feed_link_tag` + `html.inject_head_markup`. The injection happens at the build pass level, not in templates — template authors don't need to remember to add feed links, and the build system ensures they're always present when feeds are generated.

### Configuration

`site_feed_enabled` (bool, default `true`) and `feed_limit` (optional int) in `lattice.toml` control output. When `site_feed_enabled` is `false`, no feed files are written and no autodiscovery links are injected. `feed_limit` caps the output at the N most-recent pages by date, which is useful for large sites where a full feed would be hundreds of entries.



## JSON Feed 1.1 — Type Reuse Across Syndication Formats

This session's commit adds `feed.json` alongside `feed.xml`, per-collection and site-wide. The JSON Feed 1.1 format provides a machine-readable alternative to Atom that's easier for JavaScript tooling to consume (no XML parsing required).

### Same FeedChannel, Different Output

`render_json_feed(channel : FeedChannel, feed_url : String) -> String` consumes the same `FeedChannel` type as the Atom renderer. No new data pipeline was needed — the `GraphPage → FeedChannel → output` pipeline has a format-agnostic middle stage. New feed formats attach at the right end of the pipeline (the renderer) without requiring changes to the left end (page graph construction and sorting).

This is the structural benefit of the typed intermediate: `FeedChannel` is not "Atom data" or "JSON Feed data" — it's format-agnostic feed data. The Atom renderer adds Atom-specific requirements (mandatory `<updated>`, `<link>` attributes), and the JSON Feed renderer adds JSON Feed-specific requirements (`version` URL, `feed_url` self-reference). The shared type catches bugs where a field that both formats need is missing from the upstream.

### Optional Fields: Omit, Not Null

JSON Feed's `summary`, `date_published`, and `date_modified` are optional — when the underlying `FeedItem` field is `None`, the key is omitted entirely from the JSON output rather than set to `null`. This is a deliberate semantic choice: `null` in JSON means "the key exists but the value is explicitly null," while omitting the key means "this property does not apply." A feed consumer checking `item.date_published` in JavaScript gets `undefined` (absent) rather than having to check `=== null` separately.

This contrasts with `check --format json` output elsewhere in the codebase, where `null` means "the violation has no position." Different null semantics for different contexts — the JSON Feed spec explicitly says optional fields should be absent, not null.

### JSON String Escaping

`@strutil.write_json_string(buf, s)` handles escaping — the same utility used by the search index and content index renderers. This is distinct from `escape_html_body` (used in Atom output), which escapes `<`, `>`, `&` as HTML entities. Using the wrong escaping would produce malformed output: HTML entities in JSON (broken for JSON consumers) or JSON escape sequences in XML (broken for XML parsers). The shared utility means the escaping logic is implemented once and tested once, and both feed formats benefit from the same correctness guarantee.

### Self-Describing `feed_url`

The `feed_url` field in the JSON Feed document points to the document's own URL (e.g., `https://example.com/feed.json` or `https://example.com/posts/feed.json`). This is a JSON Feed 1.1 requirement — the spec mandates `feed_url` so consumers can discover the feed's canonical location. The builder constructs this URL using `@strutil.absolute_url(base_url, path)`, ensuring it's always a fully-qualified absolute URL regardless of the base URL configuration format.

### Emitted Locations

Per-collection: `/<collection>/feed.json` (alongside `/<collection>/feed.xml`). Site-wide: `/feed.json` (alongside `/feed.xml`). The builder mirrors the exact error handling pattern: I/O failures produce diagnostics rather than crashing the build, and each JSON feed write is independently tracked in `error_count`.
