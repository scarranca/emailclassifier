# Implementation status

This file records both the current implementation and chronological verification milestones. Test totals, captures, and release checks in dated milestones describe those earlier builds; they are not a final audit of the current expansion.

## Goal evidence

| Requirement | Current evidence | Still needed |
| --- | --- | --- |
| Native macOS app | SwiftUI executable packaged in `dist/Cove.app`; release build, strict signature verification, connected session restoration, and compact Hub/inbox/Contacts directory/assistant/Calendar/agent preferences/compose/onboarding/Settings checks passed on the earlier baseline | Full VoiceOver interaction checks |
| Supplied designs | Original five PNGs re-opened; later HTML references preserved; native primary screens inspected | Thread-aware sources are verified; remaining Calendar refinements and verification limits are tracked in GOAL_AUDIT.md |
| Direct Gmail | Live browser OAuth, initial download, history persistence, authenticated cache refresh, and one explicitly approved self-test send/delivery passed | Other live Gmail mutations and broader send-error handling remain unverified |
| Fast local database | Per-account SQLite; atomic snapshot/cursor commits; local drafts, decisions, preferences, and events persisted | Targeted writes measured about 0.03 ms at 5,000 synthetic messages; see PERFORMANCE.md |
| Jev agent | Live automatic processing persisted structured decisions and excerpts; live assistant selected the correct event-date passage and declined an unrelated question; mocked contract and extraction tests pass | Broader quality evaluation across different messages and question types |
| Google Calendar | Live primary-calendar read persisted 49 events; parsing, pagination, creation, overlap, and clipping have automated coverage | Live Calendar mutations remain unverified |

Credentials are configured locally and no longer block read-only integration verification. One prepared self-test email was explicitly approved, sent once, and verified in Sent and Inbox; see the approved-send milestone below. Other live remote mutations remain outside verification. The initial Jev authentication smoke test used synthetic text; authorized automatic organization has since processed a newly arrived email. These checks do not establish full end-to-end coverage of every product action.

An earlier baseline passed 136 automated checks: 102 core tests, 6 native WebKit rendering tests, 6 app-state polling tests, 7 Calendar workflow tests, 7 thread-answer workflow tests, and 8 send-workflow tests. That release built and passed strict code-signature verification; later milestones below record subsequent checks. Sample-data captures are in `docs/screenshots/`; private live-account captures are not added to the repository. QA mode uses separate database storage and a separate Keychain service.

## September 22: connected verification and text decoding

Google sign-in, Gmail download, Calendar read, and Jev authentication succeeded using the user's locally configured connections. Reopening the updated app restored the saved account without asking for login again.

A live message declared ISO-8859-1 despite containing valid UTF-8 bytes. Its Gmail snippet corroborated the UTF-8 reading. The decoder now accepts that correction only for Latin-1/Windows-1252 declarations with a sufficiently informative matching snippet; genuine legacy encodings and uncorroborated cases retain their declared decoding. A versioned, one-time full-body refresh also updates older cached messages. The migration commits with the mailbox snapshot and preserves local drafts and decisions. Live cache verification confirmed decoding version 2, corrected accents, and removal of the observed garbled form.

Regression coverage includes misleading charset headers, genuine legacy text, absent or mismatched corroboration, full refresh despite a valid history cursor, local edit preservation, decoding-version persistence, and transaction rollback.

## September 22: login and unselected inbox

Without a valid saved Google session, normal startup opens the login screen. A cached account name alone cannot bypass sign-in. The `--sample` startup flag only applies with `--qa`; users can still explicitly choose the sample inbox on the login screen.

The dedicated no-selection export is implemented. Native QA confirmed Down selects the first email, a second Down selects the next, Up returns, Escape clears selection, and a row click opens the correct filtered result. Arrow keys inside search leave the reader unselected. Screenshot: `docs/screenshots/inbox-unselected.png`. Agent Hub and selected reading pane rendering also passed. Accessibility reads work again.

## Remaining verification and product limits

- One approved live self-test verified sender identity, delivery, and draft-to-sent reconciliation. Other real-mail mutation paths and remote API failure cases still require broader verification.
- Sample chat scope switching, source navigation, native attachment Save, and a live Jev date question/no-answer pair pass. Broader answer quality remains unverified; live Gmail attachment saving was verified in a later milestone, and uploads are not implemented.
- Google account identity and refresh credentials use one atomic Keychain record. Failed replacement preserves the prior session, and stale refresh responses are rejected; seven regression tests cover session persistence and failure cases.
- Snooze views refresh every 30 seconds while Cove is open. Database-load failure clears stale account state.
- Jev provides structured decisions and source excerpts; deterministic templates remain available. The current expansion adds opt-in generative providers for writing and answers, with live provider verification pending.

See README for the full product limits and PERFORMANCE.md for storage measurements.

## September 22: formatted reader and mailbox questions

The reader preserves the decoded HTML body separately from searchable plain text. A WebKit view renders paragraphs, headings, lists, tables, links, and sender CSS; inline CID images are retrieved from Gmail. The document uses ephemeral storage and disables message scripts, forms, embedded frames, and remote styles. At this milestone, external images loaded only after a per-message click. The current expansion also provides global reading options, described below. The plain-text toggle is available for HTML mail. Cache version 3 automatically fetched HTML for existing messages; the connected cache contained 60 HTML messages after refresh.

Native verification with a newsletter confirmed styled text, original spacing, image placeholders before opt-in, visible logo/hero images after opt-in, and switching to plain text and back. Live captures remain outside the repository.

The assistant opens from Agent Hub in Mailbox scope. Unread and supported folder-count questions use Gmail's label/profile statistics, including when asked from a selected email. Responses identify live Gmail counts; unavailable-live fallbacks explicitly describe partial downloaded counts. Sender/date/topic filters and ambiguous multiple-folder counts are refused rather than silently returning a different total. Single-email Jev passage questions retain explicit email scope.

The user's exact question, “how many unread emails”, was entered in the packaged app. It returned 129 unread messages from Gmail's Unread label with a live-check timestamp, without an unrelated email card or Jev attribution. No message send or remote mailbox mutation was performed for this verification.

WebKit regressions verify formatting, disabled active content, embedded CID images, stable viewport-based height, and actual network behavior with an independent loopback server: no image/frame requests before opt-in, an image request after opt-in, and frames blocked throughout. All six renderer checks passed with no skips.

## September 22: Jev-only automatic organization

Automatic organization is enabled for the connected account. Cove checks Gmail about every two minutes while open and processes incoming mail received from activation onward. Historical mail, outgoing mail, drafts, trash, spam, and messages with saved decisions are excluded from automatic processing. Older incoming mail can be organized explicitly from Your agent. Activation and decisions persist across restarts; transient per-message failures have a cooldown, and account/authentication/network-wide failures stop the batch.

The reader displays category confidence, reply-or-action likelihood, urgency within 24 hours, and a verbatim selected passage. This earlier Jev-only milestone supplied structured assessments and source selections. Generative providers are now a separate opt-in feature, documented below. One classification request combines these assessments. Input passages share 24 KB of UTF-8 text, and enabled instructions/memories share 8 KB; long messages can be partially assessed.

Live verification observed the first sync after activation, another sync two minutes later, and one newly arrived newsletter automatically organized with a persisted Jev model response. Historical decisions were retained without a backlog classification run. A malformed plain-text alternative exposed sender HTML in the selected passage during this check; decoding version 4 refreshes the body and repairs an existing passage only when its readable text is corroborated by the refreshed body. Saved assessments and local drafts survive the refresh.

The final release passes all 86 checks (80 core, 6 WebKit) and strict code-signature verification. Its restart reached a macOS login-keychain authorization dialog for the rebuilt app. After local approval, live cache verification confirmed decoding version 4, automatic organization still enabled, three newly received messages assessed, and two clean source-matching excerpts.

## September 22: stable development signing

Repeated Keychain prompts were traced to `codesign --sign -`: the old designated requirement was an exact code hash, so rebuilds changed Cove's trusted identity. The build script now selects the single installed Apple Development identity or accepts `COVE_SIGNING_IDENTITY`; ambiguous/missing identities require explicit configuration. Ad hoc signing is an explicit QA opt-in. The rebuilt bundle passes strict verification and has a certificate-based designated requirement for `ai.cove.mac`, with no build hash. Existing credentials may require authorization for this new identity on its first launch; choosing Always Allow in Cove's Keychain dialog persists access for that item. Subsequent native launches of the reader-attachment and responsive-assistant builds restored Gmail and used the saved Jev key without another Keychain prompt.

## September 22: Contacts and backend plan

Contacts is implemented from the supplied export: compact navigation, exact wave artwork, search/sort, favorites/groups, local create/edit, contact details and recent conversation links. Per-account contact records are separate from mailbox snapshots. Mail-derived contacts use incoming senders and outgoing To recipients, deduplicated by normalized email; Google Contacts, CC/BCC enrichment and generated relationship summaries are not implemented. Calendar opens the existing calendar, and Email opens a draft for review.

All 92 automated checks passed (86 core, 6 WebKit), including six new contact tests. The release bundle builds with the stable development identity and passes strict signature verification. Native sample QA at 1420×920 verified the directory, selected detail, empty search with selection cleared, creating and persisting a local contact, and opening a draft with that contact’s email prefilled. No email was sent. Screenshot: `docs/screenshots/contacts.png`. Compact window sizing and Google Contacts synchronization remain outside this verification. A separate sample app was used, leaving the connected production process running. Reopening the packaged Cove app loads the new Contacts page.

