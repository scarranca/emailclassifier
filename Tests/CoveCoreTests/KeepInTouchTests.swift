import XCTest

@testable import CoveCore

final class KeepInTouchTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_800_000_000)

  private func personal(_ id: String = "personal", email: String = "jane@example.com") -> Mail {
    Mail(
      id: id, sender: "Jane", senderEmail: email, subject: "Coffee?", body: "Let's catch up.",
      date: now.addingTimeInterval(-60),
      decision: Decision(
        category: .people, confidence: 0.95, needsReply: 0.8, urgent: 0, model: "Jev"),
      isBulkOrAutomated: false)
  }

  func testOnlyConfidentPersonalAndWorkConversationsQualify() {
    let person = personal()
    XCTAssertTrue(KeepInTouch.isPersonalCorrespondence(person))
    var work = person
    work.decision?.category = .work
    XCTAssertTrue(KeepInTouch.isPersonalCorrespondence(work))
    for category in [MailCategory.newsletters, .updates, .purchases, .other] {
      var other = person
      other.decision?.category = category
      XCTAssertFalse(KeepInTouch.isPersonalCorrespondence(other), category.rawValue)
    }
    var uncertain = person
    uncertain.decision?.confidence = 0.69
    XCTAssertFalse(KeepInTouch.isPersonalCorrespondence(uncertain))
    uncertain.decision = nil
    XCTAssertFalse(KeepInTouch.isPersonalCorrespondence(uncertain))
  }

  func testBulkHeadersAndGmailCategoriesOverridePersonalClassification() {
    for label in [
      "CATEGORY_PROMOTIONS", "CATEGORY_UPDATES", "CATEGORY_SOCIAL", "CATEGORY_FORUMS", "SPAM",
      "TRASH", "DRAFT", "SENT",
    ] {
      var mail = personal()
      mail.labels.insert(label)
      XCTAssertFalse(KeepInTouch.isPersonalCorrespondence(mail), label)
    }
    var mail = personal()
    mail.isBulkOrAutomated = true
    XCTAssertFalse(KeepInTouch.isPersonalCorrespondence(mail))
    mail.isBulkOrAutomated = nil
    XCTAssertFalse(
      KeepInTouch.isPersonalCorrespondence(mail), "Legacy snapshots wait for header refresh")
    for address in [
      "no-reply@example.com", "No_Reply+abc@example.com", "notifications@example.com",
      "marketing@example.com", "mailer-daemon@example.com", "not an email",
    ] {
      XCTAssertFalse(KeepInTouch.isPersonalCorrespondence(personal(email: address)), address)
    }
    XCTAssertTrue(KeepInTouch.isPersonalCorrespondence(personal(email: "jane+project@example.com")))
  }

  func testHeaderParsingTreatsExplicitNoAsHumanAndListOrAutomationAsBulk() throws {
    func parsed(_ name: String, _ value: String) throws -> Mail {
      let json: [String: Any] = [
        "id": "message", "threadId": "thread", "labelIds": ["INBOX"],
        "payload": [
          "headers": [
            ["name": "From", "value": "Jane <jane@example.com>"],
            ["name": name, "value": value],
          ]
        ],
      ]
      return try JSONDecoder().decode(
        GmailMessage.self, from: JSONSerialization.data(withJSONObject: json)
      ).mail()
    }
    for (name, value) in [
      ("List-ID", "team.example.com"), ("list-unsubscribe", "<https://example.com/unsubscribe>"),
      ("AUTO-SUBMITTED", "auto-generated"),
      ("Auto-Submitted", "auto-replied; owner-email=bot@example.com"),
      ("Precedence", " BULK "), ("Precedence", "list"),
    ] {
      XCTAssertEqual(try parsed(name, value).isBulkOrAutomated, true, name)
    }
    XCTAssertEqual(try parsed("Auto-Submitted", " no ").isBulkOrAutomated, false)
    XCTAssertEqual(try parsed("Precedence", "normal").isBulkOrAutomated, false)
  }

  func testLatestMessagePerSenderMustQualifyAndOwnFutureMailIsExcluded() {
    var old = personal("old")
    old.date = now.addingTimeInterval(-500)
    var latest = personal("latest", email: "JANE@example.com")
    latest.date = now.addingTimeInterval(-50)
    var earlierContact = personal("earlier", email: "alex@example.com")
    earlierContact.date = now.addingTimeInterval(-100)
    var future = personal("future", email: "future@example.com")
    future.date = now.addingTimeInterval(100)
    let own = personal("own", email: "ME@example.com")
    XCTAssertEqual(
      KeepInTouch.candidates(
        mails: [old, latest, earlierContact, future, own], accountEmail: " me@example.com ",
        now: now
      ).map(\.id), ["earlier", "latest"])
    latest.decision?.category = .newsletters
    XCTAssertEqual(
      KeepInTouch.candidates(
        mails: [old, latest, earlierContact], accountEmail: "me@example.com", now: now
      ).map(\.id), ["earlier"],
      "Do not fall back to an older personal-looking message from a marketing sender")
  }

  func testOptionalMetadataPreservesLegacySnapshotsAndIsRefreshedWithoutLosingDrafts() throws {
    var cached = personal()
    cached.draft = "Unsent work"
    cached.snoozedUntil = now.addingTimeInterval(60)
    var object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(cached)) as? [String: Any])
    object.removeValue(forKey: "isBulkOrAutomated")
    let legacy = try JSONDecoder().decode(
      Mail.self, from: JSONSerialization.data(withJSONObject: object))
    XCTAssertNil(legacy.isBulkOrAutomated)
    var refreshed = personal()
    refreshed.isBulkOrAutomated = true
    refreshed.decision = nil
    let merged = try XCTUnwrap(
      GmailSyncResult(messages: [refreshed], historyID: "new").applying(to: [legacy]).first)
    XCTAssertEqual(merged.isBulkOrAutomated, true)
    XCTAssertEqual(merged.draft, cached.draft)
    XCTAssertEqual(merged.decision, cached.decision)
    XCTAssertEqual(merged.snoozedUntil, cached.snoozedUntil)
  }
}
