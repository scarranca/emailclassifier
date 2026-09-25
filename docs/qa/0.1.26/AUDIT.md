# Cove 0.1.26 — model picker regression fix

The user's screenshots showed that Settings loaded a full account catalog but the assistant popup displayed only its saved default.

Reproduced before the fix:
- At its natural fitting size, the previous popover was only 261 points high. Its max-height-only ScrollView collapsed around the saved-model row. The earlier rendering test forced a 475-point parent and masked this bug.
- If a connection became available after the picker appeared, discovery was never called because the task ID only depended on the manual refresh count. The new test observed zero requests instead of one.

Changes:
- Give the model list a stable 280-point scroll area, independent of the initial single saved row.
- Share the model catalog owned by AIProviderSettings. Successful Settings discovery immediately populates the catalog read by chat.
- Reload when the eligible provider list changes, including delayed connection restoration.
- Coalesce catalog discovery in a shared task that survives closing the popover. Reopening waits for that same request. Changing credentials or disconnecting invalidates/cancels its catalog; stale results are discarded.
- Preserve per-conversation selection and Settings defaults.

Validation:
- Both new reproduction tests failed on the previous implementation and pass with the fix.
- All 12 picker tests pass, covering shared Settings/chat results, natural fitting size, delayed connection readiness, close/reopen during discovery, disconnect during discovery, earlier selection and error cases.
- Full suite: 346 passed, 5 opt-in live tests skipped (351 total), no failures.
- Rendered the real picker at its natural fitting size, with 25 synthetic models, in an invisible window. Visually inspected the resulting model-picker.png; the list, selection and footer are visible. No physical mouse/keyboard or live credentials were used.

Universal Developer ID app and DMG passed strict signatures, notarization, stapling and Gatekeeper. App receipt: aae5267b-8944-4dd3-be5a-a7a9148cffd1. DMG receipt: 33faa9a8-c13e-4434-9576-047699753036.

Cloudflare Pages deployment 7d788d37-deaf-4b82-b604-469461e48755 published the release. The public signed feed exactly matches the verified local feed. The public DMG matches SHA-256 15a3012a8a5814219be2f3c5867b707be3f21dff7e6a6135d741599d2ddbe262 (14,946,606 bytes). Independent Ed25519 verification passed and tampering was rejected. Headless Sparkle checks confirm build 27 finds 0.1.26/build 28 and build 28 finds no newer update.

The running installed app was left unchanged; the user can install through Check for Updates. Interactive live-account clicking is not claimed.
