# Cove AI providers

Integrations configures OpenRouter, OpenAI API, Anthropic, or a ChatGPT subscription. Jev remains the classification and original-passage engine. API keys are stored under separate provider accounts in Cove's existing Keychain service. UserDefaults stores only model IDs, provider choice, and a key-present flag. Removing a key removes its Keychain item. Keys are never bundled with a release.

Writing is explicit: open Write with Cove in a new message or reply, enter an instruction, generate, review/edit, and choose Use draft. The normal Send action is still required. Assistant users can keep Jev or enable a configured model for generated answers. Search Gmail produces an editable Gmail query; the user explicitly runs it before Gmail downloads up to 20 results. This permits searches beyond already downloaded mail without letting models execute arbitrary tools.

Requests contain at most 20 emails, 48,000 UTF-8 bytes of body evidence, 6,000 bytes per body, 8,000 bytes of instructions, and 24,000 bytes of draft. Spam, Trash, and Draft context is excluded. Trusted task instructions and untrusted email evidence use separate message fields. Prompt injection remains possible within generated text; no provider is given a mail-send or account-write tool. API output is capped at 2,048 tokens; requests time out after 90 seconds. API transport is the existing ephemeral, HTTPS-only, no-redirect implementation; HTTP errors do not echo provider payloads. OpenAI requests set store=false. Other provider retention policies apply; Cove makes no zero-retention claim.

## ChatGPT subscription

This uses the official **Codex app-server**, not ChatGPT cookies or an unofficial API endpoint. Install the official native Codex CLI and select it if Cove cannot find it. Cove starts its own stdio process with an isolated `~/Library/Application Support/Cove/ChatGPT` runtime directory and `cli_auth_credentials_store="keyring"`. It never reads a user's existing Codex authentication files or inherits API-key environment variables. Browser login, account state, and model discovery use documented app-server methods. Plan eligibility and limits are controlled by OpenAI. OpenAI API billing remains separate.

The local helper disables shell, apps, hooks, web search, multi-agent and remote-plugin features; it does not configure MCP servers. It uses read-only Codex permissions with no approval grants and ephemeral threads. Cove rejects any server tool/permission requests. An outer macOS Seatbelt profile additionally denies file data access outside the isolated runtime, selected CLI executable, and enumerated system runtime directories. It denies writes outside the isolated runtime except the system-selected encrypted keychain database and the Security framework’s lock/atomic-save files. macOS still enforces normal Keychain item access controls; Cove does not reset the keychain, allow the whole Keychains directory, or fall back to plaintext credential storage. This boundary is important because older Codex schemas expose read-only permissions without restricted readable roots. Nothing in the mailbox database or another user directory is readable to the helper. The profile allows network connectivity needed by the official Codex client; it is not a general network domain filter.

The outer boundary uses `/usr/bin/sandbox-exec`, an Apple-deprecated utility still present on the macOS version tested. If unavailable or incompatible, connection fails closed; it must not fall back to launching without the boundary. Only standalone/native Codex binaries are supported (Node launcher scripts may need runtime dependencies outside the allowlist). Cove requires a model selection before sending text. A generation has a 120-second deadline; cancel/timeout terminates the helper. Credentials remain in the OS Keychain; user text is supplied over stdin, not command arguments.

## Verification

Provider request/response shapes, error redaction, invalid-header rejection, no accidental subscription-to-API fallback, finite context, and sandbox read/write denial are covered by `AIProviderTests`. A synthetic app-server initialize handshake against the installed official CLI succeeded within the outer sandbox, without logging in or transmitting mail. A September 23 opt-in smoke test also verified real generation through the saved ChatGPT subscription model using synthetic calendar data (see below); no real mail was sent. GitHub is an explicitly pending integration; no GitHub authorization or API call exists.

Primary implementation references, checked September 22, 2026:
- https://learn.chatgpt.com/docs/app-server
- https://learn.chatgpt.com/docs/auth
- https://learn.chatgpt.com/docs/config-file/config-sample
- https://developers.openai.com/api/docs/quickstart
- https://platform.claude.com/docs/en/api/messages/create
- https://openrouter.ai/docs/api_reference/overview

## 0.1.3 keychain correction

A real browser login exposed a gap in 0.1.2: the helper could initialize but its outer sandbox denied the login keychain, leading macOS to show a misleading “Keychain Not Found” reset dialog. 0.1.3 obtains the system default keychain path through Security.framework and permits only that database, its `.sb-…` atomic-save files, and `.fl…` lock files. No account data, keychain configuration, or existing credentials are reset. The regression test creates a disposable keychain, proves the original profile cannot access it, saves/reads/deletes a synthetic credential under the corrected profile, confirms unrelated files are blocked, and restores the original keychain search list.

## Compose context and read-only lookups (0.1.10)

