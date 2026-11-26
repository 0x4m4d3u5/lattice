# Lattice

Lattice is a MoonBit static site generator and structural checker for Markdown
vaults. It can publish a public projection and prepare a separate, local
plaintext export for agent memory. Its roots are in the 2026 MoonBit Software
Synthesis Challenge; the [retrospective](docs/retrospective.md) records that history.

## Working contracts

- MoonBit types model content and diagnostics. Validation happens during
  `check` and `build`; it is not a compile-time proof of vault correctness.
- `check` and `inventory` are read-only. Preserve the distinction between
  validation, planned output and actual publication.
- Public source selection precedes tags, indexes, link resolution and other
  derived output. Draft status is not visibility. Keep the private-export
  destination and artifact boundaries intact.
- Read [README.md](README.md) for CLI behavior, [TODO.md](TODO.md) for the current
  vault workflow, and [build safety](docs/build-safety.md) for what is guaranteed.
  Keep the package README aligned with the user-facing CLI.

## Development

- Make small, coherent changes with a regression at the appropriate layer.
  For publication behavior, compare read-only check or inventory with emitted
  files through the CLI. Use synthetic fixtures for regressions and disposable
  copies of real vaults for evaluation. Never publish or upload private notes.
- Match the repository's pinned toolchain and target coverage. Start with
  `moon check --target js --deny-warn` and focused tests; the reliability workflow
  covers JS, native, Wasm and Wasm GC, including CLI and browser smoke tests.
- Check the [MoonBit standard library](https://mooncakes.io/docs/moonbitlang/core)
  for existing helpers before introducing new ones. Keep architectural decisions
  and tradeoffs in the relevant docs or commit message.
