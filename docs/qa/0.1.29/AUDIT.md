# Cove 0.1.29 — model versions and Writing and answers

The user confirmed that Claude sign-in and the model response work. The remaining problem was model names without versions and a confusing setup page.

## Implementation

- Replaced the static Claude alias list with a stream-json initialize request to the unmodified official CLI. This request performs no inference; Cove parses only model metadata, not account data. Existing filesystem restrictions, no tools/MCP, environment isolation, and timeout/output limits apply.
- Explicit choices use the CLI’s resolved model IDs. Automatic is distinct and shows its current resolved version. Legacy saved aliases remain usable and gain resolved labels when metadata is available. Unknown/malformed results show an actionable error; no guessed version fallback.
- Shared model labels appear in Integrations, the chat picker, and chat’s selected-model control.
- Writing and answers now occupies the main width. It shows the saved default, one account selector, compact connected status, a model selector, and Test & use model. Manage connection reveals technical/reconnect controls. Privacy details remain accessible in a disclosure.
- Test & use saves only after a successful synthetic test and a cancellation check. Failure/cancellation preserves the old default. No real email is included in testing.

## Verification

- Full suite: 376 tests, 369 passed, 7 opt-in skips, no failures.
- Final targeted tests cover changed settings/connection/chat surfaces after final UI adjustments; all pass.
- Live connected-account model discovery passed via the official CLI: Automatic / Opus 5.5 (1M), Fable 5.1, Sonnet 5, Haiku 4.5. No inference, email, or credential extraction.
- Real signed-out CLI 2.1.282 discovery and generation-argument checks passed in an isolated sandbox.
- Parser regressions cover pinned IDs, distinct Automatic, version labels, deduplication, older metadata, malformed/redacted output.
- Offscreen NSHostingView checks at 620, 760, 1100 points; screenshots inspected for hierarchy, wrapping, and reachability. No visible windows or focus changes. Existing chat picker offscreen tests passed.
- Test-and-use regressions verify success commits, rejection preserves defaults, and cancellation cannot save.

## Distribution

Published 0.1.29 build 31, universal arm64/x86_64, Developer ID signed. App notarization `61f23b95-bd22-4d98-9f25-1e20f826823e` and DMG notarization `b412c52f-1967-449e-8712-c1e695a39e68` accepted. Both stapled; strict signatures, Gatekeeper, and DMG integrity passed.

Cloudflare deployment `a9b5a410-2a96-4163-848c-2e08ad70f3f2` completed successfully. Public metadata, beta link, and latest redirect resolve to 0.1.29. Downloaded DMG is 15,517,724 bytes, SHA-256 `7993a4eba978a48bdbb0893333fc6b23df096972a6ac182a93feb0199b0675f9`, byte-identical to the release. Independent Ed25519 verification passed and a tampered byte was rejected. Headless Sparkle discovers build 31 from build 30 and reports no newer update from 31.

The Mac’s MCP hostname route needed a temporary per-process IPv4 DNS fallback, obtained from Cloudflare DoH with normal hostname/TLS verification. The bridge was restored afterward; no system network settings changed.

The running installed app was left untouched; users update through Cove → Check for Updates….
