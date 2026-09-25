import XCTest

@testable import CoveCore

final class JevAutomationTests: XCTestCase {
  private let activation = Date(timeIntervalSince1970: 2_000_000_000)
  private func message(_ id: String, seconds: Double = 1, labels: Set<String> = ["INBOX"]) -> Mail {
    Mail(
      id: id, sender: "Sender", senderEmail: "sender@example.com", subject: "A message",
      body: "Source text", date: activation.addingTimeInterval(seconds), labels: labels)
  }

  func testAutomaticCandidatesExcludeBacklogOutgoingDraftsAndStoredDecisions() {
    var decided = message("decided")
    decided.decision = Decision(
      category: .newsletters, confidence: 0.9, needsReply: 0, urgent: 0,
      model: "jev-latest")
    var selfSentWithoutLabel = message("self")
    selfSentWithoutLabel.senderEmail = "ME@example.com"
    let mail = [
      message("older", seconds: -1), message("boundary", seconds: 0),
      message("newest", seconds: 20), message("new", seconds: 10),
      message("sent", labels: ["SENT", "INBOX"]),
      message("draft", labels: ["DRAFT"]), message("local-composition"),
      message("trash", labels: ["TRASH"]), message("spam", labels: ["SPAM"]),
      decided, selfSentWithoutLabel,
    ]
    XCTAssertEqual(
      JevAutomation.candidates(in: mail, accountEmail: "me@example.com", since: activation).map(
        \.id),
      ["boundary", "new", "newest"])
  }

  func testIncomingMailDoesNotNeedToRemainInInbox() {
    let archived = message("new-incoming-archived", labels: [])
    XCTAssertTrue(
      JevAutomation.isEligible(archived, accountEmail: "me@example.com", since: activation))
    XCTAssertFalse(
      JevAutomation.isEligible(
        archived, accountEmail: "me@example.com", since: activation.addingTimeInterval(5)))
  }

  func testManualOrganizationIncludesHistoricalIncomingMailButNeverOutgoing() {
    let mail = [
      message("historical", seconds: -10_000), message("new"),
      message("sent", labels: ["SENT"]), message("local-draft", labels: ["DRAFT"]),
    ]
    XCTAssertEqual(
      JevAutomation.candidates(in: mail, accountEmail: "me@example.com").map(\.id),
      ["historical", "new"])
  }

  func testLegacyEnabledPreferencesStartNowAndNeverRetroactivelyIncludeBacklog() throws {
    var legacy = Preferences()
    legacy.autoClassify = true
    let encoded = try JSONEncoder().encode(legacy)
    let decoded = try JSONDecoder().decode(Preferences.self, from: encoded)
    XCTAssertNil(decoded.autoClassifySince)
    let migrated = JevAutomation.initialized(decoded, at: activation)
    XCTAssertTrue(migrated.autoClassify)
    XCTAssertEqual(migrated.autoClassifySince, activation)
    XCTAssertFalse(
      JevAutomation.isEligible(
        message("old", seconds: -1), accountEmail: "me@example.com",
        since: migrated.autoClassifySince))
    XCTAssertEqual(
      JevAutomation.initialized(migrated, at: activation.addingTimeInterval(500)).autoClassifySince,
      activation)
    XCTAssertNil(JevAutomation.initialized(Preferences(), at: activation).autoClassifySince)
  }

  func testFailedOlderMessageCooldownDoesNotStarveLaterIncomingMail() {
    let old = message("oldest-new", seconds: 1)
    let later = message("later-new", seconds: 2)
    let retry = activation.addingTimeInterval(600)
    let first = JevAutomation.candidates(
      in: [old, later], accountEmail: "me@example.com",
      since: activation, retryAfter: [old.id: retry], now: activation.addingTimeInterval(10))
    XCTAssertEqual(first.map(\.id), [later.id])
    let afterCooldown = JevAutomation.candidates(
      in: [old, later], accountEmail: "me@example.com",
      since: activation, retryAfter: [old.id: retry], now: retry)
    XCTAssertEqual(afterCooldown.map(\.id), [old.id, later.id])
  }

  func testGlobalFailuresStopBatchButInvalidMessageResponseDoesNot() {
    for status in [401, 402, 403, 429, 500, 503] {
      XCTAssertTrue(
        JevAutomation.shouldStopBatch(after: HTTPFailure(statusCode: status, message: "Fixture")))
    }
    XCTAssertTrue(JevAutomation.shouldStopBatch(after: CancellationError()))
    XCTAssertTrue(JevAutomation.shouldStopBatch(after: URLError(.notConnectedToInternet)))
    XCTAssertFalse(
      JevAutomation.shouldStopBatch(after: CoveError.message("Invalid decision for this message")))
    XCTAssertFalse(
      JevAutomation.shouldStopBatch(
        after: HTTPFailure(statusCode: 400, message: "Invalid message input")))
  }

  func testRestartPreservesActivationAndStoredDecisionPreventsAnotherCall() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("mail.sqlite")
    var preferences = Preferences()
    preferences.autoClassify = true
    preferences.autoClassifySince = activation
    var organized = message("already-organized")
    do {
      let database = try Database(url: url)
      try database.save(preferences, key: "preferences")
      try database.saveMailSnapshot([organized])
      organized.decision = Decision(
        category: .work, confidence: 0.8, needsReply: 0.7, urgent: 0.1,
        model: "jev-latest")
      try database.saveMessage(organized)
    }
    let reopened = try Database(url: url)
    let restored = try XCTUnwrap(reopened.load(Preferences.self, key: "preferences"))
    XCTAssertEqual(restored.autoClassifySince, activation)
    XCTAssertTrue(
      JevAutomation.candidates(
        in: try reopened.loadMail(), accountEmail: "me@example.com",
        since: restored.autoClassifySince
      ).isEmpty)
  }
}
