# Cove 0.1.20 — conditional agents

- Ordered rules (up to eight): first confident match only; label, draft reply, or both.
- Jev returns an allowlisted rule choice. Unknown choices fail closed. Confidence below 80% or incomplete extraction routes to Needs review.
- Old fixed-label configurations and run records continue decoding; conversion is explicit in the editor.
- Writing requests use the configured provider, saved writing voice/preferences, triggering email and bounded readable attachments. Background reply generation does not call Gmail/Calendar tools.
- Suggestions persist in encrypted per-mailbox activity. Applying is explicit and refuses to overwrite an existing draft; original conversation handles recipient/threading and manual send.
- Completed labels persist before writing begins. Provider failures remain visible and retries reuse the classification and completed label action. Pause/edit/account guards discard stale asynchronous results.
- UI: editable sample body, reorder/remove rules, applicable fields only, matched-condition preview, list shortcut to pending replies, left-aligned review action.

Validation: full swift test suite passed 322 tests, with four opt-in live checks skipped. Dedicated agent coverage includes branch routing, malformed choices, legacy decoding, attachments, retry across restart, no-match/uncertain suppression of writing, pause during writing, suggestion persistence and draft protection. Synthetic screenshots at 720 and 1100 points are saved alongside this audit.

Native verification: installed the Developer ID signed build and preserved the existing Fin agent. Converted Fin to two ordered label rules without activating it. Synthetic live Jev previews returned US EXPENSE for Cherry (97%) and MX expense for Gigstack (95%). Saved as draft, reopened and verified both conditions and labels. No real Gmail label write or email send was performed for QA. Generated replies were validated with injected provider responses, not a live paid writing request.

Final universal release rebuilt after the Integrations disclosure correction and installed successfully. Strict signature and Gatekeeper checks pass for both app and DMG. App receipt 310cb135-5918-4057-b07b-cf9a88d56945 and DMG receipt 6876b6c1-6a29-49e5-991f-bf1a396325c0 are accepted and stapled. Installer: dist/releases/Cove-0.1.20.dmg. SHA-256: 3f9e4381bafe012ff2fc14b523068fb69dd148d805bbf25f689e02aa362e4fb5. Earlier same-version packaging receipts are superseded. Fin was reopened after the final installation and both rules remained saved as a draft.
