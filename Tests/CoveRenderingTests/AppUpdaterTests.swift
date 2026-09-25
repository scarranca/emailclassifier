import Foundation
import XCTest
@testable import Cove

@MainActor final class AppUpdaterTests: XCTestCase {
  func testRestartWaitsForWorkThenResumesExactlyOnce() {
    let updater = AppUpdater()
    var blocked = true
    var installs = 0
    var notices: [String] = []
    updater.interruptionReason = { blocked ? "Save draft" : nil }
    updater.showNotice = { notices.append($0) }
    XCTAssertTrue(updater.postponeRestart(reason: "Save draft", install: { installs += 1 }))
    XCTAssertTrue(updater.restartPending)
    XCTAssertEqual(updater.menuTitle, "Install Update and Relaunch…")
    updater.checkForUpdates()
    XCTAssertEqual(installs, 0)
    XCTAssertEqual(notices, ["Save draft", "Save draft"])
    blocked = false
    updater.checkForUpdates()
    updater.resumeRestart()
    XCTAssertEqual(installs, 1)
    XCTAssertFalse(updater.restartPending)
    XCTAssertNil(updater.status)
  }

  func testIdleRestartIsHandledBySparkle() {
    let updater = AppUpdater()
    updater.showNotice = { _ in XCTFail("Idle restart should not prompt") }
    XCTAssertFalse(updater.postponeRestart(reason: nil, install: { XCTFail("Sparkle owns the immediate restart") }))
    XCTAssertFalse(updater.restartPending)
  }

  func testOnlyConfiguredProductionBundleEnablesUpdater() throws {
    func configured(_ changes: [String: Any] = [:], arguments: [String] = []) throws -> Bool {
      let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".app")
      defer { try? FileManager.default.removeItem(at: folder) }
      try FileManager.default.createDirectory(at: folder.appendingPathComponent("Contents"), withIntermediateDirectories: true)
      var info: [String: Any] = ["CFBundleIdentifier": "ai.cove.mac", "CFBundlePackageType": "APPL",
        "CoveUpdatesEnabled": true, "SUFeedURL": "https://covemail.xyz/updates/appcast.xml",
        "SUPublicEDKey": Data(repeating: 1, count: 32).base64EncodedString()]
      info.merge(changes) { _, new in new }
      try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        .write(to: folder.appendingPathComponent("Contents/Info.plist"))
      return AppUpdater.isConfigured(bundle: try XCTUnwrap(Bundle(url: folder)), arguments: arguments)
    }
    XCTAssertTrue(try configured())
    XCTAssertFalse(try configured(arguments: ["Cove", "--qa"]))
    XCTAssertFalse(try configured(["CFBundleIdentifier": "ai.cove.qa"]))
    XCTAssertFalse(try configured(["CoveUpdatesEnabled": false]))
    XCTAssertFalse(try configured(["SUFeedURL": "http://covemail.xyz/updates/appcast.xml"]))
    XCTAssertFalse(try configured(["SUFeedURL": "https://"]))
    XCTAssertFalse(try configured(["SUPublicEDKey": "invalid"]))
  }
}
