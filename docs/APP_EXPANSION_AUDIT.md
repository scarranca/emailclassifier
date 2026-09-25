# Cove 0.1.2 expansion audit — September 22, 2026

This audits the full active request against current implementation and observed behavior. Earlier goal audits describe prior releases.

| Requirement | Implementation and evidence |
| --- | --- |
| People shows contacts | `CoveApp.swift` routes People to the contact directory. Final native QA clicked People and showed 9 synthetic/downloaded correspondents and saved contacts, with name, address, and activity. Google Contacts sync remains outside scope. |
| OpenRouter, OpenAI, Anthropic BYOK and models | `AIProviderSettings`, `AIProviderClient`, `IntegrationsView`: separate Keychain items, persistent provider/model choices, provider model catalogs. Tests cover all three request/response shapes, credentials outside UserDefaults, failed saves, redacted errors, and catalog parsing. Native provider menu, secure key field, model controls, and missing-key error verified. |
| ChatGPT subscription | `ChatGPTConnection` uses a separate official Codex app-server sign-in, model/list, and generation lifecycle. Synthetic full protocol lifecycle passes; actual installed CLI initializes inside the filesystem sandbox. Requires separately installed native Codex and user browser sign-in; real subscription generation has not been exercised. No unofficial ChatGPT endpoint or existing token scraping. |
| AI writing and more capable answers/search | New-message/reply Write with AI opens instruction → generation → editable review → Use draft; normal Send stays separate. Native reply entry and Configure route verified. Assistant provider/search controls and disclosure verified. `AIPrompt.sourceMails` tracks exact bounded citation evidence. Whole thread shares tested Gmail refresh/cache fallback. Gmail search requires query review; tests cover GET-only bounded retrieval, cancellation, preserving edits and history/pagination. |
| Integrations page; GitHub deferred | Sidebar and Settings routes open Integrations. Gmail/Jev details and unavailable GitHub Coming later row verified in native UI. The supplied Documents/Cove-export.html is an Inbox export; preserved as `docs/design-source/InboxUnread.html`. Integrations uses the supplied Cove components rather than inventing a GitHub connection. |
| Home email click | Entire priority row opens its original email. Native Maya row opened Website launch — final sign-off in the reader. |
| Reading settings | Persistent Text-only reading and opt-in automatic HTTPS images in Settings. Native switch changes and labels verified. WebKit tests verify global settings control image policy and text-only removes the web view. Existing per-message override retained. |
| Design-system buttons/switches | Shared CoveToggleStyle and CoveMenuPicker; calendar, agent, reading, sort and provider controls use them. Load older mail and event actions use SecondaryButton. Native switch/menu/button appearance checked against supplied screenshots and components; compact Calendar toolbar remains usable. |
| Calendar current-time line | Per-minute current-day marker; DST/day-boundary tests. Native screenshot showed dot and horizontal line at 8:54 PM in Tuesday column. |
| Movable calendar bar | Explicit 12-point handle with resize cursor, bounded persisted width and keyboard/AX adjustment. Native drag changed 280 → 396 points; AX decrement changed to 372; navigation/relaunch retained width. Bounds tests cover compact and invalid values. |
| Home wrapping/divider | Short dates, full-width subject/excerpt and single continuous vertical separator. Wide native screenshot shows unbroken separator; half-screen layout stacks sections without clipped/wrapped controls. |
| Keep in touch only personal correspondence | `KeepInTouch` requires confident Jev People/Work plus non-bulk metadata, rejects marketing/system labels and automated senders. Eligibility/MIME tests pass. Final sample UI showed Sam and Priya, excluding newsletter/product/receipt fixtures. Metadata refresh is versioned for existing Gmail caches; existing sample fixtures migrate missing metadata only. |
| Clear unread emails | Leading dark dot, bold sender/subject/time, explicit Unread label and AX value. Native inbox screenshot verified unread rows contrasted with read Linear/Figma rows. |

## Validation

- Final `swift test`: **190 passed** (140 core, 50 app/rendering), zero failures. Log: `/tmp/cove-expansion-final-tests-2.log`.
- Universal release build completed for arm64 and x86_64, version **0.1.2 build 4**, signed with the existing Developer ID identity. Log: `/tmp/cove-expansion-release.log`.
- Native QA used the separate `ai.cove.qa` bundle, synthetic mailbox, separate defaults/database/Keychain namespace and ChatGPT runtime. No private mail was sent to the new providers, no new provider login was performed, and no live mail/calendar mutation was part of this audit.
- App notarization accepted: `af4150af-cd08-489a-a0ee-27f2190605bf`. DMG notarization accepted: `acef2779-5868-4ca8-a2cc-1ab7f9bb4e41`. Both app and DMG tickets stapled and validated; strict signatures, disk checksum and Gatekeeper assessments passed. Final artifact: `dist/releases/Cove-0.1.2.dmg`.

Live provider generation is an explicit verification limit, not a claim of successful account setup. Users supply their own API credentials or complete the official ChatGPT subscription login in Integrations. See [provider requirements and boundaries](AI-PROVIDERS.md).

## Installed update

The verified 0.1.2 build 4 bundle replaced `/Applications/Cove.app`; the prior bundle is retained under ignored `.local/app-backups/`. The updated app reopened with the existing Gmail account and local draft intact, without a Keychain prompt during this check. People showed **131 real contacts** from saved/downloaded correspondence. Cove is open on Integrations for user-controlled provider setup. Native metadata refresh runs through the normal Gmail sync.

DMG SHA-256: `c83e9e9f64c7a6cbb0590537585fc950faa4560d9e91a772b0dd160368e4257b`.
