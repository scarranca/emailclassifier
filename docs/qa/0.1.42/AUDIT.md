# Cove 0.1.42 settings typography and buttons

September 26, 2026.

- Three existing targeted Swift checks passed: settings navigation/offscreen layout, cloud pause persistence/layout, and Integrations rendering.
- Inspected native Privacy at 900 points wide and Integrations at 620 points wide, including expanded upcoming integrations. Existing fixtures also cover 760/1100-point Integrations and 1100-point Settings.
- Local/cloud removal actions use the shared SecondaryButton; confirmation and removal behavior are unchanged. No removal action was performed during testing.
- Typography changes are scoped to settings/integrations views. Main controls retain their standard height; secondary text uses 12-point body and 11-point metadata. Future integration copy is shorter and subordinate to the account/model controls.
- Layout fixtures use synthetic accounts and never bring a window to the foreground.
- Universal Developer ID app and DMG notarized/stapled. App receipt `077c9b5b-26d5-430c-a4b2-fc310633538e`; DMG receipt `f6fb0df8-5b48-4e2f-884a-a17a166f2d27`.
- Pages deployment `cd3042b6-a3f4-4949-a73f-e6228946cbab` published 0.1.42/build 44. Public latest redirect, beta page, metadata and signed feed verified. Downloaded bytes match the local notarized DMG; tampering rejected.
- DMG: 16,815,155 bytes, SHA-256 `d25e5155a331dded5b5b8600b16f7068c9555b0973086be6fdb1167cf1e49bd8`.
- Headless Sparkle probes passed: build 43 discovers 44; build 44 is current. No running app was quit or replaced.
