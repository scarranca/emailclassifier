# Cove 0.1.40 settings readability validation

September 25, 2026.

- 12 targeted Swift tests pass: provider persistence, synthetic test context, failed/cancelled model checks preserving the default, credential-save failures, updater configuration, cloud pause persistence, and offscreen rendering.
- Inspected native Settings renders at 900 and 1100 points wide, and Integrations at 620, 760 and 1100 points wide. Text wraps and model-version labels remain readable. Test windows were never ordered front; no live account or Keychain reads were used by the layout fixtures.
- Settings typography and disclosures are scoped to these screens. Calendar, email content, stored credentials, cloud API, and AI execution logic are unchanged.
- No foreground UI interaction test was performed; offscreen AppKit accessibility did not expose the SwiftUI button tree. Layout and provider behavior were checked separately.
- Universal arm64/x86_64 app signed with Developer ID, notarized and stapled. App receipt: `266021b0-2d6f-4381-bfb3-9566ebfb76b4`; DMG receipt: `4108fd59-d533-4065-b021-8d20132851f2`.
- Cloudflare Pages deployment `f8ba0a4c-2795-4743-8fd4-14314d195067` published 0.1.40/build 42. Public download, beta page, latest redirect, checksum and signed feed all verified. Downloaded DMG matches local notarized bytes; signature tampering is rejected.
- Release: 16,749,478 bytes; SHA-256 `6ee571f38144d7fa4a408960f0f6ed1e7038a3d41d972c77a3ca516097ea278e`.
- Headless Sparkle checks passed: build 41 discovers 0.1.40/build 42; build 42 reports no newer release. The running Cove app was not quit or replaced.
