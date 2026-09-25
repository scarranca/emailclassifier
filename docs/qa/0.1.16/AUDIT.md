# Cove 0.1.16 verification

283 automated checks passed; three opt-in live scenarios skipped. Log: `/tmp/cove-0116-final-tests.log`.

- Ignore persists across store reload and new mail from the same normalized sender; undo/restore is persisted. No mail changes.
- Preferences without the new optional field still decode. Separate mailbox stores do not share ignored people.
- Archive POST removes only INBOX, preserves message/read state and local copy.
- Delete POST uses `/trash`, not permanent DELETE. Repeat trash is a no-op.
- HTTP failures retain visible mail and surface an error. Sample changes make no network requests; busy actions do not send.
- A forced account lifecycle change during trash prevents stale completion from changing the new mailbox.
- Production Hub hosted in a native NSHostingView and visually inspected; Archive/Delete and Ignore are visible.

No real mail was archived/deleted during QA. Native app-control startup failed, so full live interactions were not exercised.

Packaging and installation status follows.

Universal Developer ID app notarization accepted: `f7cf6d6d-9254-46a0-8e93-743094735fd3`. DMG notarization accepted: `f4c1810a-5bcc-4930-a2ea-b8b0dd7a17a5`. App/DMG stapled; signatures, Gatekeeper and DMG checksum verified. Release: `dist/releases/Cove-0.1.16.dmg`. Installation pending: `/Applications/Cove.app` 0.1.15 is running; native control connection failed, so user must save and quit before replacement.

Installation completed after the user quit Cove. Installed `/Applications/Cove.app` version 0.1.16 build 18. Strict signature, Gatekeeper, staple and universal architectures verified. Whole previous bundle preserved at `/Users/santiagocarranca/orca/workspaces/emailclassifier/lugworm/.local/app-backups/Cove-before-0.1.16-61f51455-b1dc-4ffb-bcb5-aaee5e4f5dee.app`.