`docs/BACKEND_PLAN.md` now uses the user's preferred PlanetScale Postgres + Cloud Run, with Pub/Sub, Cloud Tasks and an encrypted recent-body cache. The personal pilot targets one PS-5 single-node branch, reference price $5/month; confirm region/configuration price before deployment. Included storage, backups, egress and pooling are documented, with Jev and Google costs separate. `docs/DATABASE_RESEARCH.md` retains eight SQL hosting options and free-tier alternatives. The earlier $8–30 estimate remains an alternative paid-Neon scenario. Planning only: no backend was deployed, and no mail was uploaded to a Cove server.

The user selected SQL over Firestore. The revised plan includes relational tables/joins, transaction-safe device revisions, row-level security and pooled-connection isolation, plus updated Postgres cost scenarios. No infrastructure was provisioned.

## September 22: independent Gmail polling and PlanetScale connection

Gmail polling no longer depends on the automatic Jev toggle. Connected mailboxes check for new mail about every two minutes while Cove is open; AI remains opt-in. Manual refresh resets the poll interval, failed attempts wait two minutes before retrying, older-page downloads do not delay new-mail checks, and a backward wall-clock correction cannot freeze polling. Sample, disconnected, busy and cancelled polling paths do not start sync. The preferences copy now explains that turning Jev off leaves Gmail synchronization active.

Six AppStore integration regressions use an injected Gmail transport, temporary SQLite database and clock, without Keychain access or real email. They verify new mail and its cursor persist with Jev disabled, retry/manual timing, excluded states, clock changes and older-page behavior. All 98 checks pass. The release bundle builds successfully and passes strict code-signature verification. This polling change has not been timed against a live mailbox with Jev disabled.

PlanetScale MCP authentication and read-only discovery succeeded. The user's `cove` database is PostgreSQL in AWS us-east-1, ready, with one `main` branch. Branch inspection confirms PS-5 ARM, zero replicas, gp3 storage, a 10 GiB minimum disk and storage autoscaling; the database listing reports zero tables. No schema or mailbox data was written. Backend implementation/deployment and mobile synchronization remain outstanding.

## September 22: assistant sample flow and reader attachments

The email reader now lists attachments beneath the message body, with filename, optional file size and an accessible Save button. It uses the same native Save dialog and download path as Agent Hub, disables saving while busy, and captures the source message when the button is pressed. Messages without attachments show no attachment section.

An isolated packaged sample app verified opening chat from Hub in Mailbox scope, answering the unread-count shortcut, choosing Maya's email, displaying an explicitly labeled sample source response, and overriding email scope for the exact question “how many unread emails.” Open email navigated to Maya's message. These checks establish the sample UI flow, not live Jev question-answer quality.

Native Save from both Hub and the new reader row produced 257-byte files matching the sample fixture exactly. Cancelling Save restored an interactive reader, and navigating to the next message removed the previous attachment row. All seven attachment regression tests pass, and the updated release builds and passes strict signature verification. Test files were saved only under a unique temporary directory; no real email was sent, uploaded or modified.

## September 22: live passage answers and compact assistant

The connected assistant answered an event-date question by selecting the original newsletter paragraph containing the day and time. An unrelated question correctly returned no confident answer. The no-answer footer previously implied a passage had been selected; responses now carry explicit provenance, displaying “Jev checked this email · no matching passage” for that outcome. The corrected footer was verified with a live request after rebuilding.

The assistant now measures its parent window and caps its size at 752×800 with 48 points of available space reserved around it. Native sample QA used macOS quarter-screen tiling at approximately 1040×730: the modal stayed inside the window, its header/composer/footer remained visible, and submitting an unread-count question worked. The compact Hub, selected inbox reader, and Contacts directory were also inspected. This is not a complete accessibility or all-screen sizing audit.

All 98 tests pass (86 core, 6 WebKit, 6 polling), with no skips or failures. The release builds and passes strict signature verification. Live verification used the user's existing Gmail/Jev connections; no mail was sent or remotely modified, and no Cove backend upload was added. Sample QA was closed afterward.

## September 22: send preservation and Calendar editor

Sending previously cleared a reply or deleted a composition draft unconditionally after Gmail returned, including text edited while the request was pending. The send flow now captures the submitted fields, preserves newer edits, and only closes/clears the matching editor content. The local Sent message and draft transition are committed together. Rejected sends retain drafts; timeouts and server-side failures explicitly ask the user to check Gmail Sent before retrying. If Gmail accepted the message but local storage fails, Cove reports that it was sent and warns against resending.

Eight AppStore integration tests use temporary SQLite databases, a fake credential provider, and mock HTTP with controllable in-flight responses. They cover successful persisted sends, rejection, timeout/server-failure ambiguity, duplicate clicks, concurrent composition/reply edits, unchanged reply cleanup, sample-only sending/header validation, and storage failure after acceptance. Existing polling tests use the same injected Gmail credential seam. No real email is sent by tests.

Native compact Calendar QA exposed stale state on the first presentation of an existing event: its fields appeared, but the action read “Add event” and was disabled. Calendar now presents one identifiable editor draft with the event identity and initialized fields. Native verification edited a sample title, confirmed the same ID and start/end times with 10 events before and after, reopened it, and restored the original. A subsequent new-event sheet had an empty title and fresh dates. Calendar, event details/editor, agent preferences and compose were inspected in the compact sample window. A Unicode sample composition was saved through the UI and verified in the local Sent folder and SQLite; no Gmail send or remote Calendar mutation occurred.

The full suite passes 106 checks. After the final send-status wording adjustment, the eight affected workflow tests passed again. The signed release build succeeds. Live send/Calendar-mutation verification is still outstanding.

## September 22: reference audit and accessible writing controls

`docs/GOAL_AUDIT.md` compares each original image and later user instruction with the current source, native behavior and test evidence. It identifies substantive remaining Calendar and thread-aware assistant gaps instead of treating the current screen set as complete fidelity. Generated writing in the early mockups remains outside the user's later Jev-only scope.

Signed-out sample QA at approximately 1040×730 confirmed the login screen, visible footer actions, fully visible connection sheet (now Settings), and explicit entry into sample mail. No credentials were entered or changed. Message/reply editors now expose their purpose as accessibility labels; icon-only close/discard/week-navigation/instruction/memory actions also have explicit labels. Native accessibility reads confirmed the two writing fields, connection close, reply discard, week navigation and instruction removal. This is an accessibility-tree check, not a claim of complete VoiceOver testing.

The release rebuild and strict signature verification pass. These label-only changes were verified through the native app; no new automated tests were added. The most recent functional suite remains 106 passing checks. Sample QA was closed after inspection.

## September 22: Calendar navigation, agenda and availability

Calendar now shares selected-date state between a Monday-first month navigator, week grid, day agenda and context-sensitive New event/⌘N action. Weekend selection reveals the full week. The agenda includes all-day and overnight events and reports scheduled duration without double-counting overlapping meetings. Calendar visibility filters the grid/agenda; all saved busy events still constrain focus suggestions. Google event descriptions are rendered as plain text with location and attendee response details.

Focus suggestions find a future 1–2 hour gap between 9 AM and 5 PM, aligned to quarter hours, and open an editable draft. Google suggestions require a successful persisted sync covering the whole day, no active/erroring sync, and a snapshot less than five minutes old. Transparent and self-declined events do not block availability. Coverage is invalidated before remote mutations. Calendar refresh now waits for active work rather than being silently dropped; cancelled, superseded, failed or storage-rejected responses cannot publish availability. Local event edits preserve metadata and report storage failure without claiming success.

Automated checks cover month/DST boundaries, overnight and overlapping events, rounding including fractional seconds, free/busy decoding, delayed and failed syncs, cancellation, stale coverage, persistence failures and contextual commands. Native sample checks at 1040×729 verify selected dates, ⌘N defaults, focus draft times, weekend/workweek navigation, month browsing, metadata display, and hiding/revealing calendars. No live events were created, edited or deleted for these checks. Logs: `/tmp/cove-calendar-agenda-tests.log` and `/tmp/cove-calendar-agenda-build.log`.

The final signed production build was reopened and restored the connected account without a Keychain prompt. A live primary-calendar refresh transitioned from “Syncing calendar…” with unavailable focus information to the completed Sync calendar state and a calculated interval. Read-only inspection of the account cache confirmed 52 events carrying availability metadata, with guest details on 32. This verifies live reading/decoding/persistence; no Calendar write was performed. The app is left open on Calendar. Temporary metadata added to isolated QA fixtures was restored afterward.

## September 22: thread-aware Jev source selection

The assistant scope picker now supports Whole thread alongside This email and mailbox counts. A thread question reads Gmail’s `threads.get` full payload, merges refreshed messages with the latest local draft/decision/snooze state, and saves the snapshot without advancing the mailbox history cursor or pagination. Thread reads wait for active mailbox work; cancellation stops before persistence or model calls. A failed Gmail refresh uses only cached thread messages and labels that limitation. A storage failure stops the request instead of presenting unpersisted source links.

