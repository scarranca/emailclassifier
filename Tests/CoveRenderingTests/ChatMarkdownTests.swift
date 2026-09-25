import AppKit
import SwiftUI
import XCTest
@testable import Cove

@MainActor final class ChatMarkdownTests: XCTestCase {
  private let sample = """
  ## Worth a look

  **Yes, if you want to meet founders.** The invitation mentions *12 startups* and direct conversations.

  ### What stands out
  - AI and enterprise software teams
    - Ask about their plans for the US market
  - Investors and operators attending

  3. Check the [event details](https://example.com/event).
  4. Request a place before making travel plans.

  > The venue is shared after registration approval.

  | Detail | What we know | Next step |
  | --- | --- | --- |
  | Time | 5:30–8:30 PM | Check your calendar |
  | Venue | | Ask the organizer |

  Use `subject:invitation` to find related mail.

  ```text
  subject:invitation after:2026/09/01
  A long line stays readable: abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz
  ```

  ---

  Your attendance is **not confirmed**. [1]
  """

  func testBlockStructurePreservesNestedListsQuotesAndExactCode() throws {
    let doc = ChatMarkdownDocument(sample)
    XCTAssertEqual(doc.root.children.first?.kind, .heading(2))
    let list = try XCTUnwrap(doc.root.children.first { $0.kind == .list(false) })
    XCTAssertEqual(list.children.count, 2)
    XCTAssertTrue(list.children[0].children.contains { $0.kind == .list(false) })
    let ordered = try XCTUnwrap(doc.root.children.first { $0.kind == .list(true) })
    XCTAssertEqual(ordered.children.first?.kind, .item(3))
    XCTAssertTrue(doc.root.children.contains { $0.kind == .quote })
    let code = try XCTUnwrap(doc.root.children.first { $0.kind == .code("text") })
    XCTAssertTrue(code.plainText.hasPrefix("subject:invitation after:2026/09/01\n"))
    XCTAssertFalse(code.plainText.contains("```"))
    XCTAssertTrue(doc.root.children.contains { $0.kind == .rule })
    XCTAssertTrue(doc.root.plainText.contains("[1]"))
  }

  func testInlineFormattingLinksAndImageURLsAreHandledWithoutActiveContent() throws {
    let doc = ChatMarkdownDocument("**bold** *italic* ~~old~~ `code` [safe](https://example.com) [bad](file:///tmp/private) ![alt](https://example.com/pixel.png)")
    let paragraph = try XCTUnwrap(doc.root.children.first)
    XCTAssertTrue(paragraph.text.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
    XCTAssertTrue(paragraph.text.runs.contains { $0.inlinePresentationIntent?.contains(.emphasized) == true })
    XCTAssertTrue(paragraph.text.runs.contains { $0.inlinePresentationIntent?.contains(.code) == true })
    XCTAssertEqual(paragraph.text.runs.compactMap(\.link).map(\.absoluteString), ["https://example.com"])
    XCTAssertTrue(paragraph.text.runs.allSatisfy { $0.imageURL == nil })
    for url in ["javascript:alert(1)", "file:///etc/passwd", "data:text/html,hello", "cove://action", "https://user:pass@example.com"] {
      XCTAssertFalse(ChatMarkdownDocument.allowsLink(try XCTUnwrap(URL(string: url))))
    }
    XCTAssertTrue(ChatMarkdownDocument.allowsLink(try XCTUnwrap(URL(string: "mailto:alex@example.com"))))
  }

  func testTablePreservesEmptyCellPositions() throws {
    let doc = ChatMarkdownDocument(sample)
    let table = try XCTUnwrap(doc.root.children.first { $0.kind == .table(3) })
    XCTAssertEqual(table.children.count, 3)
    XCTAssertEqual(table.children.first?.kind, .row(true))
    let row = try XCTUnwrap(table.children.last)
    XCTAssertEqual(row.children.first { $0.kind == .cell(0) }?.plainText, "Venue")
    XCTAssertEqual(row.children.first { $0.kind == .cell(2) }?.plainText, "Ask the organizer")
    XCTAssertTrue(row.children.first { $0.kind == .cell(1) }?.plainText.isEmpty ?? true)
  }

  func testTypographicBulletLinesBecomeSeparateItemsWithoutChangingCode() throws {
    let text = "Tomorrow\n\n• First event\n• Second event\n\n```text\n• literal bullet\n```\n\n    • indented code"
    let document = ChatMarkdownDocument(text)
    let list = try XCTUnwrap(document.root.children.first { $0.kind == .list(false) })
    XCTAssertEqual(list.children.map(\.plainText), ["First event", "Second event"])
    let code = try XCTUnwrap(document.root.children.first { $0.kind == .code("text") })
    XCTAssertEqual(code.plainText, "• literal bullet\n")
    XCTAssertTrue(ChatMarkdownDocument.normalizeBullets(text).contains("    • indented code"))
  }

  func testPlainTextIncompleteMarkdownAndLiteralCodeStayReadable() {
    for source in ["Plain reply", "Unfinished **bold", "```\nlet unfinished = true", "Hola, mañana — 你好 👋"] {
      XCTAssertFalse(ChatMarkdownDocument(source).root.plainText.isEmpty)
    }
    let doc = ChatMarkdownDocument("```html\n<script>alert('literal')</script>\n```")
    XCTAssertTrue(doc.root.plainText.contains("<script>alert('literal')</script>"))
    XCTAssertTrue(ChatMarkdownDocument("").root.plainText.isEmpty)
  }

  func testMarkdownRendersAtNaturalHeightAtWideAndNarrowWidths() async throws {
    _ = NSApplication.shared
    DesignAssets.registerFonts()
    for width: CGFloat in [680, 360] {
      let host = NSHostingView(rootView: ChatMarkdown(sample).padding(20).frame(width: width).background(Palette.canvas))
      let size = host.fittingSize
      XCTAssertEqual(size.width, width, accuracy: 1)
      XCTAssertGreaterThan(size.height, 650, "Blocks and tables must not collapse")
      XCTAssertLessThan(size.height, 2000)
      let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
      window.isReleasedWhenClosed = false; window.contentView = host
      defer { window.close() }
      for _ in 0..<6 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(30)) }
      XCTAssertFalse(window.isVisible)
      XCTAssertEqual(host.fittingSize.width, width, accuracy: 1)
      let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
      host.cacheDisplay(in: host.bounds, to: bitmap)
      try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        .write(to: URL(fileURLWithPath: "/tmp/cove-markdown-\(Int(width)).png"))
    }
  }
}
