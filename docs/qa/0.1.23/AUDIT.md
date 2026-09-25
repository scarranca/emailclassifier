# Cove 0.1.23 — redesigned agent chat

Reference: Pen `1. Cove Agent Chat`, frame Fe933, modal VxRhd, read through Pen MCP on September 24, 2026. The user's Pen document was read only. A reference image is retained alongside this audit.

Implementation:
- 752×800-point maximum chat with a 32-point emblem and a single-line 16-point semibold header, plain selected-thread context, 15-point messages and a 464-point maximum user bubble.
- Borderless source block with an 18-point semibold source title, source metadata/link, outlined draft-review/open-email action and quiet Remind me menu. Remind me uses the existing local snooze behavior and states that behavior in its help and confirmation.
- The first source is visible, additional sources expandable, with a distinct-email count. Actual source subjects are used as titles; no model-generated task or deadline is invented to match the design's sample content.
- Inline model popover chooses among connected providers' saved models or Jev original passages; Manage models opens Integrations. Selection applies to this conversation and does not silently change global provider settings. Displayed model comes from settings, not the reference's example Claude label.
- Compact Mail search toggle retains the review-before-search flow. Selected email context also reaches the generated search query. Plus opens email/thread/mailbox scope.
- The 34-point send control becomes Stop during a request; cancellation leaves a visible neutral stopped state with retry. Provider errors remain visible with retry.
- Helpful/not-helpful state is local to the current conversation; no telemetry or provider feedback is sent. Copy answer and detailed grounding information are available from the response options menu.
- Privacy disclosure remains available from the info control beside the approval note, including provider context and the local feedback limitation.
- Long responses scroll independently above the fixed composer. Narrow widths use a compact Mail search control. Existing Reduce Motion behavior covers control transitions.

Validation:
- Full automated suite: 331 passed, five opt-in live checks skipped. Log: `/tmp/cove-0123-tests.log`.
- Actual AssistantView rendered at the 752×800 design size, at 512×652 with a long response, and with a provider error. All three images were visually inspected; composer stays visible and no horizontal clipping was observed. Images retained alongside this audit.
- Fixture provider settings contain no real keys and make no network requests; original fixture draft remains unchanged. Hidden QA windows are asserted invisible and do not take desktop focus.
- Distinct source counts and the unavailable-Gmail-count label have regression coverage.
- Direct accessibility button automation is not supported by the hidden SwiftUI hierarchy here, so no physical click/hover test is claimed. Existing model settings, source navigation, snooze, Gmail review, calendar review and assistant context paths are retained.

Universal Developer ID app built for Apple Silicon and Intel. App notarization `7189b631-83d8-4244-9d97-3531cc7c70f7` accepted and stapled. Installed 0.1.23 build 25 at `/Applications/Cove.app` after rechecking Cove was closed; installed signature and Gatekeeper assessment pass. Prior bundle retained in `.local/app-backups/Cove-before-0.1.23-b08ead5fbc34426c94310d6b77504344.app`. Cove was not launched and desktop focus was not taken. DMG notarization `33aad0e7-57db-400d-b9e8-852bd26d60e1` accepted and stapled; image integrity and Gatekeeper passed. Shareable installer: `dist/releases/Cove-0.1.23.dmg`. SHA-256: `1a0f4fb5cd07c25274447cf7cc00944c4b1d13483160dae1b4b094b32d2af8b0`. Public website download was not updated.
