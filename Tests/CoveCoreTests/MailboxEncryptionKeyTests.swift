import XCTest

@testable import CoveCore

final class MailboxEncryptionKeyTests: XCTestCase {
  func testNewKeyIsPersistedOnceAndReusedAcrossReopens() throws {
    var saved: String?
    var writes = 0
    let key = try MailboxEncryptionKey.load(
      existingEncryptedStore: false, read: { saved },
      write: {
        saved = $0
        writes += 1
      })
    XCTAssertEqual(key.count, 32)
    let reopened = try MailboxEncryptionKey.load(
      existingEncryptedStore: true, read: { saved }, write: { _ in writes += 1 })
    XCTAssertEqual(key, reopened)
    XCTAssertEqual(writes, 1)
  }

  func testMissingCorruptOrUnavailableKeysNeverGetSilentlyReplaced() throws {
    var writes = 0
    for value: String? in [nil, "not-base64", Data(repeating: 0, count: 16).base64EncodedString()] {
      XCTAssertThrowsError(
        try MailboxEncryptionKey.load(
          existingEncryptedStore: true, read: { value }, write: { _ in writes += 1 }))
    }
    XCTAssertThrowsError(
      try MailboxEncryptionKey.load(
        existingEncryptedStore: false,
        read: { throw CoveError.message("Keychain unavailable") }, write: { _ in writes += 1 }))
    XCTAssertEqual(writes, 0)
  }

  func testConcurrentCreationUsesThePersistedWinnerAndReadbackFailureStops() throws {
    let winner = Data(repeating: 9, count: 32)
    var saved: String?
    let result = try MailboxEncryptionKey.load(
      existingEncryptedStore: false,
      read: { saved }, write: { _ in saved = winner.base64EncodedString() })
    XCTAssertEqual(result, winner)
    XCTAssertThrowsError(
      try MailboxEncryptionKey.load(
        existingEncryptedStore: false,
        read: { nil }, write: { _ in }))
  }

  func testFailedKeychainSaveDoesNotReturnAnUnrecoverableKey() {
    XCTAssertThrowsError(
      try MailboxEncryptionKey.load(
        existingEncryptedStore: false,
        read: { nil }, write: { _ in throw CoveError.message("Keychain full") }))
  }
}