Jev receives one request with independently scoped Choice questions for each included message. Passages share a 24 KB UTF-8 budget, 100 candidates and a 20-message ceiling, with round-robin allocation and the selected email retained in long threads. Drafts, Spam, Trash and unsent local messages are excluded. Confidence-gated valid choices yield up to three verbatim passages, each linked to its actual message. Source coverage and input omissions are disclosed. Empty source text makes no Jev request. The answer contains fixed UI copy and original quotations, not generated synthesis.

Native compact QA verified a three-message sample conversation, source navigation to the correct Sent message, explicit sample labeling, and mailbox count override. The check caught and corrected an overly conservative input-limit notice caused by blank lines. The scope picker now shows message dates to distinguish repeated subjects. Long answers scroll to their beginning after completion. Temporary sample fixtures were restored after testing.

The final signed app restored the connected account without a Keychain prompt. A live two-message invitation thread returned the event date/time from both messages; read-only cache checks confirmed two distinct message IDs in one thread and exact passage membership in both original bodies. An unrelated question returned no confident matching passage. No live emails were sent or Calendar events mutated. Automated tests also cover invalid IDs, malformed/low-confidence choices, payload bounds, new source persistence, in-flight draft edits, offline fallback, cancellation and database/model failures. Logs: `/tmp/cove-thread-tests.log`, `/tmp/cove-thread-core-tests.log`, `/tmp/cove-thread-build.log`.

## September 22: Calendar search and focus preview

Calendar’s search button and ⌘F open a keyboard-focused search of cached titles, notes, locations and guests. Matching ignores case/diacritics and accepts multiple terms. Ongoing/upcoming events precede recent past events; the list shows at most 50 with a refinement notice for larger results. The scope is explicitly saved events, including Google weeks synced on this Mac. Selecting a hidden result reveals its calendar, selects its day/event, switches to Week for a weekend, and scrolls the time grid to the event. Empty results and Escape dismissal were checked natively. A focus-binding conflict in the shared field style was corrected so ⌘F accepts typing immediately.

Computed focus intervals now appear as outlined Suggested blocks in the selected day’s grid. They use the same recent-sync availability guard as the agenda and never enter persistent storage until the user confirms the editor. Native isolated QA proved no preview was saved, then confirmed exactly one 90-minute local block with the expected start/end. The saved event became selected and the next proposal moved to another gap. Temporary fixtures and the confirmed test event were restored after QA.

The compact native check verified guest/location search with an accented location, navigation to a 7 PM weekend event in a different month, hidden-calendar selection, and empty results. The header now follows the selected date’s month when a week crosses a month boundary. All 136 tests pass; the release build passes strict signing. Logs: `/tmp/cove-calendar-search-tests.log`, `/tmp/cove-calendar-search-build.log`.


## September 22: local Calendar groups

Work, Personal and Focus time now appear under “On this Mac” in Calendar’s sidebar. Event membership is persisted in the per-account SQLite cache; legacy events decode as Personal without rewriting their titles or other metadata. The event editor can move local events between groups, ordinary new events default to Personal, and reviewed focus suggestions default to Focus time. Google’s primary calendar retains its separate source and visibility control. Visibility filters reset on account changes and do not affect availability calculations.

Search includes hidden groups, names each source and reveals only the selected event’s group. Successful local saves similarly reveal the destination group. Hiding the selected event’s calendar returns the detail panel to the day agenda. Native compact QA verified a Product sync event moved to Work, disappeared when Work was hidden and reappeared on search selection. A reviewed Wednesday 09:30–11:00 focus suggestion saved exactly one event with Focus membership; hiding it kept the next available suggestion at 12:00. A normal new-event editor still defaulted to Personal. SQLite checks confirmed both memberships, then the isolated sample fixture was restored exactly.

All 138 tests pass (102 core and 36 app/rendering workflows), including new coverage for moving calendar membership, persisted destinations, legacy decoding, independent visibility/search reveal and hidden busy intervals. The release build passed strict signing and reopened with the connected account and all three local groups alongside Google primary. Logs: `/tmp/cove-calendar-groups-tests.log`, `/tmp/cove-calendar-groups-build.log`. No live email sends, Google Calendar writes or cloud uploads were performed.


## September 22: Jev questions across downloaded conversations

The assistant’s default mailbox scope now accepts source-passage questions across downloaded mail, alongside live Gmail counts. Candidate selection runs off the main actor against a mailbox snapshot. It scans complete eligible cached bodies, matches case/diacritic-insensitive question words in headers and body text, and ranks by word overlap with recency as a tie-breaker. At most 20 messages and 24 KB / 100 passage options reach Jev in one request. Each body retains at most 24 candidate windows locally. Overlapping windows preserve neighboring lines and words across boundaries; useful late-body details can outrank opening text. Candidate overlap does not itself establish an answer: Jev still chooses an original passage or none for each message. The source footer states actual messages checked and input omissions.

One common bounded passage collection and Jev selection implementation now serves both thread and downloaded-mail scopes. Downloaded-mail requests do not fetch Gmail, modify cached messages, change the history cursor or advance pagination. Drafts, Spam, Trash and local unsent IDs are excluded; local reply text never enters model input. Cancellation and account-generation checks prevent stale responses. Sources removed, trashed or changed during the request cannot become answer cards. Sample mode explicitly previews passages without provider calls. Long source quotes display up to eight lines with accessible expansion/collapse controls; copying still includes the complete selected passage.

Automated checks cover old messages beyond the newest page, late-body answers, Unicode/input bounds, adjacent date context, deterministic recency fallback, unrelated conversation metadata, correct original-source choices, private draft exclusion, cache/cursor preservation, no-match/model failures, cancellation and changing sources. Native compact QA verified the downloaded scope, three distinct sample source cards, original-message navigation, scope switching, live-count routing override and passage expansion/collapse. No sample fixtures were injected. Live Jev accepted 20 candidates out of 138 eligible downloaded messages, selected an original invitation’s date/time passage, and declined an unrelated washing-machine serial-number question. The response explicitly limits its conclusion to downloaded text checked. No live email was sent, no calendar event was written, and no mailbox data was uploaded to PlanetScale.

All 148 automated tests pass (107 core and 41 app/rendering workflows). The final release build passes strict signing. Logs: `/tmp/cove-mailbox-passages-tests.log`, `/tmp/cove-mailbox-passages-build.log`. The goal remains open pending the broader completion audit; bounded retrieval is not a claim of exhaustive Gmail coverage.


## September 22: real attachment download and populated-memory QA

A connected Gmail message with an attachmentId and no embedded attachment bytes was opened in the reader. Save Summary.pdf presented the native Save panel; the app downloaded the attachment to a private temporary directory. The result was exactly 269,165 bytes, matching Gmail metadata, with a `%PDF-` header and `%%EOF` ending. The temporary test copy was then removed. No document content was opened, no live mail was sent, and the source was already read.

Populated native preference QA exposed a real bug: replacing a memory while its old text matched an active search removed its row on the first keystroke. AgentView now retains the focused memory row until editing ends. Native verification reproduced the old failure, then typed a complete replacement character by character with focus intact in the fixed build. On Tab, filtering resumed and showed No matching memories; clearing search revealed the complete edited value. Forget/Undo restored that value, and reopening the isolated sample app restored both it and a changed memory opt-out. The original sample preferences were restored byte-for-byte after closing QA. Memory fields, New memory, Search memories, New instruction, sign-off, Undo and dismissal now have explicit accessible names.

The signed release was rebuilt and reopened successfully. All 148 tests pass again; logs are `/tmp/cove-memory-edit-tests.log` and `/tmp/cove-memory-edit-build.log`. Current architecture documentation now describes thread and downloaded-mail source selection. Full VoiceOver use is not claimed by these accessibility-tree/keyboard checks.

A single real-account draft was prepared locally, addressed to the connected user, to test Gmail sending/delivery after explicit approval. Subject: Cove Gmail verification - 22 Sep 2026. Body: This is a one-time test from Cove to verify Gmail sending and delivery. No reply is needed. SQLite and the native composer confirm the exact contents and DRAFT state; the draft has not been sent. Review metadata is stored locally at `/tmp/cove-live-send-review.json` for verification before any approved action.


## September 22: approved live send and completion audit

The user explicitly approved the prepared self-test email. Before sending, outgoing MIME was corrected to include the connected sender in From and a standard Date header. Long UTF-8 subjects now fold into independently decodable RFC 2047 encoded words without splitting Unicode scalars. New tests cover fixed-date output, invalid sender/header injection, empty subjects, long multilingual subjects and pathological combining sequences. All 150 tests pass (109 core and 41 app/rendering workflows), and the final release build passes strict signature verification. Logs: `/tmp/cove-origin-headers-tests.log`, `/tmp/cove-origin-headers-build.log`.

The existing draft was reopened in the final signed app and its recipient, subject and body were checked against the approved text. Send was clicked exactly once. Cove reported Email sent, removed the original local draft and displayed the test in Sent. After Gmail sync, Inbox also displayed the same test; the cache contained exactly one matching Gmail message with SENT, INBOX and UNREAD labels. The recipient and body matched the approved draft. No additional message was sent. Local verification evidence is `/tmp/cove-live-send-result.json`.

