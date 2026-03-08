# Lattice

MoonBit SSG for the [2026 MoonBit Software Synthesis Challenge](https://www.moonbitlang.com/2026-scc).

## Challenge constraints

- Deadline: April 21, 2026
- ~10k lines of MoonBit, individual, open-sourced on GitHub
- $600 grant
- Rubric (25% each): functional completeness, engineering quality, explainability (AI tool retrospective + architectural decisions), UX

## Core thesis

An SSG where structural violations are type errors, not runtime surprises.

Typed frontmatter schemas, validated wikilinks, content collections with schema enforcement — the kind of guarantees Ametrine lacks because Astro's content layer is behavioral (runtime checks) rather than structural. MoonBit's type system makes this the right language for the story.

## Differentiation angle

Not "another SSG." The pitch is that content integrity is a structural property — broken links, schema mismatches, missing required fields should be compile-time errors. Every other SSG discovers these at build time or worse, at render time.

## Rubric alignment

- **Functional completeness**: core SSG pipeline (parse → validate → render → emit)
- **Engineering quality**: MoonBit type system doing real work, not just wrapping strings
- **Explainability**: structural-vs-behavioral lens writes the retrospective naturally — document every place a type caught a bug that a dynamic check would have missed
- **UX**: the output itself + the error messages when the structural contract is violated

## Related context

- goal/3: MoonBit ecosystem familiarity — existing research base
- goal/5: the challenge goal itself
- ~/code/ametrine: direct domain context, pain points to solve
- Reference projects from challenge page: fastcc (C compiler), wasmoon (WebAssembly runtime with JIT)

## Reference sources

- Challenge page: https://www.moonbitlang.com/2026-scc
- MoonBit docs: https://www.moonbitlang.com/docs
- MoonBit async lib: https://github.com/moonbitlang/async
