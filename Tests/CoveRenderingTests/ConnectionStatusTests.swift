import AppKit
import CoveCore
import SwiftUI
import XCTest
@testable import Cove

@MainActor final class ConnectionStatusTests: XCTestCase {
  func testConnectivityClassificationDoesNotHideSecurityOrSendWarnings() {
    for code: URLError.Code in [.cannotFindHost, .dnsLookupFailed, .cannotConnectToHost, .networkConnectionLost, .timedOut, .notConnectedToInternet] {
      XCTAssertNotNil(ConnectionIssue(URLError(code), operation: "Syncing Gmail…"))
    }
    XCTAssertEqual(ConnectionIssue(URLError(.notConnectedToInternet), operation: "Syncing Gmail…")?.title, "You’re offline")
    XCTAssertEqual(ConnectionIssue(URLError(.cannotFindHost), operation: "Syncing Gmail…")?.title, "Connection issue")
    XCTAssertNil(ConnectionIssue(URLError(.serverCertificateUntrusted), operation: "Syncing Gmail…"))
    XCTAssertNil(ConnectionIssue(URLError(.cancelled), operation: "Syncing Gmail…"))
    XCTAssertNil(ConnectionIssue(CoveError.message("Gmail didn’t confirm whether this message was sent. Check Sent before retrying."), operation: "Sending through Gmail…"))
    let nested = NSError(domain: "Wrapper", code: 1, userInfo: [NSUnderlyingErrorKey: URLError(.cannotFindHost)])
    XCTAssertNotNil(ConnectionIssue(nested, operation: "Syncing Gmail…"))
  }
  func testFailuresUseTagAndOnlyMatchingRecoveryClearsIt() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let database = try Database(url: directory.appendingPathComponent("test.sqlite"))
    let store = try AppStore(database: database, accountEmail: "test@example.com", gmail: GmailClient(),
      gmailTokenProvider: { XCTFail("No live network access"); return "" }, syncClock: Date.init)
    await store.run("Syncing Gmail…") { throw URLError(.cannotFindHost) }
    let issue = try XCTUnwrap(store.connectionIssue)
    XCTAssertNil(store.error); XCTAssertFalse(store.busy)
    await store.run("Saving locally…") { }
    XCTAssertEqual(store.connectionIssue?.id, issue.id, "Local success cannot prove network recovery")
    await store.run("Syncing Gmail…") { throw URLError(.notConnectedToInternet) }
    store.connectionRecovered(operation: "Syncing Gmail…", issueID: issue.id)
    XCTAssertNotNil(store.connectionIssue, "Old success must not clear a newer failure")
    await store.run("Syncing Gmail…") { }
    XCTAssertNil(store.connectionIssue)
    await store.run("Sending through Gmail…") { throw CoveError.message("Send unconfirmed; check Gmail Sent before retrying.") }
    XCTAssertTrue(store.error?.contains("Send unconfirmed") == true)
    XCTAssertNil(store.connectionIssue)

    _ = NSApplication.shared; DesignAssets.registerFonts()
    store.connectionIssue = ConnectionIssue(URLError(.cannotFindHost), operation: "Syncing Gmail…")
    let host = NSHostingView(rootView: ConnectionStatusTag(store: store).padding(18).frame(width: 360, height: 100, alignment: .bottomLeading).background(Palette.canvas))
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 100), styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = host
    defer { window.close() }
    for _ in 0..<8 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(30)) }
    XCTAssertFalse(window.isVisible)
    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds)); host.cacheDisplay(in: host.bounds, to: bitmap)
    try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: "/tmp/cove-connection-tag.png"))
  }
}
