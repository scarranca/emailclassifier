import CSQLite
import XCTest

@testable import CoveCore

final class MailboxPersistenceTests: XCTestCase {
  private func withDatabase(_ operation: (URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try operation(directory.appendingPathComponent("mailbox.sqlite"))
  }

  func testLegacySnapshotAndIndividualEditsSurviveRestart() throws {
    try withDatabase { url in
      var original = Samples.mail[0]
      original.id = "existing"
      var edited = original
      edited.draft = "A revised reply with café 🌊"
      edited.labels.remove("UNREAD")
      let newDraft = Mail(
        id: "local-new", sender: "Me", senderEmail: "me@example.com", subject: "New draft",
        body: "Persisted without rewriting the snapshot", labels: ["DRAFT"])
      do {
        let database = try Database(url: url)
        try database.save([original], key: "mail")
        XCTAssertEqual(try database.loadMail(), [original])
        try database.saveMessage(edited)
        try database.saveMessage(newDraft)
        XCTAssertEqual(try database.load([Mail].self, key: "mail"), [original])
      }
      let reopened = try Database(url: url)
      XCTAssertEqual(try reopened.loadMail(), [edited, newDraft])
    }
  }

  func testSnapshotRemovalDoesNotResurrectAnOldOverride() throws {
    try withDatabase { url in
      do {
        let database = try Database(url: url)
        try database.saveMailSnapshot([Samples.mail[0]], historyID: "100")
        var edited = Samples.mail[0]
        edited.draft = "An edit before this message was deleted"
        try database.saveMessage(edited)
        try database.save("preserved", key: "mailOverrideOther")
        try database.saveMailSnapshot([], historyID: "101")
      }
      let reopened = try Database(url: url)
      XCTAssertEqual(try reopened.loadMail(), [])
      XCTAssertEqual(try reopened.load(String.self, key: "gmailHistoryID"), "101")
      XCTAssertEqual(try reopened.load(String.self, key: "mailOverrideOther"), "preserved")
    }
  }

  func testSnapshotAndOverridesRollBackWhenCursorWriteFails() throws {
    try withDatabase { url in
      let original = Samples.mail[0]
      var edited = original
      edited.draft = "Must survive failed synchronization"
      do {
        let database = try Database(url: url)
        try database.saveMailSnapshot([original], historyID: "before", decodingVersion: 1)
        try database.saveMessage(edited)
        var handle: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &handle), SQLITE_OK)
        defer { sqlite3_close(handle) }
        // Fail the cursor write, after the transaction has replaced mail and deleted overrides.
        XCTAssertEqual(
          sqlite3_exec(
            handle,
            "CREATE TRIGGER reject_cursor BEFORE INSERT ON records WHEN NEW.key='gmailHistoryID' BEGIN SELECT RAISE(ABORT,'simulated cursor failure'); END;",
            nil, nil, nil), SQLITE_OK)
        XCTAssertThrowsError(
          try database.saveMailSnapshot([], historyID: "after", decodingVersion: 2))
        XCTAssertEqual(try database.load([Mail].self, key: "mail"), [original])
        XCTAssertEqual(try database.loadMail(), [edited])
        XCTAssertEqual(try database.load(String.self, key: "gmailHistoryID"), "before")
        XCTAssertEqual(try database.load(Int.self, key: "mailDecodingVersion"), 1)
      }
      let reopened = try Database(url: url)
      XCTAssertEqual(try reopened.loadMail(), [edited])
      XCTAssertEqual(try reopened.load(String.self, key: "gmailHistoryID"), "before")
      XCTAssertEqual(try reopened.load(Int.self, key: "mailDecodingVersion"), 1)
    }
  }

  func testSnapshotWithoutCursorPreservesExistingCursor() throws {
    try withDatabase { url in
      let database = try Database(url: url)
      let mail = Samples.mail[0]
      try database.saveMailSnapshot([], historyID: "existing-cursor")
      try database.saveMailSnapshot([mail])
      XCTAssertEqual(try database.load(String.self, key: "gmailHistoryID"), "existing-cursor")
      XCTAssertEqual(try database.loadMail(), [mail])
    }
  }

  func testPaginationSurvivesRestartAndIncrementalSync() throws {
    try withDatabase { url in
      do {
        let database = try Database(url: url)
        try database.saveMailSnapshot(
          [], historyID: "100", nextPage: "older-page", updatesPagination: true)
        try database.saveMailSnapshot([], historyID: "101")
      }
      let reopened = try Database(url: url)
      XCTAssertEqual(try reopened.load(String.self, key: "gmailNextPage"), "older-page")
      try reopened.saveMailSnapshot([], historyID: "102", updatesPagination: true)
      XCTAssertEqual(try reopened.load(String.self, key: "gmailNextPage"), "")
    }
  }

  func testDecodingVersionCommitsWithSnapshotAndNilPreservesItAcrossRestart() throws {
    try withDatabase { url in
      let mail = Samples.mail[0]
      do {
        let database = try Database(url: url)
        try database.saveMailSnapshot([], historyID: "before", decodingVersion: 1)
        try database.saveMailSnapshot(
          [mail], historyID: "after", decodingVersion: GmailMessage.decodingVersion)
        XCTAssertEqual(
          try database.load(Int.self, key: "mailDecodingVersion"), GmailMessage.decodingVersion)
        try database.saveMailSnapshot([mail])
      }
      let reopened = try Database(url: url)
      XCTAssertEqual(try reopened.loadMail(), [mail])
      XCTAssertEqual(try reopened.load(String.self, key: "gmailHistoryID"), "after")
      XCTAssertEqual(
        try reopened.load(Int.self, key: "mailDecodingVersion"), GmailMessage.decodingVersion)
    }
  }
}
