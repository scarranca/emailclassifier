# Cove 0.1.13 verification

Requested: a smaller Apply action on the left where attention follows the text reveal, and a working selected-text rewrite.

- Added compact size to the shared primary button style and placed Apply draft in the canvas footer, left aligned. Removed the duplicate primary action from wide review; compact inline review retains Apply. Existing returned-text animation is unchanged.
- Pending canvas now publishes and receives native selection. Compact inline review uses the same selection-aware editor. Both editors suppress programmatic delegate notifications and keep selection across focus changes.
- Rewrite selection runs from the canvas; ordinary writing shortcuts run immediately instead of only filling an instruction. Follow-up input labels selected scope.
- ComposeRefinement captures pending text and the selected UTF-16 range, submits the selected passage, then merges the result into the captured pending text. Its original draft snapshot and outer selection remain intact. Invalid Unicode/range boundaries and empty replacements fail. Cancellation/failure leaves the earlier suggestion intact; final Apply still guards stale original edits.
- Scoped style rewrites skip planning and prior full-email scheduling requests, avoiding unrelated meeting options being inserted into a fragment. Explicit availability requests retain controlled lookup support.

260 automated tests passed: 155 core and 105 rendering/workflow, with one opt-in live test skipped. Log: `/tmp/cove-0113-tests.log`. No real provider call or email send was made.

New integration check hosts the production AIWritingPanel and native suggestion canvas with an isolated provider settings instance and mocked HTTP transport. It exercises original selection -> rewrite -> immediate manual edit and Unicode selection -> nested refinement -> provider failure -> Apply, verifying exact request text, unchanged surrounding text, original preservation, selection synchronization, and three writer calls with no planner. New unit checks cover nested original scopes, invalid ranges, empty output, and stale original edits. Existing tests cover undo/review behavior, animation, Reduce Motion and long drafts.

Independent reviewer identified compact selection disagreement; bidirectional selection synchronization fixed it before the full suite. Synthetic native screenshots show the left Apply footer and narrow review states. The workspace screenshot injects the canvas preview independently and thus is evidence for canvas geometry, not a complete live provider session. Native app-control has been unavailable; no claim of live UI clicking is made.

Release/install details follow below.

Installed universal 0.1.13 build 15 at `/Applications/Cove.app` after verifying no Cove executable was running. Developer ID signature, Gatekeeper assessment, and stapled ticket passed. Previous bundle preserved at `.local/app-backups/Cove-before-0.1.13-a3e0b04c-2a0e-4d88-b346-63379be9732d.app`. User data and credentials were untouched. The user can reopen Cove. App notarization receipt: `cfbb098c-d9de-4c83-aec0-7c566add28f3`.

The app is fully installed and notarized. Separate DMG finalization is blocked: after app notarization succeeded, both default-keychain and explicit login-keychain `notarytool submit` returned “No Keychain password item found for profile: Cove-notarization” (exit 69). `dist/distribution/dmg-submission-0.1.13.json` is empty; no DMG submission ID exists. No duplicate upload occurred and no unnotarized 0.1.13 DMG was published to releases. Signed staging DMG: `dist/distribution/Cove-0.1.13.dmg`. The latest finalized shareable DMG remains 0.1.12. Restoring the local profile is needed only to finish the new DMG; the installed app does not depend on that step.
