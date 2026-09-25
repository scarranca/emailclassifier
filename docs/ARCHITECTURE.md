# Architecture and service contracts

Cove is a Swift package with a macOS SwiftUI executable and a separate, testable core library. AppStore owns UI state on the main actor. Mailbox synchronization and mutations use a busy state; assistant requests use cancellation and account-generation checks, and visible failures are surfaced to the user. The database is SQLite in WAL mode; account-specific snapshots are stored as Codable records encrypted with AES-256-GCM and authenticated account/record context. Real-account keys live in Keychain. See SECURITY.md for migration and failure behavior. API transport uses HTTPS-only ephemeral sessions with caching, cookies and redirects disabled. Access and refresh credentials never enter SQLite.

## Gmail

The desktop OAuth client belongs to the user. GoogleAuth generates a cryptographically random verifier and state, opens the default browser, receives a bounded HTTP callback on a loopback-only listener, validates the state, and exchanges the code. Callback parsing rejects duplicate state and non-GET requests. PKCE's challenge is checked against the RFC 7636 example in tests. The verified Gmail identity, OAuth client credentials, refresh token, and Calendar grant are stored as one Keychain record. A candidate account is verified and its local database loaded before that record replaces the existing connection. In-memory access tokens are scoped to a connection generation; stale refresh results are rejected. Legacy refresh-only credentials are migrated only after verifying their Gmail identity matches the cached mailbox. Access tokens remain in memory.

Mailbox synchronization downloads 50 message bodies per page with at most five concurrent fetches. Server labels replace cached server labels on refreshed messages; local decisions, snoozes, and reply drafts survive refresh. A successful send uses Gmail's returned message ID so the next sync replaces the local sent copy. Mutations commit locally only after a successful server response. Outgoing MIME includes the validated connected sender and a UTC origination date. UTF-8 subjects use folded RFC 2047 encoded words with scalar-safe chunk boundaries; recipient/header injection checks run before network access.

References: [Google desktop OAuth](https://developers.google.com/identity/protocols/oauth2/native-app), [messages.list](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.messages/list), [messages.send](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.messages/send).

## Jev

JevClient uses the documented HTTP endpoint with `model: jev-latest`, structured `state`, and a map of typed `questions`. Category is a Choice; reply need and urgency are Noul values. A fourth Choice chooses an original source paragraph. Confidence below 0.55 routes category to Other or suppresses a source excerpt. Those values are product thresholds, not vendor accuracy guarantees. The assistant selects original passages from one email, a refreshed Gmail thread, or locally retrieved candidates across downloaded conversations. Thread and downloaded-mail requests share a 24 KB source budget across at most 20 messages and return up to three attributed passages. Downloaded retrieval scans cached bodies off the main actor, ranks overlapping text windows by query-word overlap and recency, and labels its limited coverage. Live mailbox counts bypass Jev.

The client validates the category and probability range before persisting a decision. API failures never fall back to fake classifications. Samples carry `Sample decision` provenance and sample mode does not call the service.

References: [Quick start](https://docs.typesafe.ai/introduction/quickstart), [Choice primitive](https://docs.typesafe.ai/primitives/choice), [Introduction](https://docs.typesafe.ai/introduction).

## Calendar

Optional Google Calendar access uses the same Google account and an additional explicit OAuth scope. Only the primary calendar is synchronized. Recurring events are expanded by the service, all-day dates are parsed in the local calendar, and each visible week replaces that week's cached remote events. Local events remain independent. Event writes do not infer or add attendees. The grid clips overnight events and assigns columns to overlapping event clusters.

References: [events.list](https://developers.google.com/workspace/calendar/api/v3/reference/events/list), [events.insert](https://developers.google.com/workspace/calendar/api/v3/reference/events/insert).

## Incremental mail synchronization

Normal sync uses Gmail history across all pages, fetches minimal labels for changed cached messages and full contents for newly discovered messages. Expired or missing history captures a new baseline before fetching recent mail, then explicitly verifies older cached IDs; absence from one message page is never treated as deletion. Confirmed remote deletion preserves an unsent reply as a local draft. Authentication and transport failures leave the sync cursor unchanged.

Mail snapshots, edits, the history cursor, and pagination state consolidate in one transaction. On restart, per-message edits overlay the existing snapshot. This keeps keystroke saves small while retaining old database compatibility.

References: [Gmail sync guide](https://developers.google.com/workspace/gmail/api/guides/sync), [history.list](https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.history/list).
