# Cove for Mac

A native SwiftUI Gmail client based on the five supplied Cove designs and the Foundations/Components HTML design system. Requires macOS 14+ and Xcode Command Line Tools (Swift 5.10+). Sparkle 2 powers signed in-app updates. The optional ChatGPT and Claude subscription connections require the separately installed official Codex and Claude Code CLIs, respectively. Inter and the supplied dotted-wave artwork are bundled resources.

## Run

```sh
./scripts/build-app.sh
open dist/Cove.app
```

Without a saved Google connection, Cove opens on the login screen. Choose **Explore a sample inbox** there to try the interface without credentials. Sample messages, replies, and calendar events stay on this Mac; sample mode never sends email.

For development:

```sh
swift run Cove --sample --qa
swift test
```

Open `Package.swift` in Xcode to work on the project. The packaging script uses the single installed Apple Development identity, or an explicit `COVE_SIGNING_IDENTITY` certificate name/SHA-1, so Keychain can recognize Cove across rebuilds. If several development identities are available, set that variable explicitly. Ad hoc signing requires `COVE_SIGNING_IDENTITY=-` and is intended for credential-free QA; changing an ad hoc build can trigger repeated Keychain prompts. Distribution mode produces a universal Developer ID build with bundled Google sign-in configuration. See [distribution and notarization](docs/DISTRIBUTION.md) for release instructions and Google testing restrictions.

## App updates

