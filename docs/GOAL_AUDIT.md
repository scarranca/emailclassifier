# Cove goal audit — September 22, 2026

This audit compares the current implementation with the user's original five PNG screens and subsequent instructions. The requested local macOS app scope is complete, with evidence and verification limits recorded below. Cloud deployment remains a separate phase.

## Original requirements and user decisions

| Requirement | Evidence inspected | Assessment |
| --- | --- | --- |
| Native macOS email app | SwiftUI entry point and views, `Package.swift`, packaged `dist/Cove.app`, release-build and strict code-signature results | Implemented and runs on this Mac; distribution to other Macs has not been requested or validated |
| Supplied design direction | Reopened all five original PNGs; inspected current source and native screens; later HTML exports preserved in `docs/design-source/` | Main visual structure exists; implemented refinements and verification limits are recorded below |
| Direct Gmail connection | OAuth implementation/session tests, live account restoration and sync, incremental-history tests, per-account cache | Live reading, restoration and one explicitly approved self-send/delivery verified; other remote mutations have contract/workflow coverage |
| Fast database; local allowed initially | SQLite per-account storage, atomic snapshot/cursor tests, persisted native sample edits, `docs/PERFORMANCE.md` | Implemented locally |
| Jev agent | `Jev.swift`, bounded-input and automation tests, live categorization and relevant/no-match passage requests | Implemented for structured decisions and original source passages; no general generative model |
| User's later “only the things Jev can solve” instruction | Categorization/action/urgency scores, passage selection, explicitly labeled deterministic reply templates | Generated summaries, generative reply rewriting and automated prose drafts in the early mockups were intentionally not added under this instruction |
| Login when not connected | Session-gated startup, native credential-free QA launch at compact size | Verified; local sample entry remains explicit |
| Formatted email detail | Separate decoded HTML/plain bodies, native WebKit tests and live formatted newsletter checks | Verified within documented resource restrictions |
| Assistant handles mailbox questions | Count parser and API tests; native live unread-count response; sample context-override check | Supported counts work. Thread-wide and cross-conversation downloaded-mail passage selection are implemented with explicit coverage limits; full-mailbox semantic search beyond the local cache is not claimed |
| Contacts page from supplied HTML | Local contact storage/tests, native create/search/draft/source navigation checks, compact directory inspection | Implemented from downloaded mail and local edits; Google Contacts sync is not implemented |
| Inexpensive SQL backend plan and PlanetScale MCP | `BACKEND_PLAN.md`, `DATABASE_RESEARCH.md`, successful MCP discovery of ready `cove` PostgreSQL database | Planning/connection request handled. No backend deployment, cloud mailbox upload or mobile sync has occurred |

## Screen-by-screen comparison

### Image 1 — Inbox and reader

The three-column layout, categories, priority/all-mail selection, search, message navigation, archive/trash/read/snooze controls, original body and review-before-send reply editor exist. Later exports supply the current spacing and empty reader state. Attachments were added to the reader and native saving was verified with exact sample bytes and a real Gmail attachment. The live attachment required a Gmail download (no embedded bytes); the saved PDF matched its 269,165-byte metadata and had valid PDF header/end markers. The temporary test copy was removed.

The reference's generated “short version” and drafted prose are represented by labeled Jev-selected passages and user-controlled templates following the Jev-only instruction. After explicit user approval, the exact self-test draft was sent once through the signed app. Native Sent and Inbox views showed the message; synced labels included SENT and INBOX on one Gmail message ID, with the original draft removed.

### Image 2 — Contextual assistant

The modal, explicit scope picker, question/response history, source card/link, draft navigation, local snooze and input composer exist. The modal adapts to the parent window. Live Jev found a relevant date passage and declined an unrelated question. Counts override selected-email context correctly.

The reference’s multiple source emails are now supported by Whole thread scope. A live Gmail conversation refresh and Jev request returned attributed original passages from two separate messages; an unrelated question returned no match. Native sample QA verified three source cards and navigation to the exact Sent message. Long threads are explicitly bounded to up to 20 messages and 24 KB of text; cached-only and omitted-text coverage is labeled. Downloaded mail now supports questions across conversations: it scans cached bodies locally, orders candidates by question-word overlap and recency, and sends at most 20 messages / 24 KB of passages to Jev. Overlapping text windows preserve adjacent context and allow details late in long bodies to compete. Drafts, Spam, Trash and local unsent messages are excluded. Native sample checks verified distinct source cards, exact source navigation, count overrides and passage expansion. Live Jev accepted a 20-of-138-candidate request, returned an original meeting-date passage, and returned no match for an unrelated serial-number question. This is bounded local retrieval, not an exhaustive semantic index or a live search of every Gmail message. Inbox rows remain individual messages. Generative narration and automatic prose drafting remain excluded by the later Jev-only instruction.

### Image 3 — Calendar

Week/workweek layout, all-day row, event selection, editable local events, optional Google primary-calendar reads, Meet links, and user-created focus blocks exist. Compact native checks verified the grid, event editor, and a durable edit without duplication.

