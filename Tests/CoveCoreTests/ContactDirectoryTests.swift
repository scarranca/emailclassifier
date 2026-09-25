import XCTest

@testable import CoveCore

final class ContactDirectoryTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_800_000_000)
  private func mail(
    _ id: String, sender: String = "Person", email: String = "person@example.com",
    to: String = "me@example.com", labels: Set<String> = ["INBOX"],
    date: Date? = nil, thread: String = ""
  ) -> Mail {
    Mail(
      id: id, threadID: thread, sender: sender, senderEmail: email, to: to,
      subject: "Subject \(id)", body: "Body", date: date ?? now, labels: labels)
  }

  func testNormalizesDeduplicatesAndUsesSavedFieldsWithoutInventingCompany() {
    let first = mail("1", email: " Person@EXAMPLE.com ")
    let second = mail("2", sender: "A different header", date: now.addingTimeInterval(-60))
    let record = ContactRecord(
      name: "Preferred Person", email: "PERSON@example.com", company: "Acme")
    let contacts = ContactDirectory.build(
      mails: [second, first, first], records: [record], accountEmail: "me@example.com")
    XCTAssertEqual(contacts.count, 1)
    XCTAssertEqual(contacts[0].email, "person@example.com")
    XCTAssertEqual(contacts[0].name, "Preferred Person")
    XCTAssertEqual(contacts[0].messages.map(\.id), ["1", "2"])
    XCTAssertEqual(contacts[0].record?.company, "Acme")
    let inferred = ContactDirectory.build(
      mails: [first], records: [], accountEmail: "me@example.com")
    XCTAssertNil(inferred[0].record)
  }

  func testOutgoingRecipientListsExcludeSelfAndDeduplicateParticipants() {
    let sent = mail(
      "sent", email: "ME@example.com",
      to:
        "\"Doe, Jane\" <jane@example.com>, jane@example.com, Me <me@example.com>, other@example.com",
      labels: ["SENT"])
    let contacts = ContactDirectory.build(
      mails: [sent], records: [], accountEmail: "me@example.com")
    XCTAssertEqual(Set(contacts.map(\.email)), ["jane@example.com", "other@example.com"])
    XCTAssertEqual(contacts.first { $0.email == "jane@example.com" }?.name, "Doe, Jane")
    XCTAssertTrue(contacts.allSatisfy { $0.messages.count == 1 })
  }

  func testExcludesDraftsSpamTrashAndMalformedAddresses() {
    let contacts = ContactDirectory.build(
      mails: [
        mail("draft", labels: ["DRAFT"]), mail("spam", labels: ["SPAM"]),
        mail("trash", labels: ["TRASH"]), mail("bad", email: "not an email"),
        mail("self", email: "me@example.com"),
      ], records: [], accountEmail: "me@example.com")
    XCTAssertTrue(contacts.isEmpty)
  }

  func testRecentCountsBoundDatesAndConversationsDeduplicateThreads() {
    let contact = ContactDirectory.build(
      mails: [
        mail("old", date: now.addingTimeInterval(-31 * 86400)),
        mail("recent1", date: now.addingTimeInterval(-100), thread: "thread"),
        mail("recent2", date: now.addingTimeInterval(-50), thread: "thread"),
        mail("future", date: now.addingTimeInterval(86400)),
      ], records: [], accountEmail: "me@example.com")[0]
    XCTAssertEqual(
      contact.messageCount(since: now.addingTimeInterval(-30 * 86400), through: now), 2)
    XCTAssertEqual(contact.recentConversations.map(\.id), ["future", "recent2", "old"])
  }

  func testLocalRecordsPersistSeparatelyFromMailAndOtherAccounts() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let accountA = try Database(url: root.appendingPathComponent("a.sqlite"))
    let accountB = try Database(url: root.appendingPathComponent("b.sqlite"))
    let record = ContactRecord(
      name: "New person", email: "new@example.com", phone: "+1 555 0100",
      group: "Clients", notes: "Met at a conference", isFavorite: true)
    try accountA.save([record], key: "contacts")
    try accountA.saveMailSnapshot([mail("1")])
    let loaded = try accountA.load([ContactRecord].self, key: "contacts")
    XCTAssertEqual(loaded, [record])
    XCTAssertNil(try accountB.load([ContactRecord].self, key: "contacts"))
    let contacts = ContactDirectory.build(
      mails: [], records: loaded ?? [], accountEmail: "me@example.com")
    XCTAssertEqual(contacts.count, 1)
    XCTAssertNil(contacts[0].lastMessage)
    XCTAssertTrue(contacts[0].messages.isEmpty)
  }

  func testEmailAndReservedGroupValidation() {
    XCTAssertTrue(ContactDirectory.isValidEmail("Person+tag@example.com"))
    for invalid in [
      "person", "person@example", "one@example.com,two@example.com",
      "p@example.com\r\nBcc:x@example.com", "Person <p@example.com>",
    ] {
      XCTAssertFalse(ContactDirectory.isValidEmail(invalid), invalid)
    }
    XCTAssertFalse(ContactDirectory.isValidGroup(" ALL CONTACTS "))
    XCTAssertFalse(ContactDirectory.isValidGroup("Favorites"))
    XCTAssertTrue(ContactDirectory.isValidGroup("Clients"))
    XCTAssertTrue(ContactDirectory.isValidGroup(""))
  }
}
