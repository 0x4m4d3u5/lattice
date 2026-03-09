# lattice SCC 2026 Retrospective

## Central Design Decision

The core architectural choice was to represent pipeline contracts with ADTs and typed error variants, not ad-hoc string checks.

Examples:

- Frontmatter values are an ADT (`src/frontmatter/frontmatter.mbt`): `FStr | FInt | FBool | FArray | FMap`.
- Schema constraints are an ADT (`src/schema/schema.mbt`): `TString | TInt | TBool | TArray | TOptional`.
- Pipeline violations are typed (`src/lint/lint.mbt`): `SchemaError | BrokenWikilink | TemplateSlotError | DataError | ...`.

This made each stage explicit about accepted inputs and failure modes. The builder then composes those typed outcomes into one lint/build result rather than propagating ambiguous strings.

## Concrete Type-System Wins

These are cases where dynamic SSG behavior typically degrades into silent or late failures, but lattice fails structurally during check/build.

1. Frontmatter shape/type mismatches fail before rendering.
- Evidence: `@schema.validate` checks declared fields against `FieldType` in `src/schema/schema.mbt`.
- Outcome: if a field declared as `Array[String]` is provided as scalar or mixed array, it is emitted as `ValidationError` before HTML generation.
- Dynamic failure avoided: malformed metadata leaking into templates/search pages as empty or coerced strings.

2. Broken wikilinks are resolved against a complete index, not rendered optimistically.
- Evidence: `src/wikilink/wikilink.mbt` returns `(Array[ResolvedWikilink], Array[ResolutionError])`; unresolved targets are explicit errors.
- Builder integration: check mode maps these to `ViolationType::BrokenWikilink` (`src/builder/builder.mbt`).
- Dynamic failure avoided: shipping dead anchors/404s discovered only after deployment.

3. Template slot contracts are enumerated, not free-form.
- Evidence: `TemplateSlot` and `TemplateError` in `src/template/template.mbt`.
- Unknown placeholders fail as `UnknownSlot`; missing required slots fail as `MissingRequiredSlot`; missing data paths fail as `MissingDataSlot`.
- Test evidence: `src/template/template_test.mbt` asserts `MissingDataSlot("data.nav.title")`.
- Dynamic failure avoided: typoed placeholders rendering empty output with no hard failure.

4. Data-file schema requirements are enforced at load time.
- Evidence: `DataError::ValidationError` in `src/data/data.mbt`; schema-required keys are validated in `load_from_dir`.
- Test evidence: `src/data/data_test.mbt` catches missing `links` key as `ValidationError(file="nav", key="links", ...)`.
- Dynamic failure avoided: partial nav/footer/template data causing nil/empty output at render time.

5. Collection configuration is typed and rejects invalid schema declarations.
- Evidence: `CollectionsError` in `src/collections/collections.mbt` (`InvalidSchema`, `MissingRequiredField`, `DuplicateCollection`, etc.).
- Outcome: malformed collection definitions fail during config ingestion, not mid-build.
- Dynamic failure avoided: pages silently excluded or routed under unintended collections.

6. Error composition remains structured through lint output.
- Evidence: `ViolationType` ADT in `src/lint/lint.mbt` and staged mapping in `src/builder/builder.mbt`.
- Outcome: check mode can aggregate heterogeneous failures deterministically with path/line metadata.
- Dynamic failure avoided: mixed plain-text errors that cannot be categorized or automated.

## Tradeoffs

1. Sync-first pipeline.
- Current implementation is fully synchronous (single-process, sequential passes in `src/builder/builder.mbt`).
- Rationale: stability and deterministic diagnostics over early concurrency complexity.
- Constraint: MoonBit async integration is deferred; `moon.mod.json` currently depends only on `moonbitlang/x`.

2. No watch mode.
- Current CLI supports build and check (`cmd/main/main.mbt`) but no incremental/watch process.
- Rationale: SCC scope prioritized structural correctness and complete pipeline behavior before UX iteration tooling.

3. Syntax highlight coverage limited to five language families.
- `src/highlight/highlight.mbt` supports: `moonbit`/`mbt`, `typescript` (incl. `js`/`ts` aliases), `python` (`py`), and `bash` (`sh`/`shell`/`zsh`), plus plain fallback.
- Rationale: explicit tokenizers with predictable behavior; avoid broad but weak heuristics.

## MoonBit-Specific Learnings

1. `s[i]` returns `UInt16`, not `Char`.
- This required explicit helpers (`to_int().unsafe_to_char()`) across parsers (`frontmatter`, `markdown`, `template`, `wikilink`, etc.) for character logic to type-check.

2. `StringBuilder` is the practical text assembly primitive.
- Most parsing/rendering code uses `StringBuilder` for deterministic append-heavy flows; this kept parsers straightforward without intermediate string churn.

3. `pub` vs `pub(all)` needs deliberate API boundaries.
- Internal/shared ADTs are often `pub(all)` while externally consumed surfaces are `pub`; this reduced accidental cross-module coupling.

4. Struct literals are a major readability lever.
- Explicit field literals in pipeline records (`BuildConfig`, `GraphPage`, lint violations) made refactors safer and constructor call sites self-describing.

## AI Collaboration Pattern

Work was broken into bounded work items (parser, schema validation, template contracts, link validation, check-mode diagnostics). The agent (Codex) was directed to complete each item with typed boundaries, then verify with focused tests.

Because module contracts were ADT-based, prompts and implementation steps stayed predictable: each task specified exact input/output types and explicit error variants. That reduced back-and-forth over edge cases compared with stringly-typed flows.

## What Structural Enforcement Bought

Each core module defines an ADT (or typed struct) for its failure space:

- config: `ConfigError`
- collections: `CollectionsError`
- data: `DataError`
- template: `TemplateError`
- shortcode: `ShortcodeError`
- lint aggregation: `ViolationType`
- link resolution: `ResolutionError`

As a result, pipeline composition in builder/check is mostly type-directed translation between error domains, not text parsing of error strings. That improves reliability, debuggability, and explainability for SCC engineering-quality evaluation.