Compose supplies the selected sender, recipient addresses/names, subject, current date/time zone, saved writing preferences, and draft. Up to six recent relevant messages are selected locally by recipient; users can remove them or disable that automatic context. Provider configuration stays in Integrations.

With Look up mail and dates enabled, Cove uses a provider-independent structured plan followed by a drafting request. The planner receives the user's instruction and envelope, not email bodies or quoted drafts. Only a validated `search_mail`, `calendar`, or `find_availability` plan can execute. The dispatcher performs at most three read-only calls and passes bounded results as untrusted evidence to the writer. It cannot send, mutate mail/calendar, access arbitrary URLs/files, or expose Google credentials. Codex native tools remain disabled. Calendar ranges are limited to 31 days and two pages; incomplete results cannot establish availability. Email evidence remains capped at 20 messages/48KB, and extra lookup evidence at 12KB with explicit truncation labeling. Ordinary lookup-assisted drafting uses two model completions plus bounded Google API reads. A scheduling draft may use one additional correction completion if the provider omits the exact verified date/time; a second omission fails visibly. With lookups off, ordinary writing uses one completion; availability requests require lookups.

Motion uses actual work stages and a reveal of the returned suggestion, not simulated streamed output. Users review/apply before the original draft changes and explicitly send afterward. Reduce Motion removes the particle/typing effects.


Availability is calculated by Cove from the complete primary Google Calendar day plus local events, using the current local time zone. The first free slot respects blocking all-day/overlapping events and defaults to 30 minutes within 09:00–17:00 unless the request supplies a duration/window. These assumptions and the checked-calendar scope appear beside the suggestion. A typo-tolerant intent guard prevents a provider from skipping the calendar check for a first-available request. Missing permission, incomplete/malformed results, no free slot, or a cancelled account fail before a generic meeting draft is shown. Recipient availability and other Google calendars are not checked.

Runtime writing actions require a saved model and API key, or a connected ChatGPT subscription plus saved model. Compose and Assistant restore an existing ChatGPT session; they do not start a login flow. Unconfigured providers are absent from runtime choices; Integrations retains setup controls. No Keychain lookup occurs during view-body evaluation.

The opt-in `COVE_RUN_CHATGPT_SMOKE=1 swift test --filter LiveWritingSmokeTests` check passed with the saved `gpt-6-luna` subscription model. It used a synthetic September 24 calendar busy from 09:00–10:30 PDT, one calendar tool call, and two model completions. The result proposed Thursday, September 24, 2026 at 10:30 AM PDT for 30 minutes. No real mailbox/calendar evidence was used or email sent.


## Follow-up scheduling (0.1.11)

Compose and reply writing retain an in-memory session for the current draft: up to four successful user requests (500 UTF-8 bytes each) and verified meeting parameters. The planner receives this context without receiving quoted drafts or mail bodies. The latest request takes precedence. Applying a suggestion retains context for further changes; choosing Keep original, changing the envelope/account, or opening a new Compose resets it.

The availability tool now accepts slotCount (1–5). “Suggest 3 timeslots” inherits the meeting day, duration, and window, then re-fetches the complete calendar day. Cove calculates distinct, non-overlapping options; it reports when fewer fit rather than inventing the remainder. Every returned option must appear in the generated suggestion; one bounded correction is allowed. No extra Calendar calls or model calls are needed just to return multiple slots.

The live two-turn test passed through the saved gpt-6-luna ChatGPT subscription, with synthetic calendar evidence: first available tomorrow produced 10:30 AM PDT, then “suggest 3 timeslots” produced 10:30 AM, 11:00 AM, and 11:30 AM on the same day after a new calendar read. Total: two calendar reads and four model completions. No real email sent. Continuous waiting particles and refinement spinner are removed; actual returned text retains the finite glyph-assembly animation.


## Compose review polish (0.1.12)

A small native spinner accompanies actual work stages; an empty canvas shows static skeleton lines. Reduce Motion replaces the spinner with an hourglass. The finite returned-text reveal is preserved. Wide Compose lets users edit the pending suggestion directly on the main canvas, with Apply and follow-up instructions in a compact sidebar. Narrow Compose and replies retain inline editing. Sources and checks are collapsed by default. Manual canvas edits are synchronized into Apply and the next refinement request; cancellation/failure retains the earlier suggestion. The hidden original editor is disabled and relinquishes keyboard focus. Provider planning, context limits, model calls, and sending authorization are unchanged.


## Selected passage rewrites (0.1.13)

Original and pending text editors publish UTF-16 selections. A pending refinement snapshots the current suggestion and selected substring, sends only that passage as editable draft text, then splices the returned replacement into the snapshot. The original draft and outer selection remain unchanged until Apply; stale original changes still reject Apply. Invalid ranges and empty responses fail without replacing text. Cancellation/failure preserves the prior suggestion and selection.