The completion audit in GOAL_AUDIT.md now closes the requested local-app scope. Full VoiceOver navigation, other live Gmail mutations, live Calendar writes and broader model-quality evaluation remain verification limits. Cloud hosting/mobile synchronization remains a separate phase; only planning and the PlanetScale connection were requested and completed. No mailbox content was uploaded to PlanetScale.


## September 22: local security hardening

The current app now encrypts every real-account SQLite record with CryptoKit AES-256-GCM and account/record-bound authentication. A random per-account key stays in Keychain, with insert-only creation and persisted read-back to avoid concurrent-instance key replacement. Missing/corrupt keys fail closed. Migration is transactional, verifies legacy JSON and checkpoints/compacts active storage; interrupted cleanup resumes on startup. Symlink stores are rejected, temporary SQLite storage is memory-only, and both existing and newly created sidecar files receive owner-only permissions. Synthetic tests cover data/draft preservation, key loss, account/record swaps, tampering, rollback, cleanup restart and removal.

Networking now requires HTTPS and uses an ephemeral session with no caches/cookies/credential storage. Redirects are denied, including POST redirects; tests verify no secondary request. Startup removes this app bundle's old networking caches. Email image opt-in permits HTTPS only and uses no-referrer; native WebKit request-probe tests verify plain HTTP remains blocked. The build uses stable signing with Hardened Runtime enabled.

The connection sheet (now titled Settings) explains TypeSafe processing/retention, links its privacy policy, explains local encryption and provides an explicitly confirmed Remove local data and disconnect action. Removal clears the device connection and local records without provider requests; ordinary disconnect preserves the encrypted cache. Destructive workflow tests use synthetic mail only. A native real-account check opened the warning and cancelled, preserving the account and draft.

All 165 tests pass (123 core, 42 app/rendering). The signed release migrated the real mailbox, restored its existing draft, synced normally and reopened without another Keychain prompt. Read-only checks found encrypted envelopes on every current record, successful SQLite integrity, preserved original record names, 0600 database/WAL/SHM modes, no tested plaintext markers and no remaining legacy network-cache files. No additional live email was sent. Details, evidence paths, recovery behavior and remaining limits are in SECURITY.md. This is implementation hardening, not an independent security certification or zero-retention claim.


## September 22: current expansion for 0.1.2 (build 4)

Implementation is in the current worktree. This section does not claim a final test total, finished native audit, or signed/notarized 0.1.2 artifact. The prior live Gmail/Jev checks do not establish live verification of the new generative providers.

### Contacts and Home

People now routes to the existing Contacts directory, with All contacts selected. The directory still combines manually saved records with senders and outgoing recipients from downloaded mail, without requiring Jev classification. An empty directory offers Sync Gmail, and sorting uses the shared Cove menu control. Google Contacts synchronization remains unimplemented.

Home’s priority rows open emails across the full clickable row and show compact dates, instead of reserving width for Review email buttons. The two-column layout has one continuous separator, while compact widths stack its sections. Keep in touch uses the new `KeepInTouch` helper: only Jev People/Work decisions with confidence at least 0.7 qualify, and Gmail promotion/update/social/forum labels, list/unsubscribe/automation headers, and no-reply sender patterns exclude messages. Each sender’s latest incoming message must qualify; own addresses, future dates, Drafts, Spam and Trash are excluded. This reduces false suggestions but is not proof that every remaining sender is a person.

Gmail parsing stores only an optional bulk/automation boolean, not the raw header values. Decoding version 5 refreshes existing downloaded content while preserving decisions, drafts and snooze. Older messages without the signal are excluded from suggestions until refreshed. Existing sample fixtures gain only missing metadata through the sample migration. Eleven scoped contact/filter tests passed, including six existing directory tests and five new eligibility/header/legacy-preservation tests; the log is `/tmp/cove-contacts-isolated-tests.log`. This scoped result is not the final full-suite count.

### Reading and shared controls

Settings replaces the connection-only title and includes Text-only reading and Load external images automatically. Both options default off and persist on this Mac. Text-only mode suppresses images and sender layout; the reader can still show original formatting per message. Automatic external images applies to HTTPS images in formatted mail, with the existing per-message action retained. Plain HTTP and active content remain blocked. The UI explains that image requests can reveal message opens to senders.

Unread list items use a visible unread dot and stronger sender/subject typography. Shared monochrome Cove switches and menu pickers replace the inconsistent default controls on the updated surfaces. Native interaction, compact-layout, and accessibility verification belong to the final expansion audit.

### Providers and Integrations

The Integrations page provides OpenRouter, OpenAI API and Anthropic key entry, Keychain save/remove, provider selection, model catalog loading, and saved exact model IDs. ChatGPT subscription uses a separately installed official Codex CLI through its local app-server, with an explicit browser sign-in and a separate Cove configuration/authentication context. The app offers executable selection and installation guidance. The bridge does not reuse credentials from the main Codex app, exposes no mail-send action to the model, and configures isolated, tool-disabled requests. A real subscription connection and live generative requests have not been tested; account/model availability and usage limits are not guaranteed by mocked contract checks.

Compose/reply offers generated writing and refinement, editable results, and an explicit Use draft step. Sending remains a separate action. The assistant has an opt-in model mode for generated answers and summaries, distinct from Jev’s source excerpts. Provider requests carry a bounded instruction/current draft and at most 20 emails with a shared 48 KB body budget. These requests use the user’s provider account and its data/usage policies; Jev continues inbox classification and source selection. No shared paid AI backend has been deployed.

AI-assisted Gmail search generates an editable query from the user’s request without attaching email bodies. Search Gmail is a separate user action, fetching up to 20 messages outside Spam/Trash/Drafts. Results are stored locally; a later AI question may send its selected context. Search is bounded and does not imply that the model searched the entire mailbox. GitHub remains visibly deferred: no OAuth connection or GitHub API implementation is included.

### Calendar

The current week grid draws a small current-time line and dot on today’s visible column, updated every minute. The day-agenda divider supports dragging and focused left/right arrow adjustment. Width is persisted locally and bounded against the available layout so the calendar remains usable. Existing event creation/editing/deletion controls remain explicit; this expansion does not add live Google Calendar write verification.

### Expansion verification and delivery

0.1.2 build 4 completed: **190 tests passed** (140 core, 50 app/rendering), zero failures, followed by universal arm64/x86_64 Developer ID builds. Native QA covered wide/compact Home, People/contact routing, full-row email opening, clear unread rows, reading switches, AI setup/drafting entry, persisted calendar resizing and current-time marker. See [the requirement audit](APP_EXPANSION_AUDIT.md).

Both app and `dist/releases/Cove-0.1.2.dmg` are notarized, stapled and accepted by Gatekeeper. The app is installed in `/Applications/Cove.app` and reopened with the existing Gmail account; People displayed 131 real contacts. Integrations is ready for locally entered provider credentials. New-provider live generation and ChatGPT browser sign-in remain user-controlled and unverified.

## ChatGPT Keychain fix — 0.1.3 build 5

User browser login revealed that the 0.1.2 outer helper sandbox denied Keychain storage and triggered macOS “Keychain Not Found.” Read-only inspection verified the login keychain exists. Reproduction with a disposable keychain confirmed the denied access. The fix resolves the default keychain through Security.framework and permits its encrypted database plus atomic-save and lock files only, preserving filesystem restrictions elsewhere and OS item access controls. There is no keychain reset or plaintext-token fallback.

All 9 focused provider/sandbox/ChatGPT lifecycle tests pass, including a new real Security.framework credential persistence regression via the macOS security CLI and checks that unrelated files remain inaccessible. The disposable keychain was removed and the original user search list verified unchanged. Both release architectures compile. Log: `/tmp/cove-keychain-fix-tests.log`. Final user browser sign-in must be retried after installing the update.

0.1.3 is installed in `/Applications/Cove.app` and accepted by Gatekeeper. App notarization: `e62684d9-a88a-4f51-9b19-5c681389459e`; DMG notarization: `6ee73bdc-c38c-428a-8000-122dba953e1c`. The updated app is open on ChatGPT subscription setup; Check connection starts the corrected helper without the missing-keychain alert. The failed previous browser attempt did not persist credentials, so the user must retry sign-in.

## Connection-check feedback — 0.1.4 build 6

Check connection previously refreshed the same account-state label, so a successful check looked inert. It now shows Checking… while in flight and a timestamped sign-in confirmation next to the button afterward, or clear sign-in guidance when no account is stored. Model loading reports the returned count or empty result, and connected accounts without a saved model receive the next setup steps. Save model is disabled during provider operations. Universal signed release builds pass; native confirmation is verified after installation. This check reports stored ChatGPT sign-in status, not a successful paid model generation.

0.1.4 build 6 is installed and accepted by Gatekeeper. In the running app, the completed connection check displayed “ChatGPT sign-in confirmed at 9:22:33 p.m.” and the saved model remained `gpt-5.6-sol`. This also verifies the previous Keychain fix through a persisted real ChatGPT sign-in after restart. App notarization: `2c582de0-ee9a-4141-aead-fda5f7360c56`.


## Full-page Settings — 0.1.5 build 7

Settings now replaces the main-window content rather than opening a sheet. The dedicated sidebar, Gmail/Jev/Reading sections, and responsive voice/privacy preview follow Pen frame QC7XX in Cove.pen. Cmd-comma, the account button, sidebar Settings, and sign-in connection settings use the same destination. Returning from Settings restores the preceding screen; signed-out users return to sign-in. Integration navigation remains available for an entered mailbox.

