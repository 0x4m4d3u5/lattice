# clap 0.2.6 compatibility copy

This is the source of `TheWaWaR/clap 0.2.6` from the Mooncakes registry, retaining
its MIT license, upstream README, and all 13 upstream tests. The registry archive
SHA-256 is `3cd182293d37bd4ef12bfe5edc845b77b204c910f221bdf0b51ba3e85e6f62e2`.
Upstream is https://github.com/TheWaWaR/clap.mbt; its master commit inspected on
2026-10-08 was `9bb2bedc138e08f5c9efe6e71e923aa7a8773282`, still version 0.2.6.
No newer published compatibility release was found.

Lattice uses this local source through `moon.mod.json`; it does not modify the
registry cache. `compatibility.patch` shows the complete changes to upstream code:

- `SimpleValue` uses the builtin `Map` (which retains `Show`) rather than the
  deprecated `HashMap`, whose `Show` implementation was removed.
- Numeric parsing uses `@string.parse_*` on a string view. Its current API raises
  a general error, so the `BasicValue` signature follows that API. Existing parser
  wrappers still turn parse failures into `InvalidArgumentValue`.
- The package explicitly imports the core string and hashmap APIs.
- The custom-value test uses the current parsing API and derives `Debug` for
  its asserted command enum. Parser algorithms and help text are unchanged.

Two local tests in `src/value_compat_test.mbt` additionally verify numeric boundaries
and error wrapping. Run `moon -C vendor/clap test --target js`; all 15 tests pass on the pinned toolchain with the JavaScript backend. See [the baseline backend limitation](../../docs/reliability-baseline.md#local-results-and-backend-limitation) for the tagged compiler distribution's WebAssembly allocation defect.
Return to a registry dependency when upstream publishes a compatible release and
these tests plus Lattice's CLI tests pass. Generated `_build` and `.mbti` files are
ignored and are not part of this copy.