Distribution builds from 0.1.24 onward include **Cove → Check for Updates…** and **Settings → App updates**. Cove checks daily while running, with an option to disable automatic checks. You choose when to install and relaunch. Users on earlier builds install the current [DMG](https://covemail.xyz/beta/) once to gain this feature. Releases use Apple notarization and a signed Sparkle feed; see [release instructions](docs/DISTRIBUTION.md).

## Connect your account

Open **Settings** (⌘,) in Cove. Distribution builds include Cove’s desktop OAuth configuration; sign in through **Connect Gmail** with an allowed Google test account. Existing custom client settings remain supported.

For a development build without bundled OAuth configuration:

1. In [Google Cloud](https://console.cloud.google.com/apis/credentials), create a project, enable **Gmail API**, configure the OAuth consent screen, and add your Gmail address as a test user.
2. Create an OAuth client with application type **Desktop app**. Enter its client ID and desktop client secret under **Advanced Google settings**.
3. Optionally enable **Google Calendar API** and select **Also connect Google Calendar**.

Enter your [TypeSafe API key](https://console.typesafe.ai) in Settings for Jev organization, save, and connect Gmail through your browser.

Cove checks Gmail about every two minutes while open, independently of AI settings. You can pause background sync in Settings; manual Sync Gmail remains available. In **Your agent**, enable **Organize new mail with Jev** to classify newly received mail. Only incoming mail received from activation onward is processed automatically. Use **Organize downloaded mail** to process older incoming mail too; saved decisions are skipped.

Google sign-in uses authorization code + PKCE with a temporary loopback listener bound to `127.0.0.1`, state verification, cancellation, and a three-minute timeout. Gmail requests `gmail.modify` for reading, organizing, and user-initiated sending. Optional calendar access requests `calendar.events`. Refresh tokens and provider secrets are stored in macOS Keychain. Google account identity and its refresh credentials are saved together only after profile verification and successful local database loading. Failed reconnections preserve the current account; stale refresh responses cannot replace a newer connection. OAuth clients in Google's testing mode can have short-lived refresh grants; reconnect if Google revokes access.

## What works

- Agent Hub home with whole-row email navigation and a continuous column divider; three-column inbox with a dot and stronger typography for unread mail, local search, priority view, categories, starred/sent/drafts/archive views.
- Direct Gmail sync with incremental history, external label/deletion reconciliation, and **Load older mail** pagination in pages of 50.
- Formatted HTML email reading preserves paragraphs, links, lists, tables, and sender styling, with a plain-text toggle. Embedded MIME images load from Gmail. Settings offers **Text-only reading** and **Load external images automatically**, both off by default. Formatted mail can load HTTPS images automatically when enabled or through the existing per-message action; text-only mode loads no images. Plain HTTP images remain blocked. Scripts, forms, frames, and remote styles are blocked. Replies respect Reply-To.
- Archive, star, read/unread, trash, and local snooze.
- Persistent local composition and reply drafts; explicit sending through Gmail. Edits made during a send remain saved, and uncertain send results ask you to check Gmail Sent before retrying.
- Attachments in the Agent Hub and email reader, source-email navigation, and explicit download through a native Save panel; sample and live Gmail downloads verified.
- Jev categorization, urgency and action probabilities, confidence-gated routing, and source passage selection. The assistant also answers unread and folder-count questions directly from Gmail, with explicit mailbox, single-email, or whole-thread scope.
- Contextual assistant that finds original passages in one email, its Gmail conversation, or across downloaded mail. Whole thread refreshes the conversation. Downloaded mail scans cached bodies locally, ranks candidates by question-word overlap and recency, then lets Jev choose relevant passages. Both scopes share a 24 KB text budget across up to 20 messages and display up to three attributed sources; long quotes can be expanded. Cached-only and limited-input results are labeled. The reader shows Jev’s action and urgency likelihoods beside the selected passage.
- Writing-tone templates, editable sign-off, instructions, and opt-in memories with search, uninterrupted inline editing and Remove/Undo. Optional generative writing and answers use your selected provider and model; generated drafts require review and insertion before sending.
- Calendar with month navigation, saved-event search (⌘F), selected-day agenda, Work, Personal and Focus time local calendars with per-calendar visibility, optional Google primary-calendar visibility, workweek/week view, event details and guests, Meet links, and user-confirmed focus suggestions shown as outlined previews in the grid. Availability uses all saved events, including hidden calendars; connected suggestions require a recent successful primary-calendar sync. The week grid marks the current time on today’s column. The day-agenda divider supports dragging and keyboard resizing, with its width remembered on this Mac. Event creation, editing, and deletion remain explicit user actions.
- Keyboard shortcuts: ⌘0 home, ⌘1 mail, ⌘2 calendar, ⌘3 agents, ⌘N compose/new contact/new event for the current screen, ⌘K search, ↑/↓ previous/next email, Esc/← back to the list, ⌘J assistant, ⌘R sync, ⌘, Settings.

## Contacts

Open **People** or **Contacts** from the sidebar, or use **⌘4**, to see the contact directory. People now opens contacts rather than an empty categorized-mail view. Search by name, email, or saved company; add/edit local contact details, favorites, groups, and notes. Contacts also include senders and outgoing recipients from downloaded mail. Recent activity is limited to that local cache. The Email action opens a draft; Calendar opens the existing calendar. Google Contacts synchronization is not connected. An empty directory offers **Sync Gmail**.

Home’s **Keep in touch** is deliberately narrower than the directory: it requires a Jev People/Work decision with at least 0.7 confidence and excludes bulk/automation headers, promotional/notification Gmail categories, and no-reply senders. Suggestions use each sender’s latest received message; unclassified mail and older caches without header metadata wait for organization or sync. The full contact directory still includes saved contacts and downloaded correspondents.

## Jev's role

[Jev](https://docs.typesafe.ai/introduction) returns structured decisions, not generated prose. Cove calls `POST https://api.typesafe.ai/v1/systemone` using `jev-latest`, Choice and Noul questions. Low category confidence routes to Other; source passages remain verbatim. Reply templates remain deterministic and labeled as templates. Generative writing, summaries, and answers are a separate, optional provider feature; Jev continues to organize mail and select source passages.

Running Jev sends bounded email text, sender, subject, instructions, and enabled memories directly to TypeSafe. Source passages share a 24 KB UTF-8 budget per request; whole-thread questions include message dates and bounded headers, exclude Drafts/Spam/Trash, and use the newest messages plus the selected message when the thread exceeds 20 messages; downloaded-mail questions use the same source budget, with at most 20 locally ranked candidates across conversations; instructions and memories share an 8 KB budget. Long messages may be only partially assessed. Automatic organization is off by default. No email send or calendar mutation is triggered by a model decision.

## AI providers and Integrations

Open **Integrations** to configure **OpenRouter**, **OpenAI API**, or **Anthropic** with your own API key. Keys are saved in macOS Keychain. Load the provider’s model list or enter an exact model ID, then save the model for that provider. OpenAI API billing is separate from a ChatGPT subscription.

To use **ChatGPT subscription**, install the official Codex CLI separately, select its executable if Cove cannot find it, and choose **Sign in with ChatGPT**. Cove uses the official local Codex app-server with a separate sign-in and isolated configuration; it does not reuse another app’s tokens. Available models and subscription limits depend on the connected account. This path requires its own installation and authentication on every Mac; it is not a bundled, preauthenticated service.

To use **Claude subscription**, install the official native Claude Code CLI, choose **Claude · Subscription** in Integrations, and **Connect Claude**. Anthropic handles browser authentication through its unmodified CLI. Cove uses a separate configuration directory, disables the CLI’s native tools and session persistence, and supplies bounded email/calendar context over stdin. Choose a supported model alias or exact ID, test access, and save. Aliases are not a live entitlement list; plan access and usage limits apply. Anthropic API keys remain a separate option.

**Write with AI** in compose/reply produces editable text. **Use draft** inserts it for review; sending stays a separate user action. The assistant’s **Use AI model** option provides generated answers and summaries from bounded email context. Requests you start send your instruction, current draft when applicable, and up to 20 relevant emails with a shared 48 KB body budget to the selected provider. Generated results can be wrong and should be checked against their linked emails. Provider data and usage policies apply.

AI-assisted Gmail search first proposes an editable Gmail query. Review it and click **Search Gmail** to fetch up to 20 matching messages, excluding Spam, Trash and Drafts. Query generation sends the search request without email bodies; retrieved messages are not automatically sent to the model. A follow-up AI question shares its selected context. This is bounded retrieval, not exhaustive search or background mailbox processing.

The integrations page also shows Gmail and Jev status/setup guidance. **GitHub is a coming-later placeholder; no GitHub authentication or API integration is connected.** Live requests to the newly added generative providers and a real ChatGPT subscription have not yet been verified.

## Local data

Mail, contacts, drafts, decisions, preferences, and events live in a per-account SQLite database under `~/Library/Application Support/Cove/`. Sample data uses a separate database. Draft edits write one message at a time; sync commits messages and its history cursor atomically. See `docs/PERFORMANCE.md` for measured storage timings. Real-account record contents are encrypted with AES-256-GCM using a per-account key in macOS Keychain. Existing caches migrate transactionally; sample fixtures remain plaintext. The containing directory is owner-only. SQLite metadata remains visible; FileVault additionally protects the volume at rest. Disconnect removes the refresh token and returns to onboarding; the encrypted cached mailbox remains on disk for reconnection. Settings also offers an explicitly confirmed local-data removal action. That action does not delete Gmail messages or Google Calendar events. See [the security review](docs/SECURITY.md) for key recovery, retention, backup and threat-model limits.

## Current limits and verification

**0.1.23 build 25** implements the revised Pen Agent Chat: compact header, borderless sources, secondary draft/open actions, local reminder menu, conversation feedback, and inline saved-model/Mail search controls. Provider/privacy details remain accessible from the footer. Full suite: 331 passed, five opt-in live checks skipped; normal, compact long-answer, and error states were rendered in hidden windows. See `docs/qa/0.1.23/AUDIT.md` for release status and validation limits.

**0.1.22 build 24** fixes assistant routing for selected invitations: routing and answers receive the same bounded selected email/thread evidence, email advice stays separate from Calendar operations, and successful follow-ups retain context within the same selection. Offline suite: 329 passed, five opt-in live checks skipped. A separate live check with the saved gpt-6-sol subscription model passed invitation advice, date/location routing, and an explicit event proposal using synthetic evidence and a fake read-only calendar. See `docs/qa/0.1.22/AUDIT.md` for packaging status and limitations. Older version notes below are historical evidence.

**0.1.7 build 9** implements the Pen Integrations layouts with a shared Settings sidebar, landscape header, provider tiles, separate API-key and ChatGPT subscription setup, model loading, optional synthetic model testing, and explicit Save configuration. Browsing provider tiles does not change the active provider. Google Tasks and GitHub remain clearly marked Coming later. The installer is `dist/releases/Cove-0.1.7.dmg`.

Version **0.1.2 build 4** passes **190 automated tests** (140 core, 50 app/rendering), native expansion checks, universal release builds, and app/DMG notarization. See the [requirement-by-requirement audit](docs/APP_EXPANSION_AUDIT.md). New provider generation has fixture/protocol coverage; live API or ChatGPT subscription requests require your own setup and are not claimed as verified.

The current expansion targets version 0.1.2 (build 4). Final verification totals and release signing/notarization are tracked separately; the code changes alone are not a verified release artifact.

The pre-expansion security baseline passed 165 automated checks (123 core, 6 WebKit, 6 app-state polling, 9 Calendar workflow, 7 thread-answer workflow, 5 downloaded-mail workflow, 8 send-workflow tests, and 1 local-erasure workflow test). They cover database reopening, nested MIME decoding, HTML fallback, UTF-8 sending, header injection prevention, Jev contract and confidence handling, HTTP errors, Gmail pagination, Google Calendar parsing/pagination/creation, atomic account credential replacement and recovery, reply routing, charset decoding, history reconciliation, transactional targeted persistence, attachment decoding/downloads, background Gmail polling with automatic Jev disabled, and draft preservation across in-flight sends and failures. That baseline’s release build and native rendering were checked; it does not certify the current expansion or its release package. Live Google OAuth, Gmail download and session restoration, and Calendar reading have been verified with locally configured credentials. Jev authentication passed using synthetic text; live automatic organization subsequently classified a new email and persisted category, action/urgency scores, and a source-matching excerpt. Live mailbox counts, formatted reading, and Jev passage question/no-answer pairs for both single emails and a two-message Gmail thread are verified in the packaged app. The downloaded-mail scope also passed a live 20-candidate request with a matching meeting-date passage and an unrelated no-match question. The assistant fits compact windows and distinguishes a selected passage from a no-match result. A user-approved self-test was sent once through the signed app and verified in Gmail Sent and Inbox with the original draft removed. Other live mail mutations, Calendar mutations, and broader Jev answer quality remain unverified. Versioned cache refreshes repair corroborated UTF-8 bodies with misleading legacy charset headers and retrieve HTML for previously downloaded messages while preserving local drafts.

The inbox lists individual messages; the assistant can retrieve their full Gmail conversations on demand. Local search covers downloaded mail; optional reviewed Gmail queries can retrieve additional matches. Cove syncs on request or, when background sync is enabled, about every two minutes while Cove is open. Automatic Jev organization is controlled separately. It does not yet provide attachment upload, conversation grouping in the inbox list, Gmail-hosted draft editing, or push sync. Generative-provider live verification is still pending. Snooze is local and becomes visible when its timestamp passes while Cove is running. Overlapping timed events are arranged in separate columns.

## Structure

- `Sources/Cove`: SwiftUI screens, application state, Keychain, Google sign-in.
- `Sources/CoveCore`: testable models, SQLite storage, Gmail, Jev, Google Calendar, MIME handling.
- `Tests/CoveCoreTests`: persistence, parsing, safety, and API contract tests using injected HTTP transports.
- `DESIGN.md`: visual direction derived from the supplied references.
- `docs/STATUS.md`: current completion evidence and outstanding checks.
- `docs/BACKEND_PLAN.md`: proposed low-cost cloud architecture, pricing assumptions, security boundaries, and mobile migration; no backend has been deployed.

**0.1.8 build 10** adds read-on-open Gmail synchronization, formatted-email wheel scrolling, lighter typography, collapsible Integrations sections, current Codex model discovery, and the Pen Compose AI workspace with editable review before applying suggestions. Verified with 213 passing tests and native sample checks. Installer: `dist/releases/Cove-0.1.8.dmg`.

**0.1.16 build 18** adds persistent Ignore/Undo/restore controls for Keep in touch, direct Archive/Delete actions on priority cards, and mail-list context menus. Delete moves to Gmail Trash. 283 automated checks passed. Installer: `dist/releases/Cove-0.1.16.dmg`.

**0.1.17 build 19** adds today's agenda and pending primary-calendar invitations to Home, with Accept/Maybe/Decline; optional location-based weather with city fallback; and ⌘Delete with an animated five-second Undo notification. Gmail Trash is requested only after the countdown. 297 automated checks passed, with three opt-in live checks skipped. Release verification: [audit](docs/qa/0.1.17/AUDIT.md).

### Custom Jev agents

Open **Agents** (⌘3) and choose **Create agent**. Name the agent, describe the overall task, and add ordered conditions. Each rule can apply a custom Gmail label, prepare a reply, or do both. Existing fixed-label agents have an **Add conditional rules & replies** button. Readable PDF/text attachments are optional. **Run test** sends the selected sample or downloaded inbox email to TypeSafe but does not change Gmail. Save an unfinished agent as a draft, or choose **Create & turn on**.

Active agents check new incoming inbox mail during Gmail sync while Cove is open. Only the first matching rule runs. Confident matches run its configured actions; uncertain or partially inspected messages get **Cove / Needs review**. No match leaves Gmail unchanged. Pause/resume, edit, duplicate, delete, and inspect activity from **Your agents**. Deleting an agent retains existing Gmail labels and emails. Agents and activity are saved per mailbox on this Mac.

Attachments are limited to five files of up to 5 MB each, up to 20 pages per PDF, with bounded text sent to Jev. Images/scans and unsupported or incomplete attachment content require review. Jev selects a rule; your configured writing provider generates any reply from the triggering email and readable attachments. Suggestions are saved in **Activity**, separate from existing drafts; **Use reply as draft** opens the original conversation for your review. No reply sends automatically. Routing tests preview actions without generating replies or modifying Gmail. Agents do not delete messages, pay invoices, or create calendar events. Active agents add TypeSafe usage and reply actions add writing-provider usage. Failed actions are visible in Activity and can retry without repeating a completed label action.

Inbox rows use stronger unread typography, a soft read background, and compact counts from the latest Pen Cove design. Hovering a row reveals Archive, Mark read/unread, and Delete (five-second Undo); selected rows keep these actions visible. Arrow navigation follows the current folder/filter and remains available after clicking the reader, but does not intercept typing or dialogs.
