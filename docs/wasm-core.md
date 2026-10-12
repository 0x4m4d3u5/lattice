# Portable WASM core smoke test

MoonBit provides [first-class WebAssembly support](https://docs.moonbitlang.com/en/latest/toolchain/wasm/index.html).
Two different WASM uses matter here: our pinned compiler itself runs as WASM
through a Node wrapper; `--target wasm` and `--target wasm-gc` generate WASM
applications. A compiler running as WASM does not establish that its generated
WASM applications work.

## Verified scope

`bash scripts/check-wasm-core.sh` uses the repository's verified toolchain,
bundles core for both targets, builds `tests/wasm_core`, and executes its exports
in a Node worker. The five authored fixtures call existing public APIs:

- YAML frontmatter → wikilink extraction/resolution → exact Markdown HTML.
- Valid frontmatter and an exact missing-title schema diagnostic.
- A resolved link, a broken-link diagnostic, and exclusion of a code-span link.
- Template escaping and optional-description presence/absence.
- TOML frontmatter with Unicode string-array values and preserved body text.

The expected HTML, URLs, diagnostics and values are literals rather than output
computed by a second call to the implementation. Replacing resolved URLs with
`/wrong/` makes the rendering and link assertions fail on both targets, after
the mutation compiles with warnings denied.

The worker checks the exact export set and requires **zero host imports** before
execution. No filesystem, CLI, environment, network or Moonrun adapter is passed
to the generated modules. This is a portable-core smoke test, not certification
of the filesystem builder or the complete WASM test suite. The full JavaScript
baseline remains a separate required CI step.

Verified locally on Linux x86_64 with Node `26.10.0`, compiler
`v0.10.14+7d59c7ec9`, and Moon CLI/Moonrun `914d7da`. Both generated targets pass
all five fixtures; the full warning-free JS baseline also passes. A Node worker
was tested. Browser execution is not asserted: no browser test surface was
available in this execution environment.

## Remaining compiler limitation

The pinned compiler emits a StringBuilder capacity hint of `2147483647` for
this minimal exported function, independently of Lattice:

```moonbit
pub fn interpolated(n : Int) -> Int {
  "n=\{n}".length()
}
```

Calling `interpolated(42)` directly through Node's WebAssembly API traps on
`wasm` (`RuntimeError: unreachable`) and `wasm-gc` (array allocation too large),
in both debug and release builds. There are no module imports or test driver in
that reproduction. Concatenation and an explicit StringBuilder return the
expected length 4 on both targets; interpolation also returns 4 on JS. The
generated WAT places the large hint at the interpolation's constructor call.

The broad `moon test` driver uses interpolation before running assertions, so
all 103 selected strutil tests trap in that driver on both WASM targets. The
official [v0.10.15+943464bfa WASM compiler archive](https://github.com/moonbitlang/moonbit-compiler/releases/tag/v0.10.15%2B943464bfa),
released 2026-10-12, was also checked in isolation with its bundled core: the
minimal `wasm` interpolation still traps. Its archive SHA-256 matched GitHub's
published digest `907644982d00b1db3a4d882626c448987f383b9faebe873d605a92cc78c14625`.
No compiler/core patch, compiler upgrade or Lattice interpolation rewrite is
part of this smoke gate.

AI-assisted diagnosis separated compiler host, generated target, core,
Moonrun/test driver and a direct Node host. Small control functions and emitted
WAT established the interpolation failure; independent site literals and the
wrong-URL mutation established sensitivity of the portable-core fixtures.

## Supplied-text boundary

The additive [note-rendering proof](wasm-note.md) now accepts host-supplied
strings using the documented WASM GC JavaScript string ABI. It has its own
required CI gate; these five fixed fixtures and both existing target checks
remain unchanged. The new boundary verifies arbitrary synthetic notes in a
Node worker. Browser execution and full WASM-suite certification remain open;
the latter still requires fixing compiler interpolation lowering and rerunning
the normal test harness.
