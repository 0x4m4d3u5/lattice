# Portable WASM core smoke test

MoonBit provides [first-class WebAssembly support](https://docs.moonbitlang.com/en/latest/toolchain/wasm/index.html).
Our pinned compiler runs natively; `--target wasm` and `--target wasm-gc`
generate WebAssembly applications. Compiler host and output target are independent.

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

Verified locally on Linux x86_64 with Node `26.12.1`, compiler
`v0.10.18+6c83a7f62`, and Moon CLI/Moonrun `e1e1f15`. Both generated targets pass
all five fixtures; the full warning-free JS baseline also passes. A Node worker
was tested. These fixed fixture exports remain Node-only. The separate
[supplied-note browser gate](wasm-note.md#real-browser-worker-gate) now verifies
the documented WASM GC string boundary in a real Chrome/Chromium Web Worker.

## Compiler-host regression coverage

The previous WASM-hosted compiler distribution failed this standalone probe:

```moonbit
pub fn interpolated(n : Int) -> Int {
  "n=\{n}".length()
}
```

With compiler `0.10.18+6c83a7f62` and matching core, calling the generated export
with `42` under Node 26.12.1 returns `4` for both WASM targets when compiled by the
native-hosted compiler. The WASM-hosted distribution instead traps with memory
access out of bounds (`wasm`) or oversized array allocation (`wasm-gc`). The
comparison uses identical source and runner, without host imports. Earlier emitted
WAT inspection found a huge interpolation capacity hint; the internal cause has
not been established or confirmed by upstream maintainers.

Bootstrap now selects the native-hosted compiler. `scripts/check-targets.sh`
runs the conventional WASM and WASM-GC test suites, whose test driver exercises
interpolation, in addition to these independent portable exports. The historical
host-specific failure does not mean MoonBit's WASM targets are generally broken.
See [toolchain retention and coverage](reliability-baseline.md#current-compiler-profile)
for reproducibility limits.

## Supplied-text boundary

The additive [note-rendering proof](wasm-note.md) now accepts host-supplied
strings using the documented WASM GC JavaScript string ABI. It has its own
required CI gate; these five fixed fixtures and both existing target checks
remain unchanged. The new boundary verifies arbitrary synthetic notes in a
Node worker and a separate Chrome/Chromium Web Worker gate. The conventional
target suites now run separately with the native-hosted compiler;
these worker checks continue to verify the actual browser integration.