The page preserves explicit Keychain credential saving, reconnect/disconnect, Calendar authorization, confirmed local erasure, automatic Jev organization, per-account instructions and reply-template voice, and immediate reading preferences. Unsupported label selection and automatic generated drafts are not presented as working controls. Background polling can be paused through a saved local preference; manual sync remains available.

Validation: 192 tests passed (141 core, 51 rendering), including paused polling, manual sync, and resumed polling. Native sample QA verified signed-out Settings/back, Cmd-comma from sample mail, section scrolling, compact layout and wide preview. No real credentials or provider preferences were changed during QA.

Release verification: universal Developer ID app and DMG are notarized, stapled and accepted by Gatekeeper. App submission `4f2023a2-daee-43f2-bd63-34f268f9d0f9`; DMG submission `4bfd7d7a-a412-425d-9887-91792cd78575`. Installed `/Applications/Cove.app` reports 0.1.5 build 7. The live connected app displays the full Settings page, retains Gmail and automatic Jev organization, and shows a successful current sync. The page is left open for review. Shareable installer: `dist/releases/Cove-0.1.5.dmg`.


## Settings control hit targets and collapse — 0.1.6 build 8

CoveDisclosureStyle uses explicit full-row buttons for section and nested connection headers. Gmail, Jev and Reading can be collapsed independently or together. The Settings sidebar expands its requested section before scrolling. Credential editing state remains in the parent page when a section is hidden. Shared CoveMenuPicker controls use a styled button with a selection popover rather than the macOS borderless menu label, preserving selection bindings and disabled states. Lists with more than seven choices scroll within a bounded popover.

Native isolated QA verified Collapse all, sidebar reopening Jev, Google connection collapse, TypeSafe expansion with its key field revealed, voice selection and preview update, voice persistence across restart, provider selector choices in Integrations, and Escape dismissal. Only sample preferences were changed. This UI-only update was verified by compilation and native interactions; the preceding release's 192 automated checks are historical, not rerun for this patch.

Release verification: 0.1.6 build 8 is installed, Developer ID signed, notarized, stapled and accepted by Gatekeeper; the shareable DMG is `dist/releases/Cove-0.1.6.dmg`. Final app submission `c58f296a-e404-4796-aafe-db2fe488fd4b`; DMG submission `838f5cb9-343a-4047-9f32-633e8ce897c2`. The connected installed app verified TypeSafe expansion/collapse and voice option opening/dismissal without changing credentials or voice. Settings remains open. An earlier uninstalled 0.1.6 submission was superseded to bound long model-option lists.


## Pen Integrations implementation — 0.1.7 build 9

The app follows Cove.pen frames uEb0K and ZqHkM: shared Settings navigation, exported landscape artwork, tool cards, a two-column provider choice, and separate API-key/subscription setup. Layout stacks at compact widths. Google Tasks and GitHub are marked Coming later because no connection implementation exists. Gmail, Jev and Reading links navigate to the corresponding full-page Settings section.

Provider selection is now pending until Save configuration; existing provider keys and per-provider models remain intact. Test model sends only a fixed synthetic prompt and empty email evidence using the pending provider/model, without altering saved settings. Test feedback is cleared when the model, connection or credentials change. Testing is optional and its provider usage implications are shown. Codex executable controls and detailed data-sharing copy are expandable. ChatGPT connection checks retain visible progress and timestamped results.

Validation: 194 automated checks passed (141 core, 53 rendering). New injected-transport tests verify synthetic-only test input, the pending model in the request, and unchanged saved configuration on success and failure. Native QA verified both provider layouts, compact and wide presentation, section-link navigation, and provider browsing without saving. No paid generation or real email sharing was performed for QA.

Release verification: 0.1.7 build 9 is installed. The universal Developer ID app and DMG are notarized, stapled and Gatekeeper accepted. App submission `031e776c-5109-4b31-8554-f042aa455afe`; DMG submission `82222242-ba72-4d73-ab82-bd5d103b8e57`. The live installed page retained ChatGPT as the selected provider and `gpt-5.6-sol` as the saved model; Check connection confirmed the existing sign-in. No model-generation test was sent live. Integrations remains open for review. Installer: `dist/releases/Cove-0.1.7.dmg`.

## September 22: 0.1.8 mail, Integrations, and Compose refinement

213 tests passed (141 core, 72 native/workflow), including read/sync races, account isolation, HTML wheel forwarding and long-message overflow, paginated model discovery, Unicode selection rewriting, stale-draft rejection, and editable suggestion review. Native QA showed the synthetic unread fixture become Read and wheel input over formatted body moved from checkpoints 1–10 to 26–38. Compact and wide Integrations layouts were inspected against Pen uEb0K; Collapse all and individual Writing/ChatGPT controls responded. Composer showed the split message/AI workspace, accepted typed draft fields, updated word count, and opened the explicit context picker. Review was hosted at 320 and 420 points with synthetic content, with no provider generation.

Installed signed 0.1.8 build 10 restored the Gmail account and ChatGPT sign-in. Its actual model picker returned gpt-6-astra, gpt-6-sol, gpt-6-luna, gpt-5.6-sol, gpt-5.6-terra, gpt-5.6-luna, and gpt-5.5 from the current official Codex CLI. Check connection displayed a timestamped sign-in confirmation. The existing saved model remained gpt-5.6-terra. No paid model generation or real email send was performed during these checks. Google Tasks and GitHub remain Coming later.

Apple app submission: eb9b808b-87a5-4d0c-95ef-bc9f311409ce (Accepted). DMG submission: 07ddb61e-b5bf-44d4-a325-76384e7f25f6 (Accepted). Current app installed at /Applications/Cove.app; prior bundle retained in ignored .local/app-backups.

## September 22: compose sender aliases (0.1.9 build 11)

Compose reads Gmail's configured send-as addresses with the existing gmail.modify scope. The request asks only for address, primary flag, and verification status. The From control becomes a picker when verified aliases exist; primary-only accounts retain a simple address. Refresh is available beside From. A choice is persisted using the draft's sender fields and restored when reopening. An unavailable saved alias remains visible and blocks sending until another address is selected. Failed loading permits the primary address and offers retry; it does not silently change a saved alias.

Sending a custom alias revalidates it through Gmail before messages/send. The selected address is included in MIME From, the send confirmation, and the local Sent record. Draft cleanup includes sender equality, preserving a newer sender choice during an in-flight send. Reply behavior is unchanged; this picker applies to the Compose workspace.

217 tests passed (142 core, 75 native/workflow). New regressions verify verified/unique/header-safe address filtering and minimal requested fields, durable alias selection and actual MIME From, rejected removed aliases with zero send requests, and preservation of a sender edited during an in-flight send. No real email was sent for this feature's tests.

Reference: https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.settings.sendAs/list and the SendAs resource documentation.

## 0.1.9 combined AI compose experience

The To field suggests local contacts by name/email and includes up to six recent incoming/outgoing messages for the recipients, excluding Drafts/Spam/Trash. Sender, recipients, known contact names, subject, current date/time zone, saved voice, instructions, and the actual draft enter the writing request. Users can remove context or disable automatic recipient context and lookups. Changing the envelope cancels and invalidates a pending suggestion; mailbox search results cannot accidentally invalidate the request by adding contact metadata.

Provider selection was removed from Compose and remains in Integrations. Missing provider configuration links to Settings. The working state uses an inline phase label and small accessible cancel icon. A 30fps Canvas draws 72 dotted-wave particles toward the email canvas only while a request runs. Actual returned text reveals over about 600ms in a suggestion preview; it is not represented as streamed model tokens. macOS Reduce Motion disables particles and the typing reveal. The original draft is untouched until explicit Apply; Send is disabled while a suggestion is pending. Existing stale-edit and Undo behavior remains.

WritingAgent asks the chosen provider for a structured read-only plan, validates a whitelist, executes at most three context lookups, then asks for the draft using bounded evidence. This provider-independent protocol works with the existing API providers and official Codex subscription bridge; it does not grant Codex shell, filesystem, arbitrary network, or Gmail credentials. There are no send/create/update/delete tools. Gmail searches exclude Spam/Trash/Drafts and do not mark read. Calendar requests are bounded to 31 days and two pages; repeated pagination is rejected. Calendar context is primary Google Calendar plus local events. Failures and truncation are labeled; missing availability must not be invented. Activity and used mail sources are visible. No background model requests occur.

Validation: full suite and synthetic SwiftUI hosting cover alias persistence/MIME, removed aliases, recipient-context selection, tool validation/dispatch, unavailable Calendar, cancellation, source limits, suggestion preservation, and canvas layouts. Native app-control failed with "Sky Computer Use native pipe startup failed", so this iteration's live interaction/installation verification is pending. Existing installed version remains 0.1.8 until the running app can safely be closed. No live provider generation or real email send was used for this update.

Final automated evidence for 0.1.9: 227 tests passed (145 core, 82 native/workflow). Five WritingAgent tests were rerun after isolating the planner from email bodies; context/card, alias picker, particle, canvas preview, and disabled-motion renders were inspected from synthetic captures in /tmp. The renderer preserves the original stored draft during all preview stages. Live model generation and app interaction remain unverified for this build because the native control bridge is unavailable.

