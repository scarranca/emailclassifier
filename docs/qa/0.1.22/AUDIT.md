# Cove 0.1.22 — assistant invitation context

The reported request, “this event is worth attending?”, was routed before the selected email reached the planner. The planner received an empty mail array and could mistakenly ask for event details already shown in the invitation.

Changes:
- Resolve selected email/thread context before routing, reuse it for the answer, and prioritize the selected message when a thread exceeds prompt limits.
- Explicitly distinguish evaluating or describing an emailed event from reading or changing Calendar. An invitation may supply proposal details, never availability or proof of registration. Calendar creation continues through the existing review button only.
- Keep the last three successful exchanges in the same email/scope as bounded untrusted context for both routing and answers. Failed attempts and other selections do not supply follow-up context.
- Ground advice in actual invitation benefits, constraints and tradeoffs; give a conditional assessment without inventing personal goals or asking which event when it is identified.

Validation:
- 12 focused assistant/calendar tests passed, including selected evidence delivery, bounded history, and read-only proposal behavior.
- Full offline suite: 329 passed, five opt-in live tests skipped. Log: `/tmp/cove-0122-tests.log`.
- Separate opt-in live test passed with the saved `gpt-6-sol` model. Synthetic invitation questions about value and date/location routed to email with no calendar reads. The generated advice cited the invitation, explained founder networking and registration approval, and an explicit add request proposed October 15, 2026, 17:30–20:30 America/Los_Angeles using a fake read-only calendar. No real email or calendar was accessed or changed. Logs: `/tmp/cove-0122-live-context.log`, `/tmp/cove-live-assistant-context.txt`.
- Existing live scheduling regression also passed: ambiguous focus timing asks for clarification, then a follow-up with start/duration produces a review; summarizing a meeting email stays in the email route. Log: `/tmp/cove-0122-live-calendar.log`.
- No physical UI automation or window focus changes; user can keep using the Mac. This checks the application pipeline and model behavior, not every possible model or phrasing.

Universal Developer ID build passed for Intel and Apple Silicon. App notarization `f93b95ed-b17e-4f9c-950e-7987194031c4` accepted; app stapled and Gatekeeper accepted. DMG notarization `0b39df72-0d4c-4241-9cf6-01b7ec6f3729` accepted and stapled; disk-image integrity and Gatekeeper checks passed.

Installer: `dist/releases/Cove-0.1.22.dmg`. SHA-256: `0d3efe7e63691fa5705a90eeaee5c36c5c3591d8dbbbca378c0efdcb30b14b6d`. A copy of the synthetic model response is `live-assistant-context.txt` alongside this audit. Public website download was not updated.

Installed at /Applications/Cove.app after the user confirmed Cove was closed. Installed version 0.1.22 build 24 and signature/Gatekeeper checks verified. Previous bundle preserved in .local/app-backups/Cove-before-0.1.22-58411fbf4cfa40e4a1843887ce9ed2e6.app. Cove was not launched; no desktop focus taken.
