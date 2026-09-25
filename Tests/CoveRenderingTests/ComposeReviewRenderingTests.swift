import AppKit
import SwiftUI
import XCTest

@testable import Cove

@MainActor
final class ComposeReviewRenderingTests: XCTestCase {
  func testReviewEditorIsEditableAndBoundedAtNarrowAndWidePanelSizes() async throws {
    _ = NSApplication.shared
    for width in [320.0, 420.0] {
      let original = "Hi Maya,\n\nI’ll review the launch today and send notes before 3 PM.\n\nThanks,\nAlex"
      var suggested = "Hi Maya,\n\nI’ll review today and send notes before 3 PM.\n\nThanks,\nAlex"
      var instructions = ""
      var didApply = false
      let review = AIWritingReview(
        value: ComposeSuggestion(original: original, text: suggested),
        text: Binding(get: { suggested }, set: { suggested = $0 }),
        instruction: Binding(get: { instructions }, set: { instructions = $0 }),
        provider: "ChatGPT subscription · gpt-6-sol", working: false, canRefine: false,
        onApply: { didApply = true }, onKeep: {}, onRefine: {}, onStop: {})
      let host = NSHostingView(rootView: review.padding(20).background(Palette.surface))
      let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 650),
                            styleMask: [.borderless], backing: .buffered, defer: false)
      window.isReleasedWhenClosed = false
      window.contentView = host
      defer { window.close() }
      for _ in 0..<5 {
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(20))
      }
      let editor = try XCTUnwrap(descendants(host).compactMap { $0 as? NSTextView }.first {
        $0.string.contains("I’ll review today")
      })
      XCTAssertTrue(editor.isEditable, "Suggestions must be editable before applying")
      let scroll = try XCTUnwrap(editor.enclosingScrollView)
      let bounds = scroll.convert(scroll.bounds, to: host)
      XCTAssertGreaterThan(bounds.width, 200)
      XCTAssertGreaterThan(bounds.height, 180)
      XCTAssertGreaterThanOrEqual(bounds.minX, 0)
      XCTAssertLessThanOrEqual(bounds.maxX, host.bounds.width + 1)
      XCTAssertLessThanOrEqual(bounds.maxY, host.bounds.height + 1)
      XCTAssertFalse(didApply, "Rendering a suggestion must never apply it")
      let changed = "A reviewed suggestion with my own edits."
      editor.string = changed
      editor.didChangeText()
      XCTAssertEqual(suggested, changed, "Review edits must reach the pending suggestion")
      XCTAssertFalse(didApply, "Editing a suggestion must never apply or send it")
      if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
        host.cacheDisplay(in: host.bounds, to: bitmap)
        if let image = bitmap.representation(using: .png, properties: [:]) {
          try image.write(to: URL(fileURLWithPath: "/tmp/cove-compose-review-\(Int(width)).png"))
        }
      }
    }
  }

  func testNativeComposeEditorKeepsLongDraftScrollableAndReportsUnicodeSelection() async throws {
    _ = NSApplication.shared
    var draft = (0..<100).map { "Paragraph \($0): Hello 👋 Maya, this is a long draft for scrolling." }.joined(separator: "\n\n")
    var selection = NSRange(location: 0, length: 0)
    let host = NSHostingView(rootView: ComposeTextEditor(
      text: Binding(get: { draft }, set: { draft = $0 }),
      selection: Binding(get: { selection }, set: { selection = $0 })))
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 240),
                          styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = host
    defer { window.close() }
    for _ in 0..<5 {
      host.layoutSubtreeIfNeeded()
      try await Task.sleep(for: .milliseconds(20))
    }
    let editor = try XCTUnwrap(descendants(host).compactMap { $0 as? NSTextView }.first)
    let scroll = try XCTUnwrap(editor.enclosingScrollView)
    editor.layoutManager?.ensureLayout(for: try XCTUnwrap(editor.textContainer))
    XCTAssertTrue(scroll.hasVerticalScroller)
    XCTAssertGreaterThan(editor.frame.height, scroll.contentView.bounds.height)
    let range = (draft as NSString).range(of: "Hello 👋 Maya")
    editor.setSelectedRange(range)
    XCTAssertEqual(selection, range)
    XCTAssertEqual(String(draft[try XCTUnwrap(Range(selection, in: draft))]), "Hello 👋 Maya")
  }

  func testCanvasReviewPanelKeepsActionsCompactAndShowsWorkingFeedback() async throws {
    _ = NSApplication.shared
    let text = "Hi Martha,\n\nCould we meet at 9:30, 10:00, or 10:30 tomorrow?\n\nThanks,\nSantiago"
    for working in [false, true] {
      for width in [320.0, 390.0] {
        let review = AIWritingReview(value: ComposeSuggestion(original: "Original", text: text),
          text: .constant(text), instruction: .constant(working ? "Suggest 3 timeslots" : ""),
          provider: "", working: working, canRefine: false, onApply: {}, onKeep: {}, onRefine: {}, onStop: {},
          inlinePreview: false, stage: "Checking your calendar", lastRequest: "Suggest 3 timeslots")
        let host = NSHostingView(rootView: VStack(alignment: .leading, spacing: 20) {
          Text(working ? "Updating your draft" : "Your draft is ready").font(.coveSection)
          Label("Your voice · Warm", systemImage: "waveform").font(.coveMetadata).foregroundStyle(Palette.body)
          review
          DisclosureGroup("Sources & checks") { Text("4 emails and Calendar checked") }
            .font(.coveMetadata).disclosureGroupStyle(CoveDisclosureStyle())
          Spacer(minLength: 0)
        }.padding(22).background(Palette.surface).foregroundStyle(Palette.ink))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 640), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host
        defer { window.close() }
        for _ in 0..<5 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(30)) }
        XCTAssertFalse(descendants(host).compactMap { $0 as? NSTextView }.contains { $0.string == text }, "Canvas mode must not duplicate the full email in the sidebar")
        XCTAssertLessThanOrEqual(host.fittingSize.width, width + 1)
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: "/tmp/cove-review-sidebar-\(Int(width))-\(working ? "working" : "ready").png"))
      }
    }
  }

  func testCanvasEditsReachPendingSuggestionWithoutChangingOriginal() async throws {
    _ = NSApplication.shared
    let original = "Original draft"
    var pending = "Hi Martha,\n\nHere are three times for tomorrow."
    let host = NSHostingView(rootView: WritingCanvasPreview(text: pending, animated: false, onEdit: { pending = $0 }))
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 420), styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = host
    defer { window.close() }
    for _ in 0..<5 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(20)) }
    let editor = try XCTUnwrap(descendants(host).compactMap { $0 as? WritingInkTextView }.first)
    XCTAssertTrue(editor.isEditable)
    editor.string = "Hi Martha,\n\nCould we meet tomorrow?"
    editor.didChangeText()
    XCTAssertEqual(pending, editor.string)
    XCTAssertFalse(editor.motionRunning)
    XCTAssertEqual(original, "Original draft", "Pending changes never overwrite the original")
    let applied = try ComposeSuggestion(original: original, text: pending).applying(to: original)
    XCTAssertEqual(applied, pending)
  }

  func testLoadingSkeletonAndDisabledOriginalEditor() async throws {
    _ = NSApplication.shared
    let host = NSHostingView(rootView: VStack {
      WritingProgressRow(stage: "Finding available times", onCancel: {})
      WritingCanvasLoading(stage: "Checking your calendar")
    }.padding(20).background(Palette.canvas))
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 360), styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = host
    defer { window.close() }
    for _ in 0..<5 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(20)) }
    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
    host.cacheDisplay(in: host.bounds, to: bitmap)
    try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: "/tmp/cove-thinking-skeleton.png"))

    let originalHost = NSHostingView(rootView: ComposeTextEditor(text: .constant("Original"), selection: .constant(NSRange(location: 0, length: 0))))
    window.contentView = originalHost
    originalHost.layoutSubtreeIfNeeded()
    let editor = try XCTUnwrap(descendants(originalHost).compactMap { $0 as? NSTextView }.first)
    window.makeFirstResponder(editor)
    originalHost.rootView = ComposeTextEditor(text: .constant("Original"), selection: .constant(NSRange(location: 0, length: 0)), isEditable: false)
    for _ in 0..<5 { originalHost.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(20)) }
    XCTAssertFalse(editor.isEditable)
    XCTAssertFalse(window.firstResponder === editor, "Hidden original cannot receive typing")
    XCTAssertEqual(editor.string, "Original")
  }

  func testFailureNoticeFitsNarrowPanelAboveScrollableContent() async throws {
    _ = NSApplication.shared
    let host = NSHostingView(rootView: VStack(spacing: 0) {
      WritingFailureNotice(message: "The selected model is not available for this account. Choose another model in Integrations, or try again.",
        model: "gpt-6-sol", onRetry: {}, onConfigure: {})
      ScrollView { Text(String(repeating: "Existing context\n", count: 80)).frame(maxWidth: .infinity) }
    }.frame(width: 320, height: 480))
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 480), styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = host
    defer { window.close() }
    for _ in 0..<5 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(20)) }
    XCTAssertLessThanOrEqual(host.fittingSize.width, 321)
    XCTAssertLessThanOrEqual(host.fittingSize.height, 481)
    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
    host.cacheDisplay(in: host.bounds, to: bitmap)
    try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: "/tmp/cove-writing-error-320.png"))
  }

  private func descendants(_ view: NSView) -> [NSView] {
    [view] + view.subviews.flatMap { descendants($0) }
  }
}