The month navigator, Calendar-specific sidebar/New event shortcut, selected-day agenda, descriptions/attendees, local/Google visibility controls and computed focus suggestions are now implemented. Native sample verification covers those flows at compact size. The final signed app also completed a live read and persisted 52 events with availability metadata before presenting a focus suggestion. Connected availability is limited to the primary Google calendar and local events, requires recent successful coverage, and includes hidden busy events. Saved-event search and the outlined focus-suggestion overlay are now implemented and verified in native compact QA, including a confirmed local save and subsequent availability update. The original reference’s Work, Personal and Focus time calendars are now implemented as local groups with persisted event membership, independent visibility and an editor picker. Older local events default to Personal; reviewed focus suggestions default to Focus time. Native QA verified moving an event, hiding it, revealing it from search and saving a focus block. Hidden groups continue to reserve busy intervals. Arbitrary Google calendar discovery is not implemented. Event details use a dedicated agenda drill-down rather than keeping the entire day list visible below the selection.

### Image 4 — Gmail onboarding

The later sign-in HTML supersedes the original artwork/layout details. Its supplied artwork, two-panel composition, Gmail action, reassurance and local settings/sample entry are implemented. Compact signed-out native launch shows all primary/footer controls without clipping. Live browser OAuth and credential restoration are verified.

### Image 5 — Agent preferences

Instructions, memory search/edit/remove/Undo, memory opt-in, sign-off, three template tones and live Jev organization settings exist and persist per account. Populated native QA verified adding, editing, removing and restoring a memory, then reopening with the complete edited value and memory opt-out intact. That check exposed and fixed a filtered-edit bug: a memory now stays visible while it has focus, even if its new text stops matching the search. Filtering resumes on blur, with a clear empty-result state. Accessible names distinguish each memory field and removal/Undo/dismiss control. Temporary sample preferences were restored exactly. The compact layout was inspected. Automatic processing is independent of Gmail polling.

The reference's custom writing voice, generated reply length/refinement and automatically inferred memories are not implemented. Generated writing is outside the user's current Jev-only scope; any future expansion must preserve that instruction. The general settings destinations shown in the mockup are consolidated into Connections and the current preferences view rather than implemented as separate settings pages.

## Verification limits

- 165 automated checks currently cover core APIs/storage, native WebKit rendering, polling, Calendar availability/sync, thread-answer workflows and send workflows. Native sample checks cover the main UI flows. One approved live Gmail self-send and delivery also passed; Google Calendar mutations were not tested live.
- Accessibility-tree inspection exposed missing labels on message/reply editors and several icon buttons. The labels were corrected; native checks confirmed Message body, Reply body, Discard reply, Close connections, Previous/Next week and Remove instruction. Populated-memory checks additionally verified Memory 1, Forget memory 1, Undo forgetting memory, Dismiss memory undo, New memory, Search memories, New instruction and Your sign-off. A full VoiceOver interaction audit has not been performed.
- Gmail attachment download contracts, exact native sample saving and a real Gmail PDF download now pass. The live check inspected size and PDF structure without opening document contents.
- Broad model-quality evaluation is not implied by the successful categorization and passage examples.

The requested app scope is complete. Calendar refinements and limits are listed above. The final outstanding mail-workflow check passed: the user-approved self-test (subject “Cove Gmail verification - 22 Sep 2026”) was sent exactly once and verified in both Sent and Inbox. The signed app is available at `dist/Cove.app`. Full VoiceOver navigation and live Calendar mutations remain documented verification limits. Cloud sync is a separate backend implementation phase authorized so far for planning and connection only. Thread-aware and downloaded-mail source selection are verified within their documented bounds. Exhaustive full-Gmail semantic retrieval is not implemented or claimed.


## Security hardening follow-up

The September 22 security request is covered in `SECURITY.md`. Real-account records now use authenticated encryption with Keychain-held keys; the existing live cache migrated and reopened successfully, including its local draft. API sessions no longer persist responses/cookies or follow redirects; old bundle networking caches were removed. A confirmed local-removal action, provider-retention disclosure, HTTPS-only image opt-in and Hardened Runtime are implemented. The security review records test/native evidence and the explicit limits around backups, OS compromise, vendor retention, sandboxing and independent assessment. The suite now contains 165 passing tests.

## 0.1.8 targeted fix audit

| Requested fix | Evidence |
| --- | --- |
| Read after opening | Actual reader presentation invokes markViewed; native sample became Read; regression coverage includes Gmail modify, failure/retry, stale sync, pending sync and mailbox switch |
| Email scroll | Wheel over native formatted body moved visible checkpoints; rendering tests include hit-tested WebKit and content beyond the 20,000px height cap |
| Pen Integrations | Native wide/compact layout follows uEb0K with banner, tool cards, provider selection and model controls; installed version 0.1.8 verified |
| Lighter typography | Shared 24pt regular page titles and 18pt medium section headings; mail, settings, hub, contacts and calendar use regular/medium; brand wordmark retains weight |
| New models and collapsing | Live account catalog includes GPT-6 Astra/Sol/Luna; prior saved model preserved; Collapse all and independent sections verified |
| Pen Compose and review | Split editor/assistant follows zoCPb; editable review follows Y8iQDz with explicit Apply/Keep original, undo and stale/Unicode selection safeguards; native workspace and hosted review inspected |

Full suite: 213 passed. Verification limits: provider generation was covered through workflow mocks and synthetic review hosting, not a paid live generation; remote Gmail read mutation was checked through contract/workflow tests, while native read state was verified on isolated sample data. No cloud backend or additional integration connectors were added.
