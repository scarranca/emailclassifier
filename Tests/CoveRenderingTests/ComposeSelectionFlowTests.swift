import AppKit
import CoveCore
import SwiftUI
import XCTest
@testable import Cove

@MainActor final class ComposeSelectionFlowTests: XCTestCase {
  func testNativeSelectionRewriteRefinementFailureAndApplyUseProductionPanel() async throws {
    _ = NSApplication.shared
    let suite = "cove-selection-flow-" + UUID().uuidString
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let transport = SelectionRewriteHTTP()
    let settings = AIProviderSettings(defaults: defaults, readSecret: { _ in "fixture" },
      saveSecret: { _, _ in }, deleteSecret: { _ in }, client: AIProviderClient(transport: transport))
    settings.provider = .openRouter
    settings.setModel("fixture", provider: .openRouter)
    try settings.saveKey("fixture", provider: .openRouter)
    let original = "Hi 👋 Maya,\n\nA very long paragraph.\n\nThanks, Santi"
    let selection = (original as NSString).range(of: "A very long paragraph.")
    let activity = WritingActivity()
    var applied: String?
    let host = NSHostingView(rootView: SelectionFlowHost(original: original, selection: selection,
      activity: activity, settings: settings, applied: { applied = $0 }).frame(width: 1000, height: 650))
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 650),
                          styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = host
    defer { window.close() }
    try await settle(host)
    activity.rewriteRequest += 1
    try await waitUntil(host) { activity.revision == 1 && !activity.working }
    XCTAssertEqual(activity.preview, "A shorter paragraph.")
    XCTAssertNil(applied)
    XCTAssertTrue(transport.prompts[0].contains("Current draft (text to edit):\nA very long paragraph."))
    XCTAssertFalse(transport.prompts[0].contains("Hi 👋 Maya"))

    let ink = try XCTUnwrap(descendants(host).compactMap { $0 as? WritingInkTextView }.first)
    // Edit and select immediately, without giving the panel a separate render turn.
    ink.string = "A manually shorter 👋 paragraph."
    ink.didChangeText()
    let inner = (ink.string as NSString).range(of: "manually shorter 👋")
    ink.setSelectedRange(inner)
    XCTAssertEqual(activity.previewSelection, inner)
    window.makeFirstResponder(nil)
    XCTAssertEqual(activity.previewSelection, inner, "Moving to instructions must retain the scope")
    settings.setModel("fixture-sol", provider: .openRouter)
    activity.rewriteRequest += 1
    try await waitUntil(host) { activity.revision == 2 && !activity.working }
    XCTAssertEqual(activity.preview, "A clearer paragraph.")
    XCTAssertEqual(transport.models, ["fixture", "fixture-sol"], "A saved model switch applies to the next request")
    XCTAssertEqual(activity.previewSelection.length, 0)
    XCTAssertTrue(transport.prompts[1].contains("Current draft (text to edit):\nmanually shorter 👋"))
    XCTAssertFalse(transport.prompts[1].contains("A manually shorter"))
    XCTAssertNil(applied, "Rewriting a pending suggestion cannot apply it")

    let revised = try XCTUnwrap(descendants(host).compactMap { $0 as? WritingInkTextView }.first)
    let retryRange = (revised.string as NSString).range(of: "clearer")
    // Selection made in the other (compact inline) editor must highlight the canvas too.
    activity.previewSelection = retryRange
    try await settle(host)
    XCTAssertEqual(revised.selectedRange(), retryRange)
    transport.failNext = true
    activity.rewriteRequest += 1
    try await waitUntil(host) { transport.prompts.count == 3 && !activity.working }
    XCTAssertEqual(activity.preview, "A clearer paragraph.")
    XCTAssertEqual(activity.previewSelection, retryRange, "Failed rewrite retains the prior selection")
    XCTAssertEqual(activity.revision, 2)
    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
    host.cacheDisplay(in: host.bounds, to: bitmap)
    try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: "/tmp/cove-visible-writing-error.png"))
    activity.applyRequest += 1
    try await waitUntil(host) { applied != nil }
    XCTAssertEqual(applied, "Hi 👋 Maya,\n\nA clearer paragraph.\n\nThanks, Santi")
    XCTAssertNil(activity.preview)
    XCTAssertEqual(transport.prompts.count, 3, "Scoped edits use one writer call each and no planner")
  }

  private func settle(_ host: NSView) async throws {
    for _ in 0..<5 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(20)) }
  }
  private func waitUntil(_ host: NSView, _ predicate: () -> Bool) async throws {
    for _ in 0..<150 {
      host.layoutSubtreeIfNeeded()
      if predicate() { try await settle(host); return }
      try await Task.sleep(for: .milliseconds(10))
    }
    XCTFail("Compose did not complete its expected transition")
  }
  private func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap { descendants($0) } }
}

private struct SelectionFlowHost: View {
  let original: String
  let selection: NSRange
  @Bindable var activity: WritingActivity
  let settings: AIProviderSettings
  let applied: (String) -> Void
  @State private var draft = ""
  var body: some View {
    HStack {
      if let preview = activity.preview {
        WritingCanvasPreview(text: preview, animated: false,
          onEdit: { activity.preview = $0 }, onSelection: { activity.previewSelection = $0 }, selectedRange: activity.previewSelection)
          .id(activity.revision)
      }
      AIWritingPanel(draft: $draft, selection: selection, activity: activity, reviewOnCanvas: true,
        providerSettings: settings, onApply: { draft = $0; applied($0) }).frame(width: 390)
    }.onAppear { draft = original }
  }
}

private final class SelectionRewriteHTTP: HTTPTransport {
  var prompts: [String] = []
  var models: [String] = []
  var failNext = false
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
    models.append(body["model"] as? String ?? "")
    let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
    prompts.append(messages.compactMap { $0["content"] as? String }.joined(separator: "\n"))
    let value = prompts.count == 1 ? "A shorter paragraph." : "clearer"
    let data = try JSONSerialization.data(withJSONObject: ["choices": [["message": ["content": value]]]])
    return (data, try XCTUnwrap(HTTPURLResponse(url: XCTUnwrap(request.url), statusCode: failNext ? 400 : 200,
                                               httpVersion: nil, headerFields: nil)))
  }
}
