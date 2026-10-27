# Repair unresolved wikilinks

`lattice check` can append nearby valid targets to a `broken_wikilink` diagnostic:

```text
notes/author.md:4:1: broken_wikilink: [[guid]]: target 'guid' not found in page index; Nearby valid targets (choose the intended page): [[guide]]
```

Choose the intended page and edit the source yourself, then run `check` again.
Nothing is rewritten. `check --format json` includes the same advice in the
existing `message` field; kind, path, line/column, summary and exit-status behavior
are unchanged. Aliased links with whitespace now retain their source location.
`lattice explain E004` describes this advice and published-fragment failures.

## What qualifies

Suggestions use the existing resolver's normalization (including `.md`, case and
accent handling), then allow one insertion, deletion or substitution in the page
key. Normalized queries must be 4–80 UTF-16 code units long; candidate keys are
limited to 80. This is deliberately a small typo aid, not a search engine.

The complete shared build preparation must succeed. A suggested page must own its
final planned HTML output, or be a valid generated collection-directory alias.
Excluded drafts, static overwrites, pages overwritten by other authored/generated
outputs, and incomplete plans are not recommended. `--drafts` permits draft pages
using normal build policy. Duplicate-slug errors suppress advice rather than
choosing an owner. Existing stale output is never used as evidence.

The suggested spelling must parse and resolve with the existing wikilink parser.
Display labels are retained: `[[Guidee.md|manual]]` can suggest `[[guide|manual]]`.
A supplied fragment is retained only when its resolved anchor exists uniquely in
the final HTML, including custom template output. For example,
`[[guid#Setup|setup]]` may suggest `[[guide#Setup|setup]]`. Removed headings,
duplicate IDs, and fake IDs in comments/scripts do not justify a suggestion.

All valid one-edit choices are shown in lexical order when there are at most
three. If there are more, no arbitrary shortlist is offered. Multiple choices
are equally plausible spellings, not ranked judgments about the author's intent.

## Limits

This advice handles unresolved **page targets in wikilinks**. It does not correct
heading typos on resolved pages or same-page links, ordinary Markdown URLs,
shortcode references, titles unrelated to a page key, or multi-edit renames.
Excluded source documents receive no suggestions. No advice is not proof that
there is no useful target: consult `lattice inventory`, inspect the intended page
and its published headings, or use the site's search.

Build warnings, rendering, publication policy and supported runtimes are
unchanged. Advice is a read-only snapshot of the prepared plan, not a guarantee
that future filesystem writes will succeed or a privacy boundary.
