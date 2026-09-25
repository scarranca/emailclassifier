# Cove 0.1.24 — signed in-app updates

- Sparkle 2.10.0 pinned in SwiftPM, embedded as a universal framework with installer helpers, re-signed inside-out with the app's Developer ID, and accompanied by its license.
- Cove menu and Settings expose Check for Updates. Daily background checks are enabled by default; users can disable them. Automatic downloading/installation and system profiling are disabled.
- Distribution-only HTTPS feed and public Ed25519 key; development/QA bundles do not start the updater. The private signing key remains in Keychain.
- Restart pauses for active mail/calendar operations, queued trash undo, open compose/chat, and attached sheets. The user saves/closes work and explicitly resumes from the menu.
- Full suite: 334 tests passed, 5 opt-in live tests skipped, no failures (339 total). New tests cover production/QA configuration, malformed feed/key configuration, immediate restart, deferred restart, continued blocking, and exactly-once resume.
- Universal release build, nested strict code signatures, framework runpath and public updater configuration checked. Both CPU slices link to the embedded framework.
- Package includes Sparkle's license. Final app notarization: `29ba64b4-d055-427b-aa1d-f19197442a33` (Accepted).
- Final DMG notarization: `9ca5ed00-57b7-4d52-b40e-7afb4ad374af` (Accepted).

- App and DMG stapled; ticket validation, strict signatures, DMG checksums, and Gatekeeper assessments passed.
- The archive and signed feed verified independently using CryptoKit Ed25519 with the bundled public key; a one-byte alteration to each payload was rejected.
- Cloudflare Pages production deployment `4a8097f3-8b8f-4a90-8d38-7c9c97cd4ba8` published the website, privacy disclosure, final DMG, checksums and signed feed together.
- `https://covemail.xyz/updates/appcast.xml` returns HTTP 200, `application/rss+xml`, and `max-age=0, must-revalidate`. Its bytes exactly match the locally verified signed feed.
- The public DMG matches the notarized artifact: 15,219,588 bytes, SHA-256 `6122642e65e1ee4d408ac3af30305c7268a9b32ae4bc0e0aa0e5b84806141875`. `/download/latest` redirects to it. The beta page advertises 0.1.24.
- Sparkle's real `checkForUpdateInformation` API was exercised against the public signed feed with isolated host bundles/preferences and a prohibited activation policy. A host at build 25 finds 0.1.24/build 26; build 26 reports no newer update. No windows were opened and the user's running Cove instance was left alone.

Limits: the interactive download/install/relaunch flow has not been driven end to end. The standard Sparkle user driver handles that flow; restart deferral is tested separately. Five live Gmail/provider tests remain opt-in and were skipped. After the user closed Cove, version 0.1.24/build 26 was installed in /Applications. Strict signature and Gatekeeper checks passed; the app was left closed. The previous app bundle was retained in .local/app-backups.
