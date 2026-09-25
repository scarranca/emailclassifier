# Cove 0.1.19 — custom Jev classifiers

## Scope and design

Reference: `/Users/santiagocarranca/Pen/Cove.pen`, frames `ywEUZ` (Create custom agent) and `PvVqD` (Your agents), read through Pen MCP on September 23. Implemented the full-page creation flow and agent management list using Cove typography, forms, buttons and native menus. Wide editor has adjacent configuration and test panels; narrow editor stacks them with a persistent save footer.

The shipped agent type is a classifier: match → chosen Gmail user label, uncertain → Cove / Needs review, no match → leave unchanged. The examples in the design implying calendar drafting or generated extraction are not represented as working classifier capabilities. Results show Jev-selected source evidence rather than fabricated extracted invoice fields.

## Requirements and evidence

- Create/edit instructions and label, save incomplete named drafts, turn on, pause/resume, duplicate and delete: `CustomAgent`, AppStore library operations, `CustomAgentTests`, `CustomAgentCoreTests`.
- Your agents: real status counts, filter/search, edit/menu actions, activity and email source navigation. No seeded agents in real accounts. Existing built-in organizer and writing preferences remain accessible.
- Preview from synthetic invoice or downloaded inbox selection: same Jev classifier as automatic execution; never writes Gmail or records a completed run. Field/source changes and navigation cancel/invalidate previews.
- Automatic execution: integrated after successful new-mail sync regardless of the built-in organizer toggle. Active cutoffs exclude prior mail; drafts/outgoing/trash/spam/archived mail excluded. Completed checks deduplicated. No server scheduler: Cove must be open.
- Pause/edit/account guards checked between async stages, especially before label application. No mail send/delete capability in the custom-agent execution path.
- Label creation/reuse through Gmail's labels API; only custom labels accepted. Nonmatch does not modify Gmail. Low-confidence results (below 0.8) and incomplete attachment/body coverage are routed to review.
- Jev decisions saved before Gmail writes. Label failures can retry the saved decision without a second Jev evaluation. Per-message errors and ten-minute cooldown are persisted. Activity provides an explicit retry action.
- Optional readable PDF/text attachments: at most five files, 5 MB/file, 20 PDF pages/file; Jev text budgets bound email and attachments. Unsupported/scanned/partial content is explicitly flagged. PDF and text fixtures verify actual extracted text reaches evaluation.
- Agent configuration and activity stored per mailbox using the existing encrypted Database record layer. Disconnect resets in-memory state; deletion removes only agent records/activity, never Gmail labels or messages.

## Validation

- Full suite after unlocking the Mac: **315 passed, four opt-in live checks skipped, zero failures** (`/tmp/cove-0119-unlocked-tests.log`). This includes 15 dedicated agent checks. The two pre-existing wheel-forwarding tests that failed with a locked desktop now pass without source or assertion changes.
- Four native renders at 720 and 1100 points inspected. Table headers aligned and test-source control refined after first inspection. Captures adjacent.
- Installed production app: opened Agents with ⌘3, loaded invoice template, ran its fictional sample through the configured Jev connection. UI displayed **Match found · Confidence 98%**, the correct source passage, **Would apply label: Finance / Invoices**, and **Preview only. No labels have been applied.**
- Created a temporary draft, edited its name through native keyboard input, saved and verified draft status. Deleted that test draft through the confirmation dialog and verified the empty list. No agent was activated on the real mailbox. Left a blank Create an agent screen open with ⌘N.
- No real emails, Gmail labels, or calendar events were changed for QA. Gmail label creation/reuse, application, failure/retry, and automatic sync wiring are covered with deterministic transport tests.
- API contracts checked against https://docs.typesafe.ai/api and official Gmail users.labels / users.messages.modify documentation.

## Release

Universal 0.1.19 build 21 installed at `/Applications/Cove.app`. Developer ID signature, location entitlement, app ticket and Gatekeeper verified. Previous app retained at `.local/app-backups/Cove-before-0.1.19-641171b2-ae65-41d3-b756-5242d7242416.app`.

- App notarization: `c9ff440a-45d4-480f-b919-edc0b7811099`, Accepted and stapled.
- DMG notarization: `2e30499f-257e-4003-8303-06e97e99ca43`, Accepted and stapled.
- Installer: `dist/releases/Cove-0.1.19.dmg`. Image verification and Gatekeeper assessment passed.
- SHA-256: `4417a5a3380343182ed9f38c01c78f7e82448c6eac9ae0d402264cfe7f9419d6`.

The earlier locked-session notarization attempt had no submission ID. Profile access recovered after unlocking; no credential replacement was required.

## Website publishing follow-up (separate from installed feature)

The local site, privacy disclosure, release checksum and installer staging are updated to 0.1.19. Public Pages remains 0.1.18. Its expired Cloudflare OAuth session refreshed successfully, but subsequent exact-item Keychain reads by the publishing helper required interaction and could not complete non-interactively. The waiting helper was terminated; no deployment was created, no upload remains running. Do not claim the public download is updated. The installed feature and notarized local installer are complete.
