# Cove 0.1.41 focused settings validation

September 25, 2026.

- Five targeted Swift tests passed: offscreen settings navigation/layout, cloud pause persistence/layout, and updater behavior.
- Switched through Settings/Gmail, Jev, Reading, Privacy, updates, and back to Reading at 900 and 1100 points wide without showing a window. Selection resolves to the requested section; legacy Settings opens Gmail. Navigation does not reload credentials from Keychain.
- Inspected Reading and Jev renders: only the selected settings content is present. Nested advanced disclosures remain; the shared scrolling list and top-level collapse controls are removed.
- Google credentials remain in parent view state across section changes. Sync and authentication behavior are unchanged.
- Universal Developer ID app and DMG are notarized and stapled. App receipt `b1e4e59d-83cf-4144-98c7-2fd75052018e`; DMG receipt `ec887c8d-5746-4428-a826-6312a0d7c1c2`.
- Pages deployment `dc3f3972-9da7-418b-9948-64584fc82a5e` published 0.1.41/build 43. Public download, latest redirect, release metadata and signed feed verified against local bytes; tampered bytes rejected.
- DMG: 16,811,445 bytes, SHA-256 `82f06b1e02af5ef486e50ba5c5ac77116defb9a50e4db1ecc7b0281b272017e1`.
- Headless Sparkle probes: build 42 discovers 43, build 43 is current. No running application was quit or replaced.
