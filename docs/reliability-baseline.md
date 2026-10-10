# Reliability baseline — 2026-10-08

Base: `9b92727962a61cbd45020afe97fbce5553aa9e33` (remote HEAD at checkout).
The final patch has a passing baseline on a fresh isolated Mac copy, with no
previous `_build`, `.mooncakes`, or synthetic test outputs. No real vault was processed.

## Tested toolchain and dependencies

CI uses the official tagged WASM compiler distribution with the matching Moon
source commit, and explicitly tests the JavaScript backend. It does not depend on
the native binary service's 60-day retention window.

- Compiler: `v0.10.14+7d59c7ec9`
- Moon source: `760759ca67539dd6b6ea59b1eba57731b3ef674a`, as recorded in the compiler archive
- Node: `26.10.0`; Rust: `1.99.0`; Cargo dependencies resolved with `--locked`
- `moonbitlang/x`: registry version `0.5.5`
- `TheWaWaR/clap`: local MIT-licensed `0.2.6` source with a narrow compatibility patch

[Official compiler release](https://github.com/moonbitlang/moonbit-compiler/releases/tag/v0.10.14%2B7d59c7ec9)
and [matching Moon source](https://github.com/moonbitlang/moon/tree/760759ca67539dd6b6ea59b1eba57731b3ef674a).
The compiler archive includes core. `scripts/install-ci-toolchain.sh` verifies its
SHA-256 and bundled Moon commit before building `moon` and `moonrun` from source.
Moon's version includes the build date; the baseline verifies its commit rather
than requiring a fixed build date. The compiler version is checked exactly.

| Input | Verified SHA-256 |
| --- | --- |
| Official tagged `moonbit-wasm.tar.gz` | `3c5d21564b0e8bbfcfda95d374eda90427f6a5e238ce4639b711b69f43391f62` |
| `moonbitlang/x 0.5.5` registry zip | `eb7ddddea2c871ac823d210c4a9fdf5efc75d2c1fe9965292760669f15041dc4` |
| `TheWaWaR/clap 0.2.6` registry zip | `3cd182293d37bd4ef12bfe5edc845b77b204c910f221bdf0b51ba3e85e6f62e2` |

The dependency hashes record the locally tested registry inputs; the installer
actively verifies the compiler archive hash. Dependency versions are pinned and
clap source is included. The installer requires a fresh `MOON_HOME`, uses task-local
Cargo directories by default, and does not edit shell startup files. CI installs
Rust in its disposable runner and uses pinned checkout/setup-node action commits.

## Reproduce

With Node `26.10.0`, Rust `1.99.0`, Cargo, Git, curl and tar available:

```bash
export MOON_HOME="$PWD/.ci-moon"
bash scripts/install-ci-toolchain.sh
export PATH="$MOON_HOME/bin:$PATH"
moon update
bash scripts/check-baseline.sh
```

The script independently runs each gate and returns failure if any fails:

```bash
moon check --target js
moon test --target js
moon build --target js
moon -C vendor/clap test --target js
```

## Local results and backend limitation

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
20, 2026, so they are not the CI installation source.

**The tagged WASM compiler distribution does not pass the WebAssembly baseline.**
Its wasm/wasm-gc output generated an interpolation StringBuilder size hint of
`2147483647`, causing allocator traps before assertions. This was reproduced on
Node 26 and Node 22 with fresh bundled core; the same source passes on JavaScript
and with the native compiler. CI's explicit JavaScript backend establishes a
reproducible source/behavior baseline; it does not certify WebAssembly compilation
by this distribution. A future backend gate requires an upstream compiler fix or
a durable native compiler distribution.

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
