# Cove 0.1.11 verification

Requested outcome: stop continuously animating while crafting an email, preserve the animation after text arrives, and fix a follow-up asking for three time slots after a successful first-available meeting request.

| Requirement | Evidence |
| --- | --- |
| No continuous waiting animation | Removed WritingParticles and the canvas overlay, plus the refinement spinner. AI progress remains static text with Cancel. Production-hosted waiting frames taken 200ms apart are identical in ComposeWorkspaceRenderingTests; inspected compose-waiting-static.png. |
| Preserve returned-text animation | WritingCanvasPreview and WritingInkTextView unchanged. Existing native tests confirm dot-to-glyph destinations, visibly different motion frames, 1.25-second completion, selectable result, immediate review edits, bounded long text and disabled-motion behavior. Inspected compose-canvas-preview.png. |
| Keep follow-up context | AIWritingPanel snapshots WritingSession into each request and stores returned session only after success/cancellation checks. It survives Apply, resets for Keep original, envelope/account changes, and fresh Compose. Session stores bounded successful user requests and structured meeting parameters; no generated draft/email body is promoted to planner instruction. |
| Suggest three actual times | WritingAvailability slots returns the requested 1–5 distinct, non-overlapping options. Explicit count and previous date/duration/window survive omitted planner tools. Each follow-up re-fetches Calendar. Regression test changes busy intervals between calls and proves the former opening is absent. |
| Handle limited availability and bad output | Tests cover only two choices fitting, disabled lookups, preserved prior session on failure, and correction when the writer omits any required option. Existing tests cover incomplete/malformed calendar, account cancellation, overlaps, all-day events, time zones and DST. |
| Real provider flow | Opt-in live test uses saved gpt-6-luna ChatGPT subscription and synthetic Calendar data. First request proposed September 24 at 10:30 AM PDT. “suggest 3 timeslots” returned 10:30, 11:00, 11:30 on the same date. Two Calendar reads, four model completions. Full synthetic transcript: live-synthetic-followup.txt. No email sent. |

Full suite: `/tmp/cove-0111-tests.log`: 155 core tests plus 99 rendering/workflow tests passed. One live test skipped by default, separately passed in `/tmp/cove-followup-live.log`. Universal build: `/tmp/cove-0111-build.log`.

Native app-control still reports pipe startup failure; visual verification uses hosted production SwiftUI/AppKit views. Actual model behavior is tested through Cove's ChatGPT connection. Cove was observed closed before installation. `/Applications/Cove.app` now contains 0.1.11 build 13; the previous bundle is preserved under `.local/app-backups`. Installed signature, Gatekeeper, and stapled ticket validated. Reopening is left to the user because native UI control is unavailable.

App notarization accepted: `fa7c271f-3a43-4acc-bb01-20eebd25d9d9`.

DMG submission `e0d3fd64-0e14-4c69-a01d-4d7d588b5c1c` accepted; final `dist/releases/Cove-0.1.11.dmg` signed, stapled, checksum verified, and Gatekeeper accepted. Every requested requirement above is verified; no implementation or delivery work remains.
