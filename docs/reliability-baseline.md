# Reliability baseline — 2026-10-08

Base: `9b92727962a61cbd45020afe97fbce5553aa9e33` (remote HEAD at checkout).
The final patch has a passing baseline on a fresh isolated Mac copy, with no
previous `_build`, `.mooncakes`, or synthetic test outputs. No real vault was processed.

## Current compiler profile

Repository bootstrap and CI use the official **native-hosted compiler** on Linux
x86_64. Compiler host and generated target are separate: this compiler produces
JavaScript, WASM, WASM-GC and native executables. Node remains pinned to 26.12.1.

- Moon CLI and Moonrun: `0.1.20261104` (`940aa18`).
- Compiler: `0.10.20+65efd5b93`.
- Core: `0.10.20+65efd5b93`, from the exact-version official core archive.
- Dependencies remain `moonbitlang/x 0.5.5` and the vendored `clap 0.2.6` compatibility copy.

| Official input | Verified SHA-256 |
| --- | --- |
| Linux SDK, including native compiler and C runtime | `80d987523308fa490eba9f1baf98df996a5a7891e118357553b7c2608c0597c5` |
| Matching official core source archive | `8ec2a2c01335501d703867bb4eef5f92d3cd7e1ae1ee5f7f14d54d16d2c7c2b5` |

[Official SDK distribution path](https://cli.moonbitlang.com/binaries/0.10.20%2B65efd5b93/moonbit-linux-x86_64.tar.gz)
and [matching core source archive](https://cli.moonbitlang.com/cores/core-0.10.20%2B65efd5b93.tar.gz).
The installer checks the core's declared version as well as its archive checksum;
it never substitutes a different compiler host or a floating core. The native compiler
reports a November 5 build date while the CLI reports November 4.

The installer verifies archives before extraction, stages the installation, bundles
JS core, and verifies installed tools before promotion. Cache reuse checks the
installed hashes and versions. The cache key includes both setup scripts. Existing
invalid installations are rejected without modification; use a new `MOON_HOME`
when changing compiler profiles. A local `moon upgrade` does not alter these pins.

### Reproducibility and download retention

The SDK download's HTTP `x-amz-expiration` header advertises deletion on
**January 5, 2027**, under `delete binaries every 60days`. This is remote object
retention, not evidence that the downloaded executable expires at runtime. Fresh
installation after removal is not guaranteed; retained installations/caches do not
provide permanent artifact availability either. Missing downloads or changed hashes
fail explicitly. Update and revalidate the official pin before its retention window
ends; bootstrap never substitutes `latest` or the WASM-hosted compiler silently.

The previous durable compiler choice avoided dependence on a short-lived native
SDK download, but its generated WASM interpolation and native linking failed.
The same standalone interpolation source, compiler/core version and Node runner
works on both WASM targets when compiled with the native-hosted distribution.
This motivates the host change; it does not establish the compiler's internal bug.

### Target coverage

`check-baseline.sh` retains the warning-free JS suite and CLI/publishing checks.
`check-targets.sh` runs conventional check/test/build and vendored tests for WASM,
WASM-GC and native, then executes the native CLI's init/check/strict-build/inventory
workflow. Native retains its visible unused-import warning; JS and WASM gates deny
warnings. Portable no-host-import exports, supplied-note workers and real browser
reader/search tests remain independent required gates. A successful native target
check alone is never treated as native CLI execution.

Native file stamps use modification times; the JS watcher hashes contents, so
restoring identical bytes can cause one additional dependency rebuild on native.

## Source compatibility

The November 4 toolchain deprecates trailing `derive(...)` syntax and legacy
`String.view()`. Sixteen declarations now use `#derive(...)` attributes, preserving
the same traits, and the vendored CLI parser uses a full string slice for defaults.
No warning category is disabled, dependency version changed, or parser policy altered.
These source changes and the compiler pin are one upgrade; the previous pinned
compiler is not claimed to support the new attribute syntax.

The October 28 compiler uses `Json(value)` instead of deprecated `to_json()`
and `Iter::count` instead of `Iter::length`. Cache I/O now follows typed
raising APIs: `cache.load` returns `CacheStore raise CacheError`, and
`cache.save` returns `Unit raise CacheError`. Library callers should catch
`CacheError`; CLI cache warnings and fallback behavior are unchanged.
Warnings-as-errors remains enabled.

## Reproduce

With Node `26.12.1`, curl, tar and the standard Linux utilities available:

```bash
export MOON_HOME="$PWD/.ci-moon"
bash scripts/install-ci-toolchain.sh
export PATH="$MOON_HOME/bin:$PATH"
moon update
bash scripts/check-baseline.sh
bash scripts/check-targets.sh
```

Every JS compiler gate treats warnings as errors, runs independently and preserves
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

## Verified upgrade results — 2026-11-07

An isolated Linux x86_64 checkout based on `dae79b388006e230762e3dcdacd9452a2aee464b`
passed the complete gate sequence with the compiler/core profile above and Node
`26.12.1`: `check-baseline.sh`, `check-targets.sh`, `check-wasm-core.sh`,
`check-wasm-note.sh`, and `check-browser-note.sh`. The browser suite used headless
Chromium `153.0.8010.12` with its sandbox enabled; only synthetic sites were processed.

The JavaScript workspace suite passed all 1,653 tests. WASM, WASM-GC and native each
passed all 1,652 tests; each total includes the 16 vendored clap tests, which also
passed their explicit package gate. JavaScript and both WASM targets retain
warnings-as-errors. Native retains only its documented unused environment import.
The CLI/publication fixtures, 21 evidence tests, portable exports, supplied-note
workers, prepared search, browser reader, graph, and preview workflows also passed.

The actual installer passed both a fresh installation and cached reuse. An
intentionally corrupted disposable core manifest was rejected without overwriting
that installation. The vendored patch was reapplied to its checksum-verified
registry archive and compared with every source and manifest. Shell syntax and
`git diff --check` passed. These results establish the new pinned profile; they do
not claim that the new attribute syntax works with the previous compiler.

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
rebuilt packages. The then-current native archive advertised download-object deletion on November
20, 2026. The initial baseline therefore chose source installation, followed by
the WASM-hosted compiler. This described artifact retention, not a demonstrated
runtime expiry. The current native-hosted profile above supersedes that choice.

**The tagged WASM compiler distribution does not pass the WebAssembly baseline.**
Its wasm/wasm-gc output generated an interpolation StringBuilder size hint of
`2147483647`, causing allocator traps before assertions. This was reproduced on
Node 26 and Node 22 with fresh bundled core; the same source passes on JavaScript
and with the native compiler. The former JS-only conventional gate did not certify WebAssembly compilation
by that distribution. The current native-hosted profile runs both full WASM suites. The separate [portable core smoke gate](wasm-core.md)
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

### Pipe-safe CLI output

`scripts/check-piped-json.mjs` exercises the built JavaScript CLI using only
synthetic content. It compares complete output bytes through regular files and
pipes, including a controlled pending write and a slow reader, checks failure
status and JSON diagnostic counts, and ensures child processes terminate. It also
covers clean results, inventory and inventory-diff errors, fatal configuration
and argument errors, and prompt closed-pipe termination. Run it after
`moon build cmd/main --target js --deny-warn`; the baseline gate runs it alongside
`check-cli-json.mjs`. `LATTICE_PIPE_CLI` optionally selects another compiled CLI
for a pre-fix negative control. One-shot JSON consumers can parse stdout directly
and should separately check the command's exit status. Invalid argument syntax
retains the existing text-error contract; watch mode is not a one-object stream.
