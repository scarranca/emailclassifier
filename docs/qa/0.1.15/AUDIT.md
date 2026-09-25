# Cove 0.1.15 calendar assistant verification

- Full suite: 275 automated checks passed; 3 opt-in live checks skipped. `/tmp/cove-0115-final-tests.log`.
- New coverage: clock and exact bounded lookup, email/clarification without reads, overlapping versus transparent/boundary events, unavailable/disconnected calendar, invalid/past/unsupported plans, cancellation, agenda evidence, hosted preview render, explicit Google POST with no attendees and local persistence.
- Live saved gpt-6-sol: ambiguous screenshot request → clarification → correct 30-minute preview starting 30 minutes later → separate email request still routes to mail. Uses synthetic calendar data only; no real calendar/mail writes or reads. `/tmp/cove-0115-live.log`.
- Hosted production event card inspected at 400-point width. `event-preview.png`.
- Limitations: primary calendar and Cove local events only; no guests/recurrence; edited times are not rechecked; no live mutation or full native assistant UI interaction tested.
- Packaging receipts and installation verification recorded after notarization below.

Installed whole signed/stapled bundle at `/Applications/Cove.app` while closed. Strict signature, Gatekeeper, staple, and universal architectures passed. Backup: `/Users/santiagocarranca/orca/workspaces/emailclassifier/lugworm/.local/app-backups/Cove-before-0.1.15-5b23f270-6386-4827-bcdf-22e2801a3bf3.app`. App notarization: `a17568ff-1062-47a6-bf8b-ab11744e7ec9` (Accepted).

DMG notarization: `f9e7769e-a453-49aa-82a8-9394ad7a2f7c` (Accepted). Stapled, signature/disk checksum/Gatekeeper validated; release at `dist/releases/Cove-0.1.15.dmg`.
