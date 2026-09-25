# Cove 0.1.28 · Claude subscription and login completion

## Implemented

- A separate Claude subscription choice in Integrations. Connect, check, disconnect, native executable selection/install guidance, model aliases/exact IDs, test and save.
- Claude is available to the existing assistant, compose, and provider-independent email/calendar context planner after connection and model selection. It never falls back to API billing.
- The unmodified local Claude Code CLI owns authentication. Cove does not inspect or copy OAuth tokens. No parent API-key environment is inherited. Generation has no native tools, MCP servers, skills, plugins, persisted sessions, or retained debug output; private context goes through stdin, never shell or argument interpolation.
- Bounded stdout, explicit timeout, cancellation, safe broken-pipe handling, and redacted actionable errors. The outer filesystem restriction preserves the existing private-file boundary, allowing read-only administrator policy files. Internal temp files use the isolated runtime.
- Animated, responsive Gmail thank-you page appears only after account/mailbox commit. Failure/denial/invalid callbacks have distinct pages. Reduced motion, no external resources/scripts, no-store response. See ../login-success/AUDIT.md.

## Verification

- Full suite: 365 passed, 5 opt-in live tests skipped, zero failures (370 total). Included the opt-in installed Claude CLI probe.
- A targeted guard test also confirms neither subscription provider can call API completion or model-list endpoints.
- Final subprocess I/O hardening reran all 8 Claude tests (7 passed, real probe skipped) and all 8 provider/core boundary tests. The additional Claude filesystem test passed, bringing covered passing tests to 366. A subsequent concurrency regression also passed: checking the connection while generation is active preserves the signed-in provider (367 covered passing tests).
- Installed native Claude Code 2.1.282: isolated fresh-directory auth status returned signed out; exact generation arguments produced a structured not-logged-in response with zero token usage. This discovered and corrected the CLI-specific temp directory and managed-policy read requirements.
- Fixture coverage: official auth commands, subscription vs API auth, model/provider routing, bounded private email/draft/calendar context, missing/empty/error responses, cancelled/timeout workers with input larger than pipe capacity, and no API-key lookup.
- Invisible SwiftUI windows at 760 and 1100 pt; screenshots reviewed. WebKit callback at 320 and 1000 pt; no overflow or external resource loads, finite/reduced motion checked.

## Remaining live verification

No real Claude subscription login or authenticated model generation has been performed. The user must complete Anthropic's browser flow locally, then use Test model. No live mail, calendar mutation, message sending, or visible desktop interaction was used for QA. Anthropic's own callback page is controlled by Claude Code; the redesigned Cove page applies to Gmail.

## Release

- Version 0.1.28, build 30, universal macOS app.
- Final app notarization: 678d257b-7851-4d6f-99dd-e95160f1d0c0 (Accepted).
- Final DMG notarization: caaa0522-674c-4a6d-b78b-95563b96643f (Accepted).
- App and DMG stapled, strict signatures verified, Gatekeeper accepted, DMG integrity verified.
- DMG: 15,558,679 bytes; SHA-256 `c35c5f19881c7958e8edd1dd8a218b92c5a1574a6260dcb5a92f8968626ca38d`.
- Cloudflare Pages deployment: e971e866-e533-490b-8acb-32512729062f. Public metadata, beta page, latest-download redirect, and signed feed all point to 0.1.28.
- Public DMG downloaded independently, size/hash matched, Ed25519 signature verified with the bundled public key, and one-byte tampering rejected.
- Real headless Sparkle check: build 29 finds 0.1.28/build 30; build 30 finds no newer update. No foreground windows or installation.
- The first deployment attempt uploaded assets but failed before deployment due to the Mac resolver returning only unreachable IPv6 records for mcp.cloudflare.com. A read-only deployment inventory proved no duplicate deployment existed. A temporary per-process IPv4 resolution using Cloudflare HTTPS DNS records preserved TLS hostname verification and enabled publication. No system network settings were changed; temporary override removed afterward.
- Installed app was 0.1.27 during verification and was left untouched. Real Claude account login/generation remains pending the user’s private browser flow.