Release handoff: the combined 0.1.9 build 11 is compiled for arm64/x86_64 and Developer ID signed. Notarization submission did not start: `notarytool` returned “No Keychain password item found for profile: Cove-notarization” both with the default and explicit login keychain; `dist/distribution/notary.fLo0tX/submission.json` is empty and has no submission ID. Restore that profile locally before submitting this final artifact once. Do not reuse a 0.1.8 receipt for 0.1.9. Native app-control remains unavailable and /Applications/Cove.app is still running 0.1.8; save/quit is required before replacement. There is not yet a shareable notarized 0.1.9 DMG.

A final boundary audit added account-change cancellation propagation and capped Calendar pagination coverage. The full 227-test run passed before those two additions; all 10 focused WritingAgent/WritingContext checks passed afterward (229 tests in the current suite). The planner sees the user's instruction/envelope only, so email bodies cannot steer additional searches. Verification of provider generation and the live app remains pending; synthetic rendering and workflow tests are the evidence for this build.

## September 23: restored notarization and final 0.1.9 checks

The user restored the local Cove-notarization profile; authenticated access succeeded. Apple accepted the final app submission `d788e0ab-2e2e-4e60-8c4e-30a6d3f788c7` and DMG submission `804d469b-fc92-421a-a2d3-1c585cf82781`. The full current suite passed all 229 tests (146 core, 83 rendering/workflow), including the added account-switch cancellation and incomplete Calendar pagination checks. Native app-control still reports a startup failure. The existing Cove process remains open, so installation waits for the user to save/quit; no forced termination or replacement of the running app occurred.

Installation completed after the user confirmed Cove was closed. /Applications/Cove.app is now 0.1.9 build 11. Installed app signature, stapled ticket, and Gatekeeper assessment passed; the previous complete bundle is backed up under ignored .local/app-backups. Final DMG ticket/signature/checksum/Gatekeeper validation passed and `dist/releases/Cove-0.1.9.dmg` is ready to share. The user must reopen Cove because native app control remains unavailable. No live model generation or email send was performed.


## September 23 — 0.1.10 compose and calendar update

Three requested agents implemented actual glyph-targeted dot animation, deterministic meeting availability, and clearer event separation. Root integrated credential/model-aware runtime AI controls and restored configured ChatGPT sessions. Full source audit and visual evidence: [0.1.10 audit](qa/0.1.10/AUDIT.md).

248 automated checks passed (154 core, 94 rendering/workflow), plus an opt-in live test through the saved gpt-6-luna ChatGPT subscription. The real model used one synthetic Calendar lookup and proposed the computed next-day 10:30 AM PDT slot rather than a generic ‘first available time’. No real email was sent. Scheduling defaults to 30 minutes, 09:00–17:00 unless overridden, shows scope/assumptions, and stops with an actionable error when availability cannot be verified.

Universal 0.1.10 build 12 is installed at `/Applications/Cove.app`, with previous bundle retained under `.local/app-backups`. App and DMG signed/notarized/stapled; Gatekeeper and DMG checksum passed. Installer: `dist/releases/Cove-0.1.10.dmg`. Native UI control still unavailable; hosted native views and actual provider execution verified separately. User can reopen the updated app.


## September 23 — 0.1.11 quiet waiting and scheduling follow-ups

Continuous waiting particles and the refinement spinner are removed; static progress/cancel remains and the returned-text glyph reveal is unchanged. Follow-ups now retain bounded user-request history and structured meeting parameters for the current draft. “suggest 3 timeslots” rechecks Calendar and returns three distinct options on the same day; fewer available choices are reported explicitly. The current draft stays unchanged until Apply.

254 automated checks passed (155 core and 99 rendering/workflow), plus the live saved-gpt-6-luna two-turn scenario with a synthetic calendar. Two calendar reads and four model completions produced one opening, then three dated options, without sending email. Native-hosted frames confirm static waiting and preserved finite reveal. See [verification](qa/0.1.11/AUDIT.md).

Installed universal 0.1.11 build 13 at `/Applications/Cove.app` after verifying the app had closed, preserving the prior bundle. Developer ID signature, notarization ticket, and Gatekeeper validated. Native UI control remains unavailable, so the user should reopen Cove.

Shareable `dist/releases/Cove-0.1.11.dmg` is signed, notarized, stapled and checksum/Gatekeeper verified. App receipt `fa7c271f-3a43-4acc-bb01-20eebd25d9d9`; DMG receipt `e0d3fd64-0e14-4c69-a01d-4d7d588b5c1c`.


## September 23 — 0.1.12 compose review polish

AI waiting now uses a small native progress indicator, actual phase label, and static skeleton on an empty canvas. The finite returned-text glyph reveal remains. In wide Compose, users edit the pending suggestion on the main canvas; the sidebar presents compact Apply/Keep original actions, collapsed comparison, an integrated follow-up input with prompt shortcuts, and collapsed Sources & checks. Narrow Compose and replies keep inline review.

257 automated checks passed (155 core, 102 rendering/workflow; one live provider smoke skipped). New checks cover narrow/wide review layouts, native canvas editing, and the hidden original editor relinquishing keyboard focus. Independent review findings were corrected. [Visual evidence and scope](qa/0.1.12/AUDIT.md). Native app-control remains unavailable; verification uses hosted production SwiftUI/AppKit components. Release/install details follow below.

Universal 0.1.12 build 14 is built, Developer ID signed, notarized, and stapled. App receipt: `1399be96-46c9-4d34-8183-c916029a55de`. DMG receipt: `a2fc5871-aff8-48fa-82b3-142211711e2d`. `dist/releases/Cove-0.1.12.dmg` passed signature, ticket, disk-image checksum, and Gatekeeper checks. Build log: `/tmp/cove-0112-build.log`.

Installation is pending: `/Applications/Cove.app` is still running 0.1.11 (PID 47450 at the final check). Native app control is unavailable; the user must save their draft and quit before replacement. No running app bundle or user data was replaced.

Installation completed after the user confirmed Cove was closed and the process check found no running Cove executable. `/Applications/Cove.app` now contains universal 0.1.12 build 14. Installed signature, Gatekeeper, and stapled ticket validation passed. Prior bundle preserved at `.local/app-backups/Cove-before-0.1.12-c48873c8-bd9f-476a-8cee-45a3caa65372.app`. User data and credentials were untouched. Reopening is left to the user because native app control is unavailable.


## September 23 — 0.1.13 left Apply and selected rewrites

A compact Apply draft button now sits on the left below the canvas. The wide sidebar keeps refinement and Keep original without a duplicate primary button. Native selection is shared by canvas and compact review. Selected rewrites execute and replace only the captured passage; writing shortcuts now run immediately. The original snapshot and outer rewrite scope remain unchanged until Apply. Scoped style edits bypass unrelated prior scheduling plans. The user-approved text animation is unchanged.

260 automated checks passed (155 core, 105 rendering/workflow; one live opt-in check skipped). A production-panel integration test with mocked HTTP exercises original rewrite, immediate native edit, nested Unicode selection, failed refinement, and explicit Apply. [Audit and images](qa/0.1.13/AUDIT.md).

Installed universal 0.1.13 build 15 at `/Applications/Cove.app` after verifying no Cove executable was running. Developer ID signature, Gatekeeper assessment, and stapled ticket passed. Previous bundle preserved at `.local/app-backups/Cove-before-0.1.13-a3e0b04c-2a0e-4d88-b346-63379be9732d.app`. User data and credentials were untouched. The user can reopen Cove. App notarization receipt: `cfbb098c-d9de-4c83-aec0-7c566add28f3`.

The app is fully installed and notarized. Separate DMG finalization is blocked: after app notarization succeeded, both default-keychain and explicit login-keychain `notarytool submit` returned “No Keychain password item found for profile: Cove-notarization” (exit 69). `dist/distribution/dmg-submission-0.1.13.json` is empty; no DMG submission ID exists. No duplicate upload occurred and no unnotarized 0.1.13 DMG was published to releases. Signed staging DMG: `dist/distribution/Cove-0.1.13.dmg`. The latest finalized shareable DMG remains 0.1.12. Restoring the local profile is needed only to finish the new DMG; the installed app does not depend on that step.


## September 23 — 0.1.14 model guidance and visible errors

Improved provider-independent planner examples for Gmail/Calendar/availability, raw-request isolation, fresh evidence priority, deduplication, and bounded clarification. Explicit language policy prevents Spanish context from steering a new English draft while preserving language during rewrites. Writing failures are pinned with model, reason and retry; ChatGPT preserves provider error messages and resets cleanly after timeout.

266 automated checks and two opt-in live synthetic scenarios passed with the user's saved gpt-6-sol. Combined search/availability, event recap, wording-only no-tools, English drafting from Spanish mail, Spanish-preserving rewrite, model-switch dispatch, and provider failures verified. The original user's failure was not reproduced; its exact cause remains unknown, while the silent/off-screen error path was fixed. [Audit](qa/0.1.14/AUDIT.md).

Installed universal 0.1.14 build 16 at `/Applications/Cove.app` after confirming no Cove executable was running. Developer ID signature, Gatekeeper, and stapled ticket validated. Prior bundle preserved at `.local/app-backups/Cove-before-0.1.14-0b219b90-d621-497e-b4f6-f8136d5dbca1.app`. User data, credentials and selected model were untouched. App notarization receipt: `a2c5f547-4dca-4b7d-b29e-6a01308e99fe`. The user can reopen Cove.

