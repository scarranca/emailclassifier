import AppKit
import CoveCore
import SwiftUI
import XCTest
@testable import Cove

@MainActor final class CloudSyncSettingsTests: XCTestCase {
  func testPausePersistsWithoutTouchingMailAndSettingsRenderOffscreen() async throws {
    _ = NSApplication.shared
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let db = try Database(url: directory.appendingPathComponent("mail.sqlite"),
      encryptionKey: Data(repeating: 2, count: 32), namespace: "cloud-fixture")
    var state = CloudMirrorState(); state.enabled = true; state.accountID = UUID()
    state.fingerprints = ["abc":"synthetic"]
    try db.save(state, key: "cloudMirror"); try db.saveMailSnapshot(Samples.mail)
    let store = try AppStore(database: db, accountEmail: "fixture@example.com",
      gmail: GmailClient(), gmailTokenProvider: { "fixture" }, syncClock: { Date() })
    XCTAssertTrue(store.cloudMirror.enabled)
    let original = store.mails
    store.pauseCloudSync()
    XCTAssertFalse(try XCTUnwrap(db.load(CloudMirrorState.self, key: "cloudMirror")).enabled)
    XCTAssertEqual(store.cloudMirror.accountID, state.accountID)
    XCTAssertEqual(store.mails, original)
    let host = NSHostingView(rootView: CloudSyncSettings(store: store)
      .disclosureGroupStyle(CoveDisclosureStyle()).padding(28)
      .frame(width: 760, height: 620, alignment: .topLeading)
      .background(Palette.canvas).foregroundStyle(Palette.ink))
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 620), styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = host
    defer { window.close() }
    for _ in 0..<6 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(30)) }
    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
    host.cacheDisplay(in: host.bounds, to: bitmap)
    try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: "/tmp/cove-cloud-settings.png"))
    XCTAssertTrue(store.cloudStatus.contains("Paused"))
  }
}
