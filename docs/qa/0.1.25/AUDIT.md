# Cove 0.1.25 — available models in assistant chat

The previous menu displayed one saved default per provider. The new picker uses the existing account-aware model discovery APIs, including the official Codex `model/list` pagination for ChatGPT subscription. It displays all returned models, groups providers, preserves saved/custom selections, and provides search, loading, empty/error feedback and refresh. Model IDs are not hardcoded.

A conversation stores provider and model together. The chosen model is passed to calendar routing, Gmail query generation, and answering. This does not change the global provider or saved default. Disconnecting a provider makes its conversation selection ineligible and falls back to an available configured provider.

Validation:
- 341 tests passed, 5 opt-in live tests skipped (346 total), no failures.
- Seven new tests cover discovery/deduplication, saved/custom choices, error recovery, independent provider failures, empty results, cancellation, disconnected-account fallback, default preservation, and the selected model reaching the provider request.
- Existing Codex fixture checks cover multi-page discovery, hidden-model exclusion, deduplication, and repeated-cursor errors.
- The real picker rendered offscreen with 25 fixture models; the scroll region and footer fit. Screenshot: model-picker.png. The window stayed invisible and no credentials or live model requests were used.
- No claim is made that all models shown by ChatGPT's web interface are available through Codex. The app lists what the connected provider returns.

Universal Developer ID build passed strict nested signatures. App notarization `2fc1f1fb-f11b-4b9c-a275-dc424132ac89` accepted and stapled; Gatekeeper accepted the app. DMG notarization `1322b977-0a58-4b1b-8dc0-1cdf971dde18` accepted and stapled. Signature, ticket, disk integrity and Gatekeeper checks passed.

Cloudflare Pages deployment `c62a1d29-274c-43b7-9452-a90ff9ddca14` published the signed feed, release and website. Public feed bytes match the signed local feed. The downloaded DMG matches SHA-256 `c4c160e6b7388b9881b10d5726edb5f336e62fe945a856a592522396588dfa87` (14,949,835 bytes); independent public-key verification passed and tampering was rejected. A headless Sparkle probe at build 26 finds 0.1.25/build 27; build 27 reports no newer update. The public beta page advertises 0.1.25.

The user's running /Applications/Cove.app remains 0.1.24. Version 0.1.25 is available through Check for Updates; no app was force-quit or replaced during work. The actual interactive install/relaunch flow remains for the user to initiate.
