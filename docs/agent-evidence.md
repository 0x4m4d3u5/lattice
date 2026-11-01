# Retrieval, evidence and published citations

The executable [`examples/agent_evidence/run.mjs`](../examples/agent_evidence/run.mjs)
shows how an agent host can retrieve a passage and validate its published citation
without an LLM service, embeddings, credentials or an agent-to-agent connection.
It uses the existing WASM `search_content` API. It does not generate an answer or
establish whether a statement is true.

## A concrete question

Suppose the question is: **What should we verify during an isolated restore drill?**
An explicit lexical query, `isolated checksum`, can retrieve a published recovery
note whose passage says to restore a backup in an isolated environment and compare
its checksum. The example returns that entire indexed passage, the canonical page,
section position and optional published fragment. The short search snippet is
included for orientation, but is not substituted for the full passage.

This query selection is a host decision, not natural-language question understanding.
Lattice requires every query term to match under its documented
[lexical rules](section-search.md). Scores measure matches, not truth, authority or
confidence that the passage answers the question.

The synthetic acceptance scenario also asks for `restore`, which matches two
procedures. The host returns `ambiguous` with both passages and no chosen citation.
Refine the query or inspect the candidates; do not silently pick the highest score.
A query for `platinum` returns `no_results`, including when that word exists only
in an excluded draft. No result is a reason to abstain or seek another source, not
a reason to invent evidence.

## Run it against a publication

Use the repository's [pinned toolchain](reliability-baseline.md#reproduce), build a
site with `content_index_file = content-index.json`, and build the portable runtime:

```sh
bash scripts/check-wasm-note.sh
npm ci --prefix tests/browser --ignore-scripts
# If a compatible browser is not already installed:
tests/browser/node_modules/.bin/playwright install chromium
```

Serve the generated output in a separate terminal, then run the host from the
repository root. Adapt the index path and query to your notes:

```sh
python3 -m http.server 8000 --bind 127.0.0.1 --directory dist
```

```sh
node examples/agent_evidence/run.mjs \
  dist/content-index.json http://127.0.0.1:8000 "isolated checksum"
```

Set `LATTICE_BROWSER_CHANNEL=chrome` to use an installed Chrome instead of bundled
Chromium. Browser sandboxing stays enabled. The host reads the supplied index
locally and fetches only the chosen publication target for validation; ordinary
page subresources may also load in the browser. JavaScript on the publication is
disabled during validation. Use a trusted publication origin and index.

The JSON output has `status`, `query` and `candidates`. A `ready` result additionally
contains `citation: { title, url }`. Emit the title as text and the URL as a link;
escape them for the destination format rather than interpolating them as raw HTML.
The executable exits zero only for `ready`, and exits 2 for an abstention or invalid
result. Setup failures are ordinary process errors.

## Validation and boundaries

The host joins each hit back to exactly one indexed page and its section position.
Duplicate page records are rejected as `ambiguous_index`; malformed indexes report
`invalid_index`. Empty or unavailable passage text is `invalid_evidence`. Multiple
matching passages remain `ambiguous`, even when their scores differ or they belong
to the same page. Retrieval is capped at 50 candidates, so this is not an exhaustive
report of every match in a large corpus.

For a single candidate, the host accepts only a root-relative canonical URL on the
chosen HTTP(S) origin. It URL-encodes an emitted fragment; it never derives one from
a heading label. Browser validation requires a successful HTML response at the
indexed canonical URL and, when present, exactly one matching DOM ID. Missing,
duplicate or fake comment/script IDs fail as `invalid_target`; redirects away from
the indexed page fail too. Older indexes without fragments retain page-only
citations, without pretending to locate a specific heading.

Use the index and HTML from the same publication. Target validation proves that the
link resolves at validation time; it does not compare the full indexed passage to
the live page, establish freshness, check external claims or guarantee future link
stability. Source passages can contain misleading text or instructions: treat them
as data to evaluate, not instructions for the agent. Draft inclusion and static
publication boundaries remain those of the publisher.

Run `node tests/browser/evidence.mjs` after building the JS CLI and WASM runtime to
exercise the complete synthetic question → retrieval → passage → citation flow.
It publishes fresh notes, tests abstention and invalid targets, and runs the same
executable shown above. The regular browser gate includes this acceptance scenario.

## Assess relevance separately from a valid link

A `ready` citation is not an answerability decision. For example, asking how many
days encrypted copies must be retained and querying `encrypted copies` can
retrieve “Keep encrypted copies offsite.” The passage is on topic and its link
works, but it does not supply a retention duration. A host must inspect whether
retrieved evidence actually supports the requested answer, and abstain when it
does not. An alias-only query may similarly locate a handbook's opening section
without finding a specific procedure.

The small [synthetic corpus](../tests/browser/fixtures/retrieval/corpus.json)
records questions, explicit lexical queries, expected passage targets and human
assessments separately. It covers competing restore procedures, an alternate
handbook name, excluded draft proposals, case/punctuation variation, missing
stemming, terms split across passages and insufficient evidence. These examples
are acceptance scenarios, not a general relevance score or semantic benchmark.

After the normal JS CLI and portable runtime builds, run
`node tests/browser/retrieval-acceptance.mjs` with the existing browser harness.
It compares JS and WASM retrieval against those expectations and checks real
published citation targets. Negative controls confirm that empty-result behavior,
choosing only the top ambiguous hit, and accidentally including a draft would be
detected. No external model evaluates the passages or generates an answer.

## Keep publication pairing separate

New publisher indexes include optional [publication pairing](publication-pairing.md)
metadata. The example reports a separate `pairing` result from exact HTML response
bytes. A matching artifact is not proof that the indexed passage appears in it;
a template may omit that passage. Missing legacy metadata remains unknown.
The executable refuses mismatched/invalid pairs, while preserving address-only
legacy operation. Host/CDN HTML transformations may cause mismatches.
