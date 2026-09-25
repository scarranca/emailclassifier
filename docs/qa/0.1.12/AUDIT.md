# Cove 0.1.12 verification

Requested outcome: replace distracting waiting animation with a loader/skeleton and simplify the review experience after the first prompt.

- Thinking: native progress indicator with actual phase and small Cancel control; static skeleton in an empty email canvas. Reduce Motion substitutes an hourglass. No looping particles.
- Review: editable pending suggestion on the main canvas in wide Compose, compact sidebar with request/voice, Apply and Keep original, collapsed original comparison, integrated follow-up composer, prompt shortcuts, and collapsed Sources & checks. Inline review remains for compact Compose/replies.
- Safety: original editor remains mounted but disabled while a suggestion exists, and relinquishes first responder. Canvas edits flow into the pending suggestion; Apply/refine synchronously use the latest preview. Cancel/failure keeps the preceding suggestion. Existing Send gating, explicit Apply, undo, and session behavior remain.
- Returned text: existing finite dot-to-glyph reveal remains, ends on interaction, honors Reduce Motion, and does not replay on manual edits.

Full suite `/tmp/cove-0112-tests.log`: 155 core and 102 rendering/workflow checks passed (257 total); opt-in live provider smoke skipped. The UI-only change does not add provider calls; no real email was sent. Nine focused compose checks also passed in `/tmp/cove-compose-polish-verified.log`.

New hosted native checks cover 320/390-point review sidebars in ready/working states, no duplicated email editor, editable suggestion callback and apply boundary, loader/skeleton rendering, and disabled original-editor focus. Existing tests cover finite animation, long/Unicode text, immediate interaction, selection replacement, preservation, and reduced motion. The canvas-edit check exercises the native edit callback plus suggestion application; it is not an end-to-end live-app click test. Production panel synchronization was inspected and synchronous apply/refinement capture added.

Screenshots in this folder use synthetic fixtures hosted with production SwiftUI/AppKit components. Inspected narrow and wider ready/working sidebars and loading skeleton: no clipping. Independent reviewer findings (pending word count, hidden-editor focus, working heading) were corrected before the final checks.

Native app-control was retried and still fails with “Sky Computer Use native pipe startup failed.” Live app interaction cannot be verified with that connection. Release/install status follows below.

Universal 0.1.12 build 14 is built, Developer ID signed, notarized, and stapled. App receipt: `1399be96-46c9-4d34-8183-c916029a55de`. DMG receipt: `a2fc5871-aff8-48fa-82b3-142211711e2d`. `dist/releases/Cove-0.1.12.dmg` passed signature, ticket, disk-image checksum, and Gatekeeper checks. Build log: `/tmp/cove-0112-build.log`.

Installation is pending: `/Applications/Cove.app` is still running 0.1.11 (PID 47450 at the final check). Native app control is unavailable; the user must save their draft and quit before replacement. No running app bundle or user data was replaced.

Installation completed after the user confirmed Cove was closed and the process check found no running Cove executable. `/Applications/Cove.app` now contains universal 0.1.12 build 14. Installed signature, Gatekeeper, and stapled ticket validation passed. Prior bundle preserved at `.local/app-backups/Cove-before-0.1.12-c48873c8-bd9f-476a-8cee-45a3caa65372.app`. User data and credentials were untouched. Reopening is left to the user because native app control is unavailable.