Final shareable `dist/releases/Cove-0.1.14.dmg` is signed, notarized, stapled, disk-image checksum verified, and Gatekeeper accepted. DMG receipt: `563fced6-f19e-47a0-bf05-4cd5983a6866`. Notarization profile was accessible for this release; the final 0.1.14 installer supersedes the pending 0.1.13 container. No remaining implementation or packaging work for this update.


## September 23: assistant calendar routing (0.1.15)

Chat now handles personal event proposals and calendar agenda questions separately from email retrieval, including when an email is selected or Gmail search is enabled. Ambiguous timing asks a follow-up. Proposals check live primary Calendar plus local event overlaps, and require Review event → Add event. Model output cannot write to Calendar. Shared Calendar save errors are visible and the injected create transport verifies persistence/no attendees. Created confirmations appear only after successful save.

275 automated checks passed (156 core, 119 app/rendering/workflow; three opt-in live tests skipped in this suite). The separate live Sol test reproduced the screenshot wording, received clarification, then prepared the correct synthetic interval after a precise reply. No real Calendar mutation occurred. Hosted production event-card rendering was visually inspected; native app interaction remains unverified because the native control bridge was unavailable previously. Evidence: `docs/qa/0.1.15/`.


## September 23: Hub ignore and email actions (0.1.16)

Keep in touch exclusions are normalized sender addresses stored in per-account Preferences. Ignore suppresses that person across future mail; Undo and the Ignored menu restore suggestions. Older preferences decode without the optional field. Ignore does not alter mail, contacts, or Gmail state. Priority cards now expose Archive/Delete and mail rows provide a context menu; Delete uses Gmail’s trash POST, never permanent deletion. Trash now uses the injected authenticated client, waits for pending read changes, and rejects stale account completions.

283 automated checks passed (156 core, 127 app/workflow/rendering; three live opt-in tests skipped). Eight Hub checks cover persistent ignore/restore, old snapshots/account isolation, archive labels, trash endpoint, failures, sample/busy behavior, stale account responses, and production Hub rendering. No real mailbox changes were performed for QA. Native app-control startup still fails; install requires the running app to close. Evidence: `docs/qa/0.1.16/`.


## September 23: Home agenda, invitations, weather and deletion Undo (0.1.17)

Home now refreshes primary-calendar events through the next 90 days, including hidden invitations. Today shows remaining events; invitations use the signed-in attendee's own response. Accept/Maybe/Decline fetch the latest event and conditionally patch only that participant, with explicit errors and no automatic RSVP. Recurring invitations target the displayed occurrence.

Weather is opt-in through macOS location permission, with manual city fallback. MET Norway receives only approximate coordinates (two decimal places) from this feature. Forecasts honor provider cache expiry/conditional requests, have a minimum automatic refresh interval, show saved timestamps and attribution, and clear on Turn off. No email or Google credentials enter forecast requests.

⌘Delete and existing mail Delete controls queue messages for five seconds, with an animated bottom Undo notification and countdown. Rapid deletions share a reset window; Undo cancels the batch. Gmail Trash is requested after the window, and failures restore the message with an error. Native text fields retain their editing shortcut. Quitting or signing out cancels uncommitted deletion requests.

297 automated checks passed (162 core, 135 app/workflow/rendering; three live checks skipped). Native hosted Home snapshots at 720 and 1100 points were visually inspected. Public-coordinate forecast HTTP smoke passed. No live mail deletion or invitation response was performed. Native app control remains unavailable; the actual location permission flow is not claimed as live verified. Evidence: `docs/qa/0.1.17/`.

App notarization accepted: `402f2a4d-1d9f-4212-9709-aaaab74ec0a7`. Installed /Applications/Cove.app 0.1.17 build 19. Strict signature, Gatekeeper, stapled ticket and universal architectures verified. Previous complete bundle: `/Users/santiagocarranca/orca/workspaces/emailclassifier/lugworm/.local/app-backups/Cove-before-0.1.17-12e7841e-8bfe-4d93-82c8-41d8ab3b784d.app`. User data and credentials untouched. Native app control remains unavailable; user should reopen Cove.

Final `dist/releases/Cove-0.1.17.dmg` is signed, notarized, stapled, checksum verified and Gatekeeper accepted. DMG receipt: `27bd4e1a-e79b-4572-8c92-8df35bf80336`. No remaining implementation, packaging or installation work for this update. Live location permission and invitation responses remain user-controlled verification limits.

## September 23: Weather recovery and Home typography (0.1.18)

Fixed the missing hardened-runtime location entitlement in production and QA signing, with a build-time entitlement assertion. Location lookup now handles authorization, temporary failures, cancellation, and bounded waiting. City lookup is visible without requiring a failed location attempt and supports cancellation and actionable errors. Apple geocoding of San Francisco California succeeded; installed Home displays saved city weather. Fresh device-location success remains unverified.

Home has shared semantic typography for primary sections, supporting sections, item titles, actions and metadata. Calendar and important mail take precedence over Weather in the compact layout. Two independent typography assessments and native renders at 720/1100 points informed validation. 300 tests passed, three opt-in live checks skipped.

Installed 0.1.18 build 20. App and DMG are notarized, stapled, and Gatekeeper accepted. Final installer: `dist/releases/Cove-0.1.18.dmg`. Evidence: `docs/qa/0.1.18/AUDIT.md`. No live email or calendar mutations were used for QA.

## September 24: Custom Jev classifiers (0.1.19, pending desktop verification/install)

Implemented Pen's Create custom agent and Your agents flow: configuration, drafts, active/paused state, duplication/deletion, search/filter, activity, inbox/sample dry runs, bounded readable attachments, Gmail label actions and uncertain-result review. Durable decisions prevent repeat evaluation on label retry. Execution follows successful new-mail sync independently of the built-in organizer, with activation cutoffs and async pause/edit/account guards. Fifteen dedicated app/core tests pass; narrow and wide screens inspected.

Universal 0.1.19 build 21 is compiled and Developer ID signed at `dist/distribution/Cove.app`. The Mac is locked (`CGSSessionScreenIsLocked=Yes`), blocking native app checks and saved-key access. Two pre-existing wheel-forwarding tests fail under this desktop condition; other tests passed. Synthetic live Jev test skipped because its runner could not access the key without interaction. Notarization attempt exited 69 before upload; profile `Cove-notarization` was unavailable, empty receipt at `dist/distribution/notary.o0Ufi9/submission.json`. No notary job is running. First recheck after unlocking; do not assume credentials need replacement. Installation/public release remain 0.1.18. User unlock request is pending. See `docs/qa/0.1.19/AUDIT.md` for requirement evidence and remaining checks.

### 0.1.19 completion after unlock

The full regression suite passed 315 checks with four opt-in live checks skipped. Both earlier wheel-forwarding failures resolved after unlocking, without code/test changes. Installed the universal, Developer ID signed, notarized and stapled 0.1.19 build 21. App notary receipt `c9ff440a-45d4-480f-b919-edc0b7811099`; DMG receipt `2e30499f-257e-4003-8303-06e97e99ca43`.

Verified the native creation screen against Pen, live Jev preview of a synthetic invoice (98% match, source passage, correct would-apply label), draft creation/edit/save, and confirmed deletion of the test draft. No real Gmail write or active custom classifier was used for QA. Blank Create an agent page is open. Final installer: `dist/releases/Cove-0.1.19.dmg`; SHA-256 `4417a5a3380343182ed9f38c01c78f7e82448c6eac9ae0d402264cfe7f9419d6`.

## Website publishing follow-up (separate from installed feature)

The local site, privacy disclosure, release checksum and installer staging are updated to 0.1.19. Public Pages remains 0.1.18. Its expired Cloudflare OAuth session refreshed successfully, but subsequent exact-item Keychain reads by the publishing helper required interaction and could not complete non-interactively. The waiting helper was terminated; no deployment was created, no upload remains running. Do not claim the public download is updated. The installed feature and notarized local installer are complete.


## September 24: Conditional agents and reply suggestions (0.1.20, build 22)

Agents now support up to eight ordered rules with label, reply draft, or combined actions. Jev selects the first matching condition; the configured writing provider prepares a reviewable reply from the triggering email and enabled readable attachments. Suggestions stay separate from existing drafts and can be explicitly applied to the original conversation. No automatic send, Calendar writes, or extra mailbox searches were added. Existing fixed-label agents remain compatible and can be converted in the editor.

Full suite: 322 passed, four opt-in live tests skipped. Added coverage for rule routing, unknown choices, old snapshots, durable suggestions, draft protection, writer failures and retry across restart without repeated label writes, and pause during generation. Narrow/wide editor and Activity screenshots are in docs/qa/0.1.20.

Installed and reopened the signed, universal, notarized app. Fin remains a saved draft with US EXPENSE for Happy Finances for All/Cherry and MX expense for Disruptive Learning/Gigstack. Live Jev routing previews using synthetic Cherry/Gigstack invoices returned the correct branches at 97%/95%. Reopening after a full app replacement verified both saved rules. No real email send or Gmail label action was used for QA. The full regression suite preceded a final copy-only Integrations disclosure correction; both architectures rebuilt successfully afterward.