Scoped style edits make one writer call, with existing email context and writing preferences but no planner or previous full-email scheduling requests. Explicit availability requests may still use bounded Calendar lookups when enabled. Successful scoped edits preserve the draft session for later whole-email follow-ups. Writing shortcuts now execute immediately; choosing a language still requires its explicit instruction step.


## Tool guidance, language, and visible failures (0.1.14)

Planner examples distinguish wording edits (no lookups), explicit fresh mail searches, existing-event queries, free-time calculations, and combined requests. It receives the raw current request, envelope, clock and successful history; saved style preferences and email/draft bodies do not direct planning. Recipient queries cover both directions; topic searches avoid invented exact subjects and date cutoffs. Identical calls are deduplicated, fresh search evidence is prioritized under the existing cap, and Sources & checks shows the actual query/count/date range. A clarification-only plan can ask one bounded question without executing tools or generating a draft. Normal assisted writing still takes two model completions; clarification takes one, and the existing verified-time correction can add one.

Language follows explicit user direction; otherwise new drafts follow the current user request and rewrites preserve existing text language. Saved voice and foreign-language email context do not override that rule. These are provider-independent instructions, not a forced model selection.

Writing failures appear above scrollable controls with attempted model and retry/settings actions. The saved model is snapshotted per request, so the next request honors configuration changes. Retry preserves the captured scope and refuses stale draft/preview text. ChatGPT errors retain bounded provider reasons; timeout has a distinct message and resets helper state before retry. Real saved gpt-6-sol passed both scheduling and combined-tool/language synthetic tests. No real emails were sent.


## Assistant Calendar (0.1.15)

AI chat now classifies each non-count question with the chosen provider before email retrieval or Gmail search planning. The planner receives the current local clock/time zone and recent calendar conversation, with no email bodies. A validated plan can route back to email, ask clarification, read an agenda (maximum 31 days), or prepare a personal event. It has no write callback. Calendar-only requests never select email evidence. Ambiguous starts or missing durations require a follow-up; an explicit offset-bearing interval is validated before a read. Proposals check overlaps in primary Google Calendar plus Cove local events, respecting transparent/declined events. Disconnected and failed reads remain visibly unverified.

The event card opens the shared Calendar editor. The user edits title/time/destination and clicks Add event before any POST. Successful creation is reflected in chat; failures stay in the editor. Duplicate clicks and account changes are guarded. Changing the time in review does not recheck availability, which is stated there. No attendee invitations, recurrence, or model-directed update/delete actions are supported. Agenda summaries use fetched events directly, without a second model call. Ordinary email answers cost one additional routing completion; calendar clarification and previews use one completion and at most one bounded Calendar read. The selected provider/model is captured for each request.

A live synthetic Sol test passed for the user's ambiguous focus request, its precise follow-up, and an email question mentioning a meeting. No real event was created during verification.


## Claude subscription (0.1.28)

Cove runs the user's separately installed, unmodified native Claude Code CLI (`claude auth login/status/logout` and `claude --print --output-format json`). Authentication is completed by Anthropic's own browser flow. Cove does not extract, read, or forward subscription tokens. The isolated `~/Library/Application Support/Cove/Claude` configuration is owned by the CLI; API-key environment variables and user/project settings are not inherited. API authentication continues to be available separately through the Anthropic provider.

Generation appends Cove's system instructions to the CLI's normal system prompt and supplies private instructions, draft, and evidence only through stdin. Safe mode, no built-in tools, no MCP servers, no slash commands, dontAsk permissions, no session persistence, debug output to `/dev/null`, and the existing macOS filesystem boundary apply. An explicit 120-second timeout and cancellation terminate the subprocess. Stdout is bounded to 2 MB in memory, provider errors are redacted, and there is no fallback to API billing. Missing/incompatible CLI installations fail visibly.

As of 0.1.29, model discovery uses a no-inference CLI stream-json initialize request. Cove reads only the response’s model metadata, displays the resolved versions, and pins explicit choices to those IDs. Automatic delegates selection to the CLI/account and displays the currently resolved version. No list is hardcoded and Cove never reads OAuth credentials. Refresh fetches current CLI metadata; test-and-use verifies access before saving. Plan limits and usage credits remain governed by Anthropic.

Official references checked September 24, 2026:
- https://code.claude.com/docs/en/legal-and-compliance (unmodified CLI hosting, individual user authentication; no credential intermediation)
- https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan (current pause of separate SDK billing change)
- https://code.claude.com/docs/en/model-config (aliases and plan-dependent access)

Verification covers fixture auth lifecycle, subscription/API distinction, complete provider routing, private-context transport, errors, cancellation, process I/O, and offscreen Integrations rendering. An opt-in test runs installed Claude Code 2.1.282 in a fresh signed-out directory, checks auth status, and verifies the exact generation flags reach a structured authentication rejection with zero model tokens; no user credentials or real emails are used. The user subsequently confirmed successful subscription sign-in and a model response. Live model discovery through the same connected account passed on September 24; no inference or email content was used for that discovery check.
