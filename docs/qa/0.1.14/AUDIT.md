# Cove 0.1.14 verification

Requests: improve tool choice for the user's selected model, resolve language drift, and make a failed generation after switching to Sol visible.

## Behavior

- Planner now has explicit decision rules and examples for mail lookup, calendar event facts, combined mail/free-time requests, wording-only edits, and scheduling follow-ups. It sees the current user request, envelope, clock, and successful request history, without saved style preferences or email/draft bodies directing lookups.
- Search guidance uses verified addresses in both directions, avoids invented exact-subject filters/date cutoffs, and requires a fresh lookup for an explicit latest-mail request. Identical calls are deduplicated. Fresh search results take priority over preselected context within the existing 20-mail cap. Search receipts record actual query/count/matching metadata, and activity shows query/date-range details.
- A bounded clarification-only plan asks for essential missing information and executes no tools/writer. Existing whitelist, three-tool ceiling, single-day availability, 31-day event range, and explicit Apply/Send remain.
- Writer language policy follows explicit output-language requests, otherwise the current user's language for a new draft and the existing passage language for a rewrite. Email context and saved voice do not silently select another language.
- Errors are fixed above the scrollable writing controls with attempted model, reason, Try again, and Writing settings. Retry keeps its captured scope and refuses to overwrite changed draft/preview text. ChatGPT RPC/turn errors retain bounded provider messages; timeouts are distinct actionable errors, not cancellation. Timeout/cancel shuts down helper state so an immediate retry can reconnect.

## Evidence

266 automated checks passed: 156 core, 110 rendering/workflow, with two opt-in live checks skipped by default. Final log `/tmp/cove-0114-final-tests.log`. Protocol fixtures cover model rejection, usage limit, timeout, and immediate reconnection. Production-panel integration confirms a saved model change is used on the next request and that a failed selected rewrite preserves pending text. Native hosted renders inspect the pinned error on narrow/wide panels; synthetic fixture transparent gaps are not app surfaces.

Actual saved model was `gpt-6-sol`; no model setting was changed. Both opt-in live scenarios passed through Cove's real ChatGPT connection using synthetic evidence only:

1. First free tomorrow followed by three options: two calendar reads, four completions. Transcript `cove-live-scheduling-followup.txt`.
2. Combined latest conversation and three times: one Gmail query `{from:maya@example.com to:maya@example.com} Pine` plus availability; draft in English despite Spanish source mail. Calendar recap chose calendar. Spanish wording edit chose no tools and remained Spanish despite previous scheduling history. Six completions, one Gmail search, two total calendar reads. Transcript/plans `cove-live-tool-language.txt`.

The original user failure was not reproduced with the synthetic Sol requests; no claim about its specific provider cause is made. The off-screen error placement and loss of provider details were confirmed in code and corrected. Prior native app-control attempts failed; this pass used hosted production views and actual provider tests rather than live app clicking. No real mailbox/calendar content was used in live tests and no email was sent.

Release details follow below.

Installed universal 0.1.14 build 16 at `/Applications/Cove.app` after confirming no Cove executable was running. Developer ID signature, Gatekeeper, and stapled ticket validated. Prior bundle preserved at `.local/app-backups/Cove-before-0.1.14-0b219b90-d621-497e-b4f6-f8136d5dbca1.app`. User data, credentials and selected model were untouched. App notarization receipt: `a2c5f547-4dca-4b7d-b29e-6a01308e99fe`. The user can reopen Cove.

Final shareable `dist/releases/Cove-0.1.14.dmg` is signed, notarized, stapled, disk-image checksum verified, and Gatekeeper accepted. DMG receipt: `563fced6-f19e-47a0-bf05-4cd5983a6866`. Notarization profile was accessible for this release; the final 0.1.14 installer supersedes the pending 0.1.13 container. No remaining implementation or packaging work for this update.