Final app notary receipt: 310cb135-5918-4057-b07b-cf9a88d56945 (accepted/stapled). Final DMG receipt: 6876b6c1-6a29-49e5-991f-bf1a396325c0 (accepted/stapled/Gatekeeper verified). Final installer: `dist/releases/Cove-0.1.20.dmg`; SHA-256 `3f9e4381bafe012ff2fc14b523068fb69dd148d805bbf25f689e02aa362e4fb5`. Public website/download deployment was not part of this change.

## September 24: Inbox design, keyboard navigation and row hover (0.1.21, build 23)

Matched the updated Pen Cove inbox: compact status strip, stronger unread text, lighter read text, and distinct read/unread/selected backgrounds. Added small hover/selected-row archive, read/unread and delete actions with a 140 ms fade and Reduce Motion support. Up/Down now work across list and reader; Escape/Left return to the list. Native editable fields, modal sheets, modifier shortcuts and other screens keep their own behavior. Reader chevrons point up/down and navigation is not blocked by sync.

326 automated tests passed, with four opt-in live checks skipped. A native sample-app test exposed that read-only selectable text shares NSTextView with editors; the final guard uses editability, with 20 focused tests passing afterward. Native navigation then passed after clicking body text, and search retained keyboard handling. Physical hover checks were stopped when the user asked to keep using the shared Mac; remaining visual checks were offscreen. No real mail changed. QA app closed.

Installed the final signed/notarized 0.1.21 app while Cove was closed, without launching it or taking focus. App receipt: 73d21259-7400-449b-b7e4-736761b92d30. See docs/qa/0.1.21/AUDIT.md for evidence and installer receipt. Public website deployment was not part of this change.

## September 24: Assistant keeps invitation context (0.1.22, build 24)

The calendar planner previously received an empty email array even when the assistant header showed a selected invitation. Selected email/thread evidence now reaches routing first and is reused for the answer; the selected message stays first within bounded thread context. Prompt rules distinguish event advice/details from Calendar operations, permit invitation details for explicitly requested proposals, and forbid treating an invitation as availability or registration evidence. Successful history is retained within the same selection/scope for follow-ups. Advice provides grounded benefits/tradeoffs without inventing personal goals.

329 offline tests passed, five opt-in live tests skipped. Two separate saved-model gpt-6-sol checks passed: advice/informational routing/explicit proposal from a synthetic invitation, and the existing ambiguous scheduling clarification/follow-up regression. Both used only fake read-only calendars. No real mail or events changed and no desktop input/focus was used. Universal app and DMG signed/notarized/stapled; installer `dist/releases/Cove-0.1.22.dmg` is ready. Installed 0.1.22 build 24 after the user confirmed Cove was closed; verified the installed signature and Gatekeeper acceptance. Previous app retained in .local/app-backups. Cove was not launched and no focus was taken. See docs/qa/0.1.22/AUDIT.md for receipts and checksum.

## September 24: Revised Pen Agent Chat (0.1.23, build 25)

Implemented the user's updated Fe933/VxRhd design: compact single-line header, plain context row, 15-point conversation, borderless source hierarchy and quiet draft/reminder actions. Added local conversation feedback, an inline popover for connected providers' saved models/Jev, compact Mail search and context controls, and send/stop state. Privacy details remain in the footer info popover; copy/grounding details remain in response options. Extra sources are expandable and counts represent distinct emails. Existing invitation context and calendar review remain intact.

331 automated tests passed, five opt-in live checks skipped. Production AssistantView rendered and inspected at design size, compact long-answer size and error state in hidden windows; no native mouse/keyboard input or focus changes. Hidden SwiftUI accessibility controls could not be exercised, so physical click testing is not claimed. Universal app signed/notarized/stapled and installed while Cove was closed, without launching it. See docs/qa/0.1.23/AUDIT.md for evidence and release receipts.

## September 24: signed in-app updates (0.1.24 / build 26)

Sparkle 2.10.0 now provides **Cove → Check for Updates…** and an App updates section in Settings. Daily background checks can be disabled. Users choose when to download/install/relaunch; active mail/calendar operations, queued trash undo, and open editors/conversations defer restart. Update checks use no email context and system profiling is disabled. Development/QA bundles do not start the updater.

The universal app and DMG are signed, notarized, and published at `https://covemail.xyz/beta/`. The signed feed is `https://covemail.xyz/updates/appcast.xml`. Public feed and archive bytes match the verified local release. Offscreen Sparkle probes correctly detect the update from build 25 and no update from build 26. 334 tests passed, 5 opt-in tests skipped. Archive/feed signature checks reject tampering. See [audit](qa/0.1.24/AUDIT.md) for receipts and verification limits.

Users on earlier builds need one manual installation to gain the updater. Cove 0.1.24/build 26 is installed in /Applications; strict signature and Gatekeeper checks passed. The app was left closed. Subsequent release builds still need notarization and signed feed publication; development builds do not automatically ship to users.

## September 24: account model catalog in chat (0.1.25 / build 27)

The assistant picker now discovers all model IDs returned by connected providers, including ChatGPT subscription through the official Codex model/list API. Search, refresh, loading, empty/error states and per-provider grouping replace the single-default-model menu. Saved/custom choices remain available during discovery failures. A conversation selects provider and model together; the selected model reaches routing, search-query generation and answers without changing Integrations defaults.

341 automated tests passed and 5 opt-in live tests were skipped. Offscreen picker rendering with 25 fixture models passed without desktop focus or credential access. See [audit](qa/0.1.25/AUDIT.md). Cove 0.1.25/build 27 is signed, notarized and published. The public signed feed correctly offers it to build 26, and the downloaded DMG matches the release checksum. The running installed 0.1.24 app is left unchanged; the user can choose Check for Updates.

## September 24: model popup sizing and discovery timing (0.1.26 / build 28)

The model picker in 0.1.25 could still show just its saved default: its naturally sized scroll region collapsed to one row, and discovery did not restart when a provider became ready after the popover appeared. The earlier fixed-height test missed the natural popover layout. Both failures were reproduced with tests before applying this fix.

The popup now reserves a 280-point scrolling region, shares the Settings catalog, responds to provider availability changes, and keeps in-flight discovery across close/reopen. Credential changes/disconnect invalidate cached and pending results. All 346 tests passed, with 5 live tests skipped, including 12 picker tests and rendering at the real intrinsic size. See [audit](qa/0.1.26/AUDIT.md). Cove 0.1.26/build 28 is signed, notarized and published. The public DMG and signed feed match the verified artifacts; a headless Sparkle probe from build 27 detects build 28. The running app is left unchanged; install through Check for Updates.

## September 24: Markdown chat replies (0.1.27 / build 29)

Assistant answers now use native block-level Markdown rendering: headings, paragraphs, nested lists, quotes, tables, inline emphasis/code, links and fenced code with Copy. Wide tables scroll with a hint in narrow chat layouts. Full Markdown parsing comes from Foundation; raw HTML is not executed, remote images are not fetched, and custom/file/data/javascript links are disabled. Email drafting and structured tool protocols are unchanged.

351 tests passed, 5 opt-in live checks skipped. The renderer and actual compact chat were checked offscreen, including natural sizing, table empty cells, nested lists, long code, link handling and incomplete input. See [audit](qa/0.1.27/AUDIT.md). Cove 0.1.27/build 29 is signed, notarized and published. The downloaded DMG and signed feed match the verified release, and a headless Sparkle check from build 28 detects it. The running installed app is left unchanged; install through Check for Updates.


## 0.1.28 — Claude subscription and Gmail welcome

Implemented a local official Claude Code subscription provider with browser sign-in, connection checks, disconnect, model aliases/exact IDs, and test/save controls. It participates in existing compose, assistant, and bounded context planning; Claude native tools remain disabled. Added isolated runtime/temp paths, read-only managed-policy access, timeout/cancellation, bounded/redacted process I/O, and no subscription-to-API fallback. A concurrent connection check preserves the signed-in provider. The Gmail callback now serves an animated, accessible thank-you page only after local account/mailbox commit, with distinct non-success states.

Automated/isolated CLI/offscreen verification passed; real Claude subscription sign-in and authenticated generation remain pending the user’s browser login. 0.1.28 build 30 is signed, notarized, and published to the website and signed update feed. Public DMG hash/signature and real headless Sparkle checks passed. The running installation was left untouched. See docs/qa/0.1.28/AUDIT.md.

## 0.1.29 — versioned models and simpler writing setup

The user confirmed Claude subscription login and generation work. Replaced the hardcoded alias list with live CLI model metadata, pinned version choices, and a distinct Automatic option. Shared readable labels now appear in Integrations and chat. Simplified Writing and answers to account selection, connection status, model selection, and Test & use model, preserving the previous default on failed/cancelled tests.

Full suite: 369 passed, 7 opt-in skips. Final focused UI/settings regressions passed; both opt-in Claude CLI checks passed separately, including connected-account discovery without inference. Offscreen layouts inspected at 620/760/1100 points. Signed, notarized 0.1.29 build 31 is published to the website and signed update feed; downloaded hash/signature, tamper rejection, and headless old/current updater probes passed. The running app was not replaced. See docs/qa/0.1.29/AUDIT.md.
