# lattice

Lattice is a MoonBit static site generator and structural checker for Markdown
vaults. It validates typed frontmatter and wikilinks, then builds a site from
the selected content. Validation happens at runtime, not at MoonBit compile time.

```text
lattice check     [content-dir] [-o <dir>] [options]
lattice inventory [content-dir] [options]
lattice build     [content-dir] [-o <dir>] [options]
lattice serve     [content-dir] [-o <dir>] [options]
```

Use `check` to validate without writing output and `inventory` to preview
planned files. Use `build --audience public` to project explicitly public
content from a mixed vault. A separate `build --audience private -o <fresh-dir>`
is a local plaintext memory export, not a privacy or encryption layer.

See the [main README](https://github.com/0x4m4d3u5/lattice#readme) for setup,
the full CLI reference and publication guarantees.
