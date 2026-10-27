# Reliability baseline — 2026-10-08

Base: `9b92727962a61cbd45020afe97fbce5553aa9e33` (remote HEAD at checkout).
The final patch has a passing baseline on a fresh isolated Mac copy, with no
previous `_build`, `.mooncakes`, or synthetic test outputs. No real vault was processed.

## Current supported JavaScript profile — 2026-10-26

Node is pinned to the [26.12.1 security release](https://nodejs.org/en/blog/release/v26.12.1),
which fixes CVE-2026-111497 among other vulnerabilities. The workflow, installer,
cache verifier and cache key all require this version; older Node versions are
rejected even when reusing an existing Moon toolchain.

Repository setup lives in `scripts/install-ci-toolchain.sh`; CI invokes that same
installer. It downloads and verifies official archives, installs the durable WASM
compiler release and **the open-source Moon CLI and Moonrun** from the Linux archive, and
bundles core for JavaScript. It never extracts or executes the expiring native
compiler. JavaScript tests run through Node. No Rust compilation is needed. The CLI eagerly
resolves `moonrun` even for JS commands, so its official bundled runtime is retained
and checksum-verified; JS tests do not execute it. There is no separate
prebuilt installer or workflow-specific toolchain setup path.

- Compiler: `v0.10.14+7d59c7ec9`, official tagged WASM distribution, including core.
- Moon CLI: `914d7da08562120ae4d9ef181cdda58c4ff0c191`, official Linux x86_64 binary.
  Its SHA-256 is `6da4919f45f4abf7c6d7f3cf8d9a457de77dca430d6fb811d21b27ae1ac8e11d`.
- Host: Linux x86_64; Node: `26.12.1`. No Rust toolchain is required.
- Dependencies: `moonbitlang/x 0.5.5` and the local MIT-licensed `clap 0.2.6`
  compatibility copy. `moon.work` selects the vendored module; the registry copy
  is not substituted for it.

| Official input | Verified SHA-256 |
| --- | --- |
| Tagged `moonbit-wasm.tar.gz`, compiler and core | `3c5d21564b0e8bbfcfda95d374eda90427f6a5e238ce4639b711b69f43391f62` |
| Linux archive, extracting `bin/moon` and `bin/moonrun` | `9226694de9ff978db1ecf820b7710c4224e84ec7a76b19a222d96f0cd4e31b6a` |

[Compiler release](https://github.com/moonbitlang/moonbit-compiler/releases/tag/v0.10.14%2B7d59c7ec9),
[official installer distribution paths](https://cli.moonbitlang.com/install/unix.sh),
and [Moon CLI source revision](https://github.com/moonbitlang/moon/tree/914d7da08562120ae4d9ef181cdda58c4ff0c191).
The compiler archive records SDK Moon revision `760759ca`; the independently
pinned prebuilt CLI revision above is the tested profile. The earlier baseline
rebuilt that SDK revision from Rust on every job. It is retained as historical
evidence below, not as a second installer path.

Archives are checked before extraction. Installation uses a temporary sibling
and promotes only after verification and bundling succeed. An existing valid
installation is reused; an invalid one is rejected without overwriting it.
`scripts/verify-ci-toolchain.sh` checks the installed CLI/runtime pair, compiler wrappers,
WASM assets and expected versions, including on cache hits. CI's exact cache key
includes OS, architecture, Node version and both setup scripts. A cache miss
runs the same installer; it never silently upgrades to a different version.
Upstream download availability remains an external dependency; absence or a
checksum change fails visibly.

The original October 11 local installation took 12.6 seconds; reuse took 0.37 seconds. The earlier
hosted source installation took 309 seconds, of which Rust compilation took 278
seconds. Hosted results for this profile are recorded on the cleanup PR.

## Reproduce

With Node `26.12.1`, curl, tar and the standard Linux utilities available:

```bash
export MOON_HOME="$PWD/.ci-moon"
bash scripts/install-ci-toolchain.sh
export PATH="$MOON_HOME/bin:$PATH"
moon update
bash scripts/check-baseline.sh
```

Every compiler gate treats warnings as errors, runs independently and preserves
failure status:

```bash
moon check --target js --deny-warn
moon test --target js --deny-warn
moon build --target js --deny-warn
moon -C vendor/clap test --target js --deny-warn -p TheWaWaR/clap
```

Workspace testing includes Lattice and all 16 vendored clap tests. The final gate
also selects clap explicitly; changing working directory alone does not restrict
workspace test selection. Deprecated syntax is no longer disabled in the module
configuration. The 2026-10-11 cleanup fixes the underlying APIs and declarations,
including vendored code. Display compatibility tests preserve 89 pre-migration
public strings and asset-validation formatting; two parser-choice diagnostic strings, and CLI stdout, stderr and exit codes
were compared against the previous implementation using seven synthetic commands.

## Historical baseline results and backend limitation

A fresh isolated Mac copy, without prior build/dependency caches or generated test
fixtures, passed all four JavaScript commands using the durable distribution:
1,262 project tests and 15 vendored clap tests (13 upstream plus two regressions).
Check and build passed with zero errors and existing warnings. Only synthetic
fixtures were processed. `bash -n scripts/*.sh` and `git diff --check` also passed.
Hosted Linux results are reported on the draft PR rather than asserted here.

The native compiler snapshot of the same compiler version independently passed
all 1,262 project tests and 15 clap tests with default WebAssembly targeting.
Fresh native check reported 2,244 warnings and build reported 288; counts vary with
rebuilt packages. The official native archives advertise expiration on November
20, 2026. The initial baseline therefore chose source installation. The current profile
uses the durable WASM compiler and extracts only the non-expiring open-source
Moon CLI from the verified archive; the expiring native compiler is excluded.

**The tagged WASM compiler distribution does not pass the WebAssembly baseline.**
Its wasm/wasm-gc output generated an interpolation StringBuilder size hint of
`2147483647`, causing allocator traps before assertions. This was reproduced on
Node 26 and Node 22 with fresh bundled core; the same source passes on JavaScript
and with the native compiler. CI's explicit JavaScript backend establishes a
reproducible source/behavior baseline; it does not certify WebAssembly compilation
by this distribution. A full-suite backend gate requires an upstream compiler fix or
a durable native compiler distribution. The separate [portable core smoke gate](wasm-core.md)
executes five real parser/validation/rendering fixtures on both generated WASM
targets without that test driver; it does not certify the filesystem CLI or
general interpolation.

Before the compatibility fixes, the native compiler with original dependencies
failed check with 98 errors and build with 83 errors. The full test run could not
compile. Individual package runs executed 1,174 tests with one highlighter snapshot
failure; three test packages lacked `Debug` implementations. Existing warnings are
mainly deprecated APIs, implicit imports and unqualified package references.

## Narrow compatibility changes

- Upgrade `moonbitlang/x 0.4.40` to published `0.5.5`, resolving rejected syntax in
  the time package. Copy its `read_dir` result from `ArrayView` to an owned array
  before sorting in the watcher; ordering behavior is preserved.
- Vendor `clap 0.2.6`: upstream has no newer published compatibility release and
  still uses removed `strconv` APIs. Use the current string parsing APIs and builtin
  `Map`, retaining parser algorithms and help text. See
  [the complete upstream delta](../vendor/clap/compatibility.patch) and
  [provenance](../vendor/clap/COMPATIBILITY.md).
- Derive `Debug` for types used in current assertions. Compare Rust highlighter
  tokens directly to the same expected token sequence instead of comparing `Show`
  formatting; no tokenizer implementation or snapshot expectation was weakened.
- Exercise signed/unsigned numeric boundaries and retain `InvalidArgumentValue`
  wrapping for overflow/negative unsigned input in the vendored parser.

## Validation behavior recorded by the original baseline

- Broken wikilinks produce violations in `check`, which emits no page and leaves
  seeded output intact.
- Broken wikilinks produce warning diagnostics in `build`, which still emits the page.
- A missing required schema field makes a build fail, but another valid page is
  replaced with new output and the invalid page's seeded previous output remains.

These use synthetic content under repository-local `_tmp_*` directories. They
recorded the pre-gate behavior. The 2026-10-10 [publication gate](build-safety.md)
replaces the partial-output regression with last-successful-output preservation.
The vault exclusion helper is not called by the builder; it is not a publication policy.

## Original next-milestone proposal

The original proposal was: after the draft PR baseline is green, give `check` and `build`
one shared validation result with an explicit broken-link severity policy. Validate
the entire site before rendering; render into a sibling staging directory and promote
only after all writes succeed. Preserve last-good output and cache on validation or
I/O failure, with synthetic two-page and write-failure regressions first.

No pipeline redesign, real vault processing, storage migration, or publishing feature
was added. No pipeline promotion, release or deployment is part of this milestone.

The implemented 2026-10-10 milestone uses a portable in-memory output plan.
It protects validation/generation failures and preflights destination types,
but does not claim atomic directory promotion or recovery from publication I/O
failures. The pinned filesystem API lacks rename; [build safety](build-safety.md)
documents that narrower, tested contract.
