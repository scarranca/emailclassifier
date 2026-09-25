# Cove 0.1.10 verification

Original scope: dramatically improve dot-to-text Compose animation; make configured ChatGPT writing and read-only tools produce a real first available meeting time; omit unconfigured AI runtime options; clarify calendar event boundaries. Three requested subagents implemented motion, scheduling, and calendar changes. Root integrated provider readiness and reviewed the combined result.

| Requirement | Current evidence |
| --- | --- |
| Dots form text | WritingMotion uses actual TextKit glyph paths, bounded to 1, 400 dots and first visible canvas. Hosted production frames at 0.47/0.72/1.0 are included here. Inspected: dots resolve into exact greeting/body/signature positions. |
| Motion remains usable | Four ComposeWorkspaceRenderingTests pass: preserved original/draft storage; finite real timer completion; exact particle destinations; native selectable text; edits do not replay; no-motion immediate path; long-body cap. Runtime respects macOS Reduce Motion. |
| Use configured subscription; hide unavailable options | AIProviderSettings requires model+saved key or model+connected ChatGPT; rendering does not read Keychain. Readiness test covers no credentials, model-only, key-only, connected subscription fallback, chosen valid provider, removal. AIWritingPanel gates actions; Assistant has no unconfigured provider menu; reply AI entry is hidden until ready. Existing connection restored without login flow. Saved production provider read as chatGPT. |
| Actual first availability | WritingAvailability merges busy intervals including all-day/overnight/overlap and rejects malformed data. Resolves local day/DST and explicit duration/time windows, defaults 30 minutes 09–17. WritingAgent requires a complete calendar lookup, displays computed slot/assumptions, and rejects generic output after one bounded correction. |
| Actual model behavior | LiveWritingSmokeTests passed against saved gpt-6-luna subscription after final source changes: exact user typo request, synthetic Sep 24 busy until 10: 30 PDT;1 Calendar read, 2 completions; final invitation proposed Thursday, September 24, 2026 at 10: 30 AM PDT for 30 minutes. No real email/calendar data transmitted, no email sent. |
| Failure and tool boundaries | Focused scheduling cases cover planner omission, generic calendar plan replacement, 40+events, disabled/missing/failing calendar, incomplete/malformed results, account cancellation, model omission/correction/failure. Maximum 3 read-only tool calls; up to 3 model completions only if correction needed; no sends/calendar mutations. |
| Calendar separation | CalendarSeparationRenderingTests pass actual nonintersecting hit rectangles, 4 point gaps, short/late-night appointments, selected states, all-day and agenda renders. Reviewed production week screenshot plus 680/1024 point fixtures. |

Full run: `/tmp/cove-0110-tests.log`: 154 core tests, 94 rendering/workflow tests passed; live test skipped by default then separately passed in `/tmp/cove-0110-live.log`. Total 249 distinct tests exercised. Universal Developer ID build succeeded in `/tmp/cove-0110-build.log`.

Native app-control bridge still reports pipe startup failure. UI evidence uses real AppKit/SwiftUI hosted production views, not an interactive click-through of installed Cove. Actual provider execution is independently verified above. The app was observed closed before installation. Installed `/Applications/Cove.app` 0.1.10build12, retained the previous bundle under `.local/app-backups`, and verified Gatekeeper and the stapled ticket. Reopening remains a user action because the native-control bridge is unavailable.


Apple accepted app submission `c0941b81-d207-40ca-b48b-12c99ae3df19` and DMG submission `035fd240-d195-4039-b88c-555a681117e5`. Final shareable installer: `dist/releases/Cove-0.1.10.dmg`; signed, stapled, checksum verified, Gatekeeper accepted. No required implementation or packaging work remains.
