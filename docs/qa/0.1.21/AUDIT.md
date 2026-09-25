# Cove 0.1.21 — inbox design and navigation

Reference: updated Pen `1. Cove` frame w3s2H, read through Pen MCP on September 24, 2026. Compact status replaces the large summary. Read/unread row fills and type weights, plus reader subject weight, follow the reference.

Keyboard: Up/Down traverse the current visible folder/filter and clamp at its ends. Escape/Left close the reader. Native event handling spans list and reader, including selectable read-only text. Editable text, modified keys, sheets, other windows and other screens retain native handling. Navigation remains available during sync. Row selection scrolls into view.

Hover: 140 ms fade and a distinct neutral background; Reduce Motion disables animation. Archive, read/unread and Delete are sibling controls, separate from the open-email target. Selected rows keep controls visible. Delete reuses the existing five-second Undo. Right-click actions remain available.

Validation:
- Full suite: 326 passed, four opt-in live checks skipped.
- Final native-focus refinement: 20 focused navigation/read-state/delete/invitation/weather tests passed. A regression case explicitly distinguishes a read-only text view from an editable reply/search editor.
- Offscreen rendering inspected at 900/1200-point mailbox widths plus 392-point row states; images alongside this file.
- Isolated Cove QA sample app: native Down opened first email, Up/Down changed the position by one, Escape returned to the unselected list. After clicking selectable email body text, Down changed 1 of 9 to 2 of 9. Down while typing in search left the reader closed and search focused.
- Physical hover testing was stopped at the user's request to keep the shared Mac available. Hover appearance and quick-action layout were reviewed offscreen; no native hover-click result is claimed.
- QA app closed. No real email was changed or sent. All desktop actions used the sample mailbox.

Release: universal Developer ID signed app installed as 0.1.21 build 23 without launching or taking focus. Final app notarization 73d21259-7400-449b-b7e4-736761b92d30 accepted and stapled. DMG completion recorded below.

Final DMG: dist/releases/Cove-0.1.21.dmg. Receipt 2b35b2ff-6322-41e9-a0a8-d6b575263d9e accepted/stapled; image integrity and Gatekeeper checks pass. SHA-256: b3119f9d945827ef507cdbb2997b1cdda4388b23553c2f606e926c5656861852.
