# Cove 0.1.17 verification

297 tests passed (162 core, 135 app/workflow/rendering); three opt-in live tests skipped. Full log: `/tmp/cove-0117-final-tests.log`.

- Calendar parsing preserves self-attendee identity, organizer and recurring-instance identity. Old cached attendees remain compatible and cannot be mistaken for pending self invitations.
- Invitation listing requests hidden invitations. RSVP verifies current state and etag, uses If-Match and attendeesOmitted, updates only the self attendee, and uses the exact occurrence ID. All three responses covered; already-matching responses are idempotent. Missing self/cancelled event cannot mutate. HTTP failure stays visible and pending.
- Today/pending projections and local sample responses persist correctly; declined events leave Today.
- Approximate weather coordinates, fresh cache, conditional 304, expiry, stale forecast and HTTP failure tested. Denied location has actionable feedback; switching weather off discards an outstanding location result before any forecast request.
- Public-coordinate MET Norway forecast request returned HTTP 200 and parsed forecast data. This did not use the user's location. Native macOS permission flow remains unverified.
- Five-second deletion queue leaves disk/Gmail untouched until expiry; Undo restores selection. Short fixture timers verify one commit, failure recovery, batch Undo and sign-out cancellation.
- Synthetic keyboard events exercise the actual native handler; a focused text editor and compose retain normal editing behavior. No live email was deleted.
- Production Home/notification hosted in native NSHostingView and inspected at 720/1100 widths. Captures contain synthetic data. Actual RSVP and full live app interactions were not exercised because native app-control startup fails.

Packaging and installation status follows.

App notarization accepted: `402f2a4d-1d9f-4212-9709-aaaab74ec0a7`. Installed /Applications/Cove.app 0.1.17 build 19. Strict signature, Gatekeeper, stapled ticket and universal architectures verified. Previous complete bundle: `/Users/santiagocarranca/orca/workspaces/emailclassifier/lugworm/.local/app-backups/Cove-before-0.1.17-12e7841e-8bfe-4d93-82c8-41d8ab3b784d.app`. User data and credentials untouched. Native app control remains unavailable; user should reopen Cove.

Final `dist/releases/Cove-0.1.17.dmg` is signed, notarized, stapled, checksum verified and Gatekeeper accepted. DMG receipt: `27bd4e1a-e79b-4572-8c92-8df35bf80336`. No remaining implementation, packaging or installation work for this update. Live location permission and invitation responses remain user-controlled verification limits.
