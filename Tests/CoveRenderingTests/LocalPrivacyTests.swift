import CoveCore
import XCTest

@testable import Cove

@MainActor final class LocalPrivacyTests: XCTestCase {
  func testConfirmedErasureClearsUIAndStorageButBusyStatePreventsIt() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let db = try Database(
      url: directory.appendingPathComponent("mail.sqlite"),
      encryptionKey: Data(repeating: 1, count: 32), namespace: "synthetic")
    try db.saveMailSnapshot(Samples.mail, historyID: "private-cursor")
    let store = try AppStore(
      database: db, accountEmail: "fixture@example.com",
      gmail: GmailClient(transport: NoPrivacyNetwork()), gmailTokenProvider: { "synthetic" },
      syncClock: { Date() })
    store.isSample = true  // No real account or Keychain access in this destructive fixture.
    store.preferences.memories = ["A private memory"]
    store.persistPreferences()
    store.busy = true
    store.eraseLocalMailbox()
    XCTAssertFalse(store.mails.isEmpty)
    XCTAssertFalse(try db.loadMail().isEmpty)
    store.busy = false
    store.eraseLocalMailbox()
    XCTAssertFalse(store.entered)
    XCTAssertTrue(store.mails.isEmpty)
    XCTAssertTrue(store.events.isEmpty)
    XCTAssertTrue(store.contactRecords.isEmpty)
    XCTAssertTrue(store.preferences.memories.isEmpty)
    XCTAssertNil(store.selectedID)
    XCTAssertEqual(try db.loadMail(), [])
    XCTAssertNil(try db.load(Preferences.self, key: "preferences"))
    XCTAssertNil(try db.load(String.self, key: "gmailHistoryID"))
  }
}

private struct NoPrivacyNetwork: HTTPTransport {
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    XCTFail("Local erasure must not contact any provider")
    throw CoveError.message("Unexpected network request")
  }
}
