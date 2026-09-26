# Cove 0.1.39 cloud-sync pilot validation

September 25, 2026. No real mailbox content was used in automated checks.

- 30 Swift tests passed: cloud allowlisted payload/bounds/Unicode/JSON/HTTPS/errors; Google session compatibility; local erasure; polling/read state; persisted cloud pause and an offscreen settings render.
- 10 backend integration tests passed against disposable PostgreSQL 17: RLS account isolation and pool cleanup; encryption/tamper binding; stale and concurrent writes; retry deduplication; cursor pagination and tombstones; deletion during upload; body expiry; identity restrictions; Swift uppercase UUID compatibility.
- npm production audit: zero reported vulnerabilities.
- PlanetScale approved migration applied; all three tables have row security. Separate runtime LOGIN has neither superuser nor BYPASSRLS and passes ownership/membership checks over verified TLS.
- Cloud Run one-shot execution `cove-sync-storage-check-xx56l` passed actual runtime KMS wrap/unwrap and wrong-context rejection, private encrypted object write/read, and RLS isolation in a rolled-back synthetic transaction.
- API deployment `cove-sync-api-00003-44d`: status 200; missing/invalid mail credentials rejected. Pilot allowlist contains only the owner's account. Runtime secret is a pinned Secret Manager version; temporary local password files removed.
- Universal arm64/x86_64 app signed with Developer ID; bundled config includes only the public API URL, no DB connection string. App notarization accepted: `b4718a1b-e3fb-47ca-be3c-96013bcac056`.
- Real-account Google cloud-consent and first-mail upload remain a user-operated check after updating and explicitly enabling Cloud sync. Existing users stay local by default. No currently running app was quit or replaced.
- DMG notarization accepted and stapled: `b2187464-ad74-4e5f-9de6-c9dc96f5f1c6`. Public release is 16,740,314 bytes; SHA-256 `255de897d077b86cfdac321e094d6291191b9f0f63d8ee75febb8b1f8a3353e5`.
- Cloudflare Pages deployment `cc04a528-514b-467c-a1bc-abba521a3c07` published the release, signed feed and updated privacy notice. `/download/latest` resolves to 0.1.39; downloaded bytes equal the notarized local DMG. Signature verified using the bundled public key; tampered bytes rejected.
- Headless Sparkle probes passed: build 40 sees the valid 0.1.39/build 41 update; build 41 sees no newer version. Neither probe opens Cove or installs anything.
