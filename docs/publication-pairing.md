# Publication pairing

Published content-index entries for final authored pages may contain:

```json
"publication": {
  "version": 1,
  "algorithm": "sha256",
  "digest": "<64 lowercase hexadecimal characters>"
}
```

The digest covers the exact UTF-8 HTML bytes prepared for the canonical page,
including template output, metadata, related notes, contextual backlinks and the
local graph. It excludes HTTP transfer encoding: a gzip-compressed response is
compared after decompression. No timestamp, source path or build identifier is
hashed separately. A template-only change can change the binding. Unchanged
cached and forced builds produce the same binding.

Only the final authored owner supplies a binding. Hidden drafts and authored
pages replaced by generated/static output do not supply one; `--drafts` includes
drafts deliberately. Generated indexes and redirect/root aliases do not inherit
another URL's binding. Custom templates are supported even if they omit the body.
The metadata lives in the index only, avoiding a self-referential HTML checksum.

## Host interpretation

The executable [evidence example](../examples/agent_evidence/run.mjs) compares
bytes from the same HTML response used for canonical-address/fragment validation.
It reports `pairing` separately from the existing address-based `status`:

| Pairing status | Meaning |
| --- | --- |
| `matched` | Response bytes match this index record's prepared HTML digest. |
| `mismatched` | Response bytes differ: for example mixed builds, stale output, or HTML transformed by a host/CDN. |
| `unknown` | Binding absent, version/algorithm unsupported, or host did not perform comparison. |
| `invalid` | Binding malformed, conflicting canonical records, or multiple bindings supplied where one object is required. |

Version 1 uses exactly `version`, `algorithm` and `digest`. Unsupported versions
or algorithms are unknown, not verified. Legacy indexes remain usable for
address validation and receive unknown pairing. The CLI exits unsuccessfully for
mismatched/invalid pairing; imported hosts can choose their own policy. A `ready`
address result alone must not be interpreted as a matched publication.

**Pairing does not establish passage presence.** A custom template that omits all
body text can still artifact-match while the index contains a passage. Matching
also does not authenticate the publisher, establish freshness, prove factual
truth, or show that a passage answers a question. Both index and HTML can be stale
or altered together. Full passage provenance/DOM extraction is a separate contract.

Bindings describe prepared output, not a filesystem transaction. Failed
validation publishes nothing; interruption/disk failure can still leave mixed
files. Pairing can expose such differences but does not repair them. It performs
no source edits, network crawling, redirects or output cleanup.
