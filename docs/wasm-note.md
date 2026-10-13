# Experimental portable note renderer

`src/note` composes the existing frontmatter, Markdown and wikilink APIs into
`render_note(source, source_file, links_json) -> String`. All three inputs and
the output are text. `links_json` is a JSON object mapping canonical slugs to
URL strings, as used by the existing wikilink resolver. The response is JSON:

```json
{"html":"<p>Hello 🌱.</p>\n","diagnostics":[]}
```

Diagnostics contain `kind`, `source` and `message`. Kinds are `link_map`,
`frontmatter`, `wikilink` and `shortcode`. An invalid link map or frontmatter
returns immediately. Otherwise all link and Markdown shortcode issues are
collected in that order; any diagnostic suppresses HTML. Footnote shortcode
errors use the same path. The source name is supplied by the caller and is
preserved in diagnostics. Frontmatter must use the existing YAML/TOML delimiters.

Cross-note [heading wikilinks](wikilink-headings.md) share the existing
Markdown heading-ID rules and page lookup.

This is a Markdown-fragment boundary, not a full site builder. It does not apply
collection schemas, draft publication, templates, filesystem/vault discovery,
URL policies, or output publication. It inherits the existing Markdown syntax
and rendering behavior. Existing public APIs are unchanged.

Treat note text and link-map URLs as trusted inputs. Existing Markdown
intentionally passes raw HTML through, and link-map URLs are not checked for
dangerous schemes. WASM and worker isolation do not make the returned HTML safe
for DOM insertion. If inputs are untrusted, the host must sanitize the returned
HTML under its own policy before inserting it into the DOM. This boundary does
not add a sanitizer or change existing rendering behavior.

## Host ABI and verification

`examples/wasm_note` exports only `render_note`. Its WASM GC configuration uses
MoonBit's documented [JavaScript string ABI](https://docs.moonbitlang.com/en/latest/language/ffi.html)
and [string builtin link options](https://docs.moonbitlang.com/en/latest/toolchain/moon/package.html#wasm-gc-backend-link-options).
This experimental host surface requires WASM GC **and** JavaScript string
builtins; it does not promise an MVP-WASM or stable pointer ABI. The existing
import-free `wasm`/`wasm-gc` fixture modules are unchanged.

`examples/wasm_note/host.mjs` is a reusable standard-WebAssembly adapter:

```js
import { createNoteRenderer } from './examples/wasm_note/host.mjs';
const render = await createNoteRenderer(wasmBytes);
const result = render('---\ntitle: Garden\n---\nRead [[soil]].',
  'garden.md', '{"soil":"/notes/soil/"}');
```

The adapter compiles with `builtins: ['js-string']` and the configured `_`
string-constant namespace, checks that the runtime-recognized module needs no
host imports and has exactly the expected export, and decodes response JSON.
Strings cross directly as JavaScript strings, including UTF-16 code units;
there is no buffer allocation/free protocol. Initialization rejects unsupported
runtimes, either during compilation or the host-import check. Each call uses
local data; the adapter reuses one module instance.

`bash scripts/check-wasm-note.sh` builds the JavaScript control and WASM GC
application with warnings denied. Both run the same 531 independent supplied-note
comparisons: YAML/TOML, exact HTML and escaped URLs, cross-note heading links,
[matching-run inline code spans](inline-code.md),
Unicode/combining characters,
NUL and a lone surrogate, malformed link maps, source-preserving diagnostics,
footnote errors, 512 changing notes/maps, a 65,536-code-unit body, and a small
call after it. The WASM checks use one reused Node worker instance with a
30-second test deadline. An argument-type control rejects non-string host input.

Calls allocate managed data and execute synchronously. The worker and runtime
own reclamation; no linear-memory handles or note state are retained by this
API. The stress checks establish the tested workload, not a memory ceiling,
leak proof, or quota for arbitrary note sizes. Hosts choose their own worker
lifetime and resource budget.

Verified with the repository-pinned toolchain and Node 26.10.0. The browser
verification below adds a real Chromium Web Worker run. The known compiler
interpolation bug and existing gates remain documented in [wasm-core.md](wasm-core.md).
AI-assisted investigation chose the documented string ABI over dependence on
unstable managed-object layouts and checked host-supplied expected results
rather than adding more fixed exported test functions. Replacing resolved URLs
with `/wrong/` compiled with warnings denied and failed the independent expected
HTML comparison on both JavaScript and WASM GC; restoring the code passed.

## Real browser worker gate

```sh
npm ci --prefix tests/browser --ignore-scripts
npm exec --prefix tests/browser -- playwright install chromium --only-shell
bash scripts/check-browser-note.sh
```

The isolated harness pins official Playwright 1.63.0 and its core package with
registry integrity hashes. It launches a fresh headless browser profile with
`chromiumSandbox: true`; it does not connect to existing browser sessions or
change security settings. The test server binds to `127.0.0.1` on an ephemeral
port and exposes only four fixed test assets. Test-context requests outside
that origin are rejected. The returned HTML is compared as data, never inserted
into the DOM.

A real module Web Worker loads the checked-in adapter and runs the same 531
supplied-note comparisons on one reused WASM GC instance. The harness confirms
`DedicatedWorkerGlobalScope`, reports the worker user agent and actual browser
version, and terminates the worker after completion or a 30-second deadline.
Browser and server are closed on success or failure. The Node and existing
core gates remain required.

CI on Ubuntu 24.04 uses the runner's preinstalled Google Chrome through
Playwright's [supported `chrome` channel](https://playwright.dev/docs/browsers#google-chrome--microsoft-edge):

```sh
npm ci --prefix tests/browser --ignore-scripts
LATTICE_BROWSER_CHANNEL=chrome bash scripts/check-browser-note.sh
```

The downloaded Chromium build failed hosted startup with "No usable sandbox".
Chromium's [AppArmor guidance](https://chromium.googlesource.com/chromium/src/+/main/docs/security/apparmor-userns-restrictions.md)
explains Ubuntu 23.10+ restrictions on downloaded builds and the existing policy
for installed Chrome at `/opt/google/chrome/chrome`. Using that installed browser
keeps `chromiumSandbox: true` without modifying AppArmor, profiles, sysctls or
sandbox helpers. There is no fallback that disables the sandbox or skips cases.
The [Ubuntu 24.04 runner image](https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md)
includes Chrome; its version follows runner-image updates and is **not pinned**
by the Playwright lockfile. CI reports the installed and launched versions.
The default local command above still uses Playwright's downloaded Chromium.

Verified locally with Chromium 153.0.8010.12, Playwright 1.63.0, and the pinned
MoonBit toolchain on Linux x86_64. The installed Chrome channel also passed all
531 comparisons locally with Google Chrome 155.0.8059.39 and the sandbox enabled.
Hosted validation of that channel remains required before merge.
The earlier browser wrong-URL mutation compiled with
warnings denied and failed the independent HTML comparison; restoring the code
passed its original 525 comparisons. This establishes Chromium browser-worker execution
for this surface, not Firefox/Safari coverage, a memory bound, or full WASM-suite
certification. AI-assisted follow-up found that an official isolated Playwright
installation was feasible despite the earlier absence of a browser executable.
