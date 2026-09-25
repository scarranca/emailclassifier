# Cove 0.1.27 — Markdown in assistant replies

Replaces inline-only answer formatting with a native block renderer driven by Foundation's full Markdown parser. Headings, paragraphs, nested unordered/ordered lists (including non-one starts), quotes, rules, inline emphasis/code, links, fenced code, and tables receive Cove typography and spacing. Code blocks wrap long lines and copy their underlying code. Tables preserve empty-cell positions and use horizontal scrolling with a hint when too wide. The original answer remains available to the existing Copy answer action.

Only generated answer text uses the new renderer. User prompts and original email excerpts retain their existing presentation. The answer prompt encourages concise Markdown when useful; draft-email output and structured tool protocols are unchanged.

Rendering uses native SwiftUI views, with no web view, HTML execution, or remote-image fetches. Parsed image URLs are removed while alt text remains. Links are limited to http/https/mailto; custom, file, javascript and data schemes are discarded. Copy code does not execute code.

Validation:
- Full suite: 351 tests passed, 5 opt-in live tests skipped (356 total), zero failures.
- Five new tests cover block/nested-list structure, starting ordinals, exact code text, inline formatting, permitted/blocked links, removed image URLs, empty table cells, Unicode, incomplete Markdown, literal HTML inside code and natural-size rendering.
- Standalone renderer checked visually at 680 and 360 points. The actual AssistantView also rendered with Markdown in a compact 512×652 chat; the composer remains visible while the answer scrolls. All rendering windows stayed invisible and no live credentials were used.
- Reference: Apple's NSPresentationIntent documentation describes Foundation's parsed block semantics: https://developer.apple.com/documentation/foundation/nspresentationintent

Universal Developer ID app and DMG passed strict signatures, notarization, stapling and Gatekeeper. App receipt: cd5e1801-49e8-4774-99cb-f02f8dff4625. DMG receipt: 26cb29fc-8331-440f-a8e8-a44390d3951c.

Cloudflare Pages deployment 8a98cf6b-931c-43fd-ad19-4a9f1d279b30 published the update. Public signed feed matches the verified feed byte-for-byte. The public DMG matches SHA-256 f3808ed1ad072a90b868fb016126d3a2bb374070ce85607bcffb243f874b1bef (15,413,194 bytes). Independent Ed25519 verification passed and tampering was rejected. Headless Sparkle checks confirm build 28 finds 0.1.27/build 29, while build 29 finds no newer update.

The running installed app was left unchanged. The user can install through Check for Updates. Physical click testing is not claimed.
