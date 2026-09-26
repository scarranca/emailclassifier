import AppKit
import CoveCore
import SwiftUI
import XCTest
@testable import Cove

@MainActor final class SettingsLayoutTests: XCTestCase {
  func testSettingsSectionsRenderWithoutKeychainOrForegroundWindow() async throws {
    _ = NSApplication.shared
    DesignAssets.registerFonts()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let database = try Database(url: directory.appendingPathComponent("mail.sqlite"))
    let store = try AppStore(database: database, accountEmail: "alex@example.com", gmail: GmailClient(),
      gmailTokenProvider: { XCTFail("Layout must not contact Gmail"); return "fixture" }, syncClock: Date.init)
    store.isSample = true
    for width in [1100.0, 900.0] {
      var secretReads = 0
      let host = NSHostingView(rootView: SettingsView(store: store, readSecret: { _ in
        secretReads += 1; return nil
      }).foregroundStyle(Palette.ink))
      let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 1400),
        styleMask: [.borderless], backing: .buffered, defer: false)
      window.isReleasedWhenClosed = false; window.contentView = host
      defer { window.close() }
      for _ in 0..<8 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(30)) }
      XCTAssertFalse(window.isVisible)
      XCTAssertEqual(secretReads, 2)
      XCTAssertEqual(host.bounds.width, width, accuracy: 1)
      let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
      host.cacheDisplay(in: host.bounds, to: bitmap)
      try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        .write(to: URL(fileURLWithPath: "/tmp/cove-settings-\(Int(width)).png"))

    }
  }
}
