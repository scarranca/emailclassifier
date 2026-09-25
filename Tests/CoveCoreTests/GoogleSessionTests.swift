import XCTest

@testable import CoveCore

final class GoogleSessionTests: XCTestCase {
  private enum PersistenceError: Error { case unavailable }

  private final class FakePersistence {
    var value: String?
    var failWrites = false
    var writes = 0

    func open() throws -> GoogleSessionStore {
      try GoogleSessionStore(
        read: { self.value },
        write: { value in
          self.writes += 1
          if self.failWrites { throw PersistenceError.unavailable }
          self.value = value
        })
    }
  }

  private let original = GoogleAccountSession(
    email: "original@example.com", clientID: "original-client",
    clientSecret: "fake-original-secret",
    refreshToken: "fake-original-refresh", calendarConnected: false)
  private let replacement = GoogleAccountSession(
    email: "replacement@example.com", clientID: "replacement-client",
    clientSecret: "fake-replacement-secret", refreshToken: "fake-replacement-refresh",
    calendarConnected: true)

  func testReplacingAccountPersistsIdentityAndAllCredentialsInOneWrite() throws {
    let persistence = FakePersistence()
    let store = try persistence.open()
    try store.commit(original)
    let priorWrites = persistence.writes

    try store.commit(replacement)

    XCTAssertEqual(persistence.writes - priorWrites, 1)
    XCTAssertEqual(store.current, replacement)
    let persisted = try JSONDecoder().decode(
      GoogleAccountSession.self, from: Data(XCTUnwrap(persistence.value).utf8))
    XCTAssertEqual(persisted.email, replacement.email)
    XCTAssertEqual(persisted.clientID, replacement.clientID)
    XCTAssertEqual(persisted.clientSecret, replacement.clientSecret)
    XCTAssertEqual(persisted.refreshToken, replacement.refreshToken)
    XCTAssertEqual(persisted.calendarConnected, replacement.calendarConnected)
  }

  func testFailedReplacementPreservesCurrentAndPersistedAccount() throws {
    let persistence = FakePersistence()
    let store = try persistence.open()
    try store.commit(original)
    let originalBytes = persistence.value
    persistence.failWrites = true

    XCTAssertThrowsError(try store.commit(replacement))

    XCTAssertEqual(store.current, original)
    XCTAssertEqual(persistence.value, originalBytes)
    XCTAssertEqual(try persistence.open().current, original)
  }

  func testRestartRestoresExactSessionWithoutWriting() throws {
    let persistence = FakePersistence()
    try persistence.open().commit(replacement)
    let writesBeforeRestart = persistence.writes

    let restarted = try persistence.open()

    XCTAssertEqual(restarted.current, replacement)
    XCTAssertEqual(persistence.writes, writesBeforeRestart)
    XCTAssertNoThrow(try restarted.current?.requireMailbox("REPLACEMENT@example.com"))
  }

  func testDifferentMailboxCannotUseSession() throws {
    XCTAssertNoThrow(try original.requireMailbox(original.email))
    XCTAssertThrowsError(try original.requireMailbox(replacement.email))
    XCTAssertThrowsError(try original.requireMailbox(""))
  }

  func testFailedDisconnectPreservesSessionAcrossRestart() throws {
    let persistence = FakePersistence()
    let store = try persistence.open()
    try store.commit(original)
    let originalBytes = persistence.value
    persistence.failWrites = true

    XCTAssertThrowsError(try store.disconnect())

    XCTAssertEqual(store.current, original)
    XCTAssertEqual(persistence.value, originalBytes)
    XCTAssertEqual(try persistence.open().current, original)
  }

  func testDisconnectClearsPersistedAndCurrentSession() throws {
    let persistence = FakePersistence()
    let store = try persistence.open()
    try store.commit(original)

    try store.disconnect()

    XCTAssertNil(store.current)
    XCTAssertNil(persistence.value)
    XCTAssertNil(try persistence.open().current)
  }

  func testCorruptPersistedSessionFailsInsteadOfSilentlySigningOut() {
    let persistence = FakePersistence()
    persistence.value = "{\"email\":\"original@example.com\"}"

    XCTAssertThrowsError(try persistence.open())
    XCTAssertEqual(persistence.writes, 0)
  }
}
