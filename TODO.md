# TODO: Lattice as a publishable vault *and* agent memory

Research notes. Started 2026-11-07; revised 2026-11-15 against `origin/main`
at `b49be8e` (#174). This is a direction, not a committed plan.

## The idea in one paragraph

One Markdown vault serves two audiences: a published site and the memory an
agent reads from. Elsewhere the private/public line is enforced
*behaviorally* (a filter plugin, a truthy-ish frontmatter flag, a curated
copy). Lattice's thesis is that integrity properties are *structural*: **one
corpus, two audiences, and a publication boundary the build checks for you.**
Lattice should be the type checker for agent memory, not the database. Agents
already write Markdown with ordinary file tools. The weak step in that loop is
lint.

## Where things stand (2026-11-15)

The boundary machinery has landed. Every PR below was tested on synthetic
fixtures only. **Nothing has been run against a real vault yet**, and that is
now the main source of risk.

Done:

- [x] `visibility: public | private` is the single source-selection field. Typed
      and duplicate-checked, it fails closed (#166, `docs/publication-visibility.md`).
      `draft` stays readiness-only; `type: private` / `publish` are not reinterpreted.
- [x] Default builds reject private declarations (#166).
- [x] Explicit static allowlist; references never widen it (#167).
- [x] Fresh, isolated output without deleting old releases (#168).
- [x] `--audience public`: early source projection before aliases, tags,
      backlinks, graph and indexes are derived; cross-boundary wikilinks, local
      links, images and typed refs are errors (#169, `docs/public-audience.md`).
- [x] Body-only Markdown ingestion opt-in (#171), piped CLI output (#172),
      watch retention (#170).
- [x] Authored evidence context: `date`/`updated`, opt-in `observed_at`,
      `valid_from`, `valid_until` (DateTime) and `supersedes` (Ref), plus derived
      `superseded_by`. Never used for ranking or truth (#173).
- [x] `--audience private`: explicit plaintext memory export with required
      `-o`, fresh output, allowlist and content index (#174, `docs/private-audience.md`).
- [x] Strict citation verification, passage retention, publication pairing
      (#162–#164).

Decided by those PRs (previously open questions):

- One field, not `type: private` implying anything. `@vault.should_exclude_from_index`
      is now explicitly documented as organizational-only (not a publication/visibility boundary).
- Missing visibility is publishable in default mode and excluded in
      `--audience public`. No vault-level `default_visibility`.

## Next steps, in order

### 0. Fix the three review findings (landed in #175–#177)

Found by reproducing on a synthetic vault with the native CLI at `b49be8e`.

- [x] **Private export inherits the public `base_url` and crawler output.** (`aabfdaa`, #175)
      Requires loopback/local `base_url`, skips robots/sitemap/feeds, and refuses destinations inside the configured `output_dir`.
- [x] **Nested folders are silently dropped.** (`aaa4193`, #176)
      Reports uninspected child directories under configured source roots as `private_source_coverage` warnings.
- [x] **A citation to a superseded page can still come back `ready`.** (`ec3b49f`, #177)
      Surfaces the selected page's authored `context` (including `superseded_by`) alongside `citation` at the top level.

### 0.5. Codebase audit & hardening (2026-11-22)

- [x] **Harden `src/serve/serve_native.c`**: anchor `resolve_path` to leading `/` (fixing prefix-confusion traversal), reject backslashes/NULs/`snprintf` truncation, fix unanchored `..` handling, enforce `realpath()` containment on Unix, ignore `SIGPIPE`, loop `sock_write` in `send_file`, and remove redundant condition.
- [x] **Fix HTML attribute escaping in `src/markdown/markdown.mbt`**: use `@strutil.escape_html_attr` instead of `escape_html_body` for footnote `id`/`href` and callout `class` attributes.
- [x] **Fix UTF-16 handling in `@strutil.substr` and `TString`**: make `@strutil.substr` slice directly instead of looping UTF-16 code units through `unsafe_to_char()`, and make `TString(minlen, maxlen)` count Unicode scalar values with safe error-preview truncation.
- [x] **Tighten `TUrl` schema validation in `src/schema/schema.mbt`**: reject bare `http://`/`https://`, protocol-relative `//...`, and whitespace/control characters.
- [x] **Clean up `src/vault/vault.mbt`**: preserve literal hyphens in `category_class` (`"in-progress"` → `"in-progress"`) and explicitly document `should_exclude_from_index` as organizational-only (not a publication/visibility boundary).
- [x] **Remove residual `@strutil` helper duplication**: replace local `trim_ws`, `split_lines*`, and `starts_with_collections` in `frontmatter.mbt`, `collections.mbt`, `config.mbt`, and `data.mbt`.
- [x] **Fix native unused-package warning in `src/watch/`**: move `current_unix_second` / `current_millis` / `today_ymd` to shared `watch.mbt` using `@env.now()` so `moon check --target native --deny-warn` is clean.
- [x] **Clean & update docs**: deduplicate `ISSUES.md` and refresh `README.md` project stats.

### 1. Real-vault compatibility pass

Run `check` and `inventory` against a **local copy** of a real vault (never the
original; nothing leaves the machine). Turn every failure into a small synthetic
fixture. The deliverable is a support table: supported / rejected with a clear
error / **silently wrong**. Only the last category is urgent.

- [ ] Known from code: non-recursive discovery. `vault.toml` lists PARA top-level
      folders only, so `10 - Projects/<project>/*.md` disappears (see step 0).
- [ ] Known from code: one flat slug namespace across collections. Two
      `README.md` / `index.md` files in different folders are a hard
      duplicate-slug error. Obsidian resolves these by shortest unique path.
- [ ] To verify: `[[folder/note]]` path links, `![[note]]` transclusions,
      `![[image.png|300]]` sizing, block refs `[[note#^id]]`, heading links with
      punctuation, links that rely on Obsidian's case-insensitive matching,
      unquoted YAML dates, `tags:` as a string vs a list, and filenames containing
      `#`, `%`, `?` or `.` (the slugifier passes most ASCII punctuation through).
- [ ] Record what fraction of a real vault builds cleanly with the minimal
      `Optional[...]` schema in `vault.collections.cfg`.

### 2. Retrieval benchmark before any retrieval feature

- [ ] 30–50 questions over the real vault, each labelled with the expected page
      and section, or "should abstain". Cover paraphrases, renamed notes,
      corrected/superseded facts, and facts that exist only in uncollected or
      draft notes.
- [ ] Score the current lexical + abstention host on: correct ready, correct
      abstain, wrong ready (the dangerous one), needless abstain.
- [ ] Baseline: QMD over the same Markdown. If hybrid search wins clearly on
      paraphrase, prefer interop (emit what QMD ingests) over embeddings in MoonBit.
- [ ] Keep the question set and labels local (they describe private content).
      Only aggregate numbers and synthetic reproductions go in the repo.
- [ ] Guardrail: authored metadata (`supersedes`, dates) may *annotate* results
      but must not change ranking or the abstention decision without a separate,
      explicitly opt-in policy.

### 3. `lattice check` as the lint step for agent-written vaults

- [ ] Audit `check --format json` for what an agent fix-loop needs: stable codes,
      file and line, and a one-line fix hint per diagnostic.
- [ ] Add only rules that step 1 shows are needed. Likely: uncollected Markdown,
      orphan notes, alias/title collisions, `supersedes` cycles or self-references
      (as warnings, not truth checks). Out of scope: contradiction detection.
- [ ] Try one loop end to end: an agent edits a vault copy, runs `check`, and
      fixes until clean. Note where the diagnostics were insufficient.

### 4. Decide the shape of the private memory export

- [ ] Should private export be a narrow profile (content index plus only the HTML
      that citation validation needs, with no feeds, sitemap, robots, tags or
      graph)? That removes step 0's first finding by design, at the cost of
      generality.
- [ ] Local-origin story for citation validation: a trusted loopback-only server.
      Loopback is not a network sandbox (`docs/private-audience.md`).

### 5. Later, only if steps 1–4 earn it

- [ ] A thin read-only MCP server (search / read passage / follow links /
      inventory) over the content index. The selling point is cited passages plus
      abstention, not storage.
- [ ] An agent write path: probably not a Lattice API. Agents write files and
      Lattice validates. If one is added, use optimistic concurrency on a
      source revision.
- [ ] `kind: fact | inference` or `confidence` fields, only if the benchmark
      shows a need. Same rules as #173: schema-validated, never ranking.

## Open questions

- Is it a leak if a public page's link *label* names a private note? Current
      answer: the reference is an error. Confirm that labels on external links
      are also out of scope (`docs/public-audience.md` says the builder can't judge them).
- Does a private memory view make people more comfortable putting secrets in a
      vault that also publishes? Step 0 should land before private export is promoted.
- CLAUDE.md still frames work around the April 2026 challenge rubric. Update it
      to the current goal so agents stop optimizing for that rubric.

## Non-goals

- Not a vector DB bolted onto a blog.
- Not an Obsidian Sync replacement or plugin.
- Not deciding truth. Lattice shows where a claim came from, not whether it's
  correct or current.
- Not access control or encryption. Private export is plaintext.

## Landscape (web-sourced, not independently verified)

- **Basic Memory**: Markdown as the source of truth, a rebuildable SQLite index,
  an entity/observation/relation graph, and MCP tools. The closest precedent for
  the memory side. <https://github.com/basicmachines-co/basic-memory>
- **QMD** (Tobi Lütke): local hybrid search (BM25 + vectors + LLM rerank) over
  Markdown with MCP. Retrieval only, with 1–2 GB of models.
  <https://github.com/tobi/qmd>
- **Obsidian Headless**: the official Sync client without the app, pitched for
  agent vault access. It only moves files. <https://help.obsidian.md/headless>
- **Karpathy's LLM Wiki** (April 2026): an Ingest / Query / Lint loop, with the
  agent maintaining Markdown.
  <https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f>
- **Anthropic memory tool**: a client-owned `/memories` directory.
  <https://platform.claude.com/docs/en/agents-and-tools/tool-use/memory-tool>
- **Commonplace review of 129 agent memory systems**: faithfulness testing is
  nearly absent, which supports leading with provenance.
  <https://zby.github.io/commonplace/agent-memory-systems/agentic-memory-systems-comparative-review/>
- **Quartz `ExplicitPublish`**: a behavioral `publish: true` filter. It once
  shipped a `"false"`-is-truthy bug, and it still emits every non-Markdown file.
  <https://quartz.jzhao.xyz/features/private-pages>
