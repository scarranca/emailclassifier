import XCTest

@testable import CoveCore

final class MailboxRetrievalTests: XCTestCase {
  private func mail(_ id: Int, body: String = "Routine update", labels: Set<String> = ["INBOX"])
    -> Mail
  {
    Mail(
      id: String(id), threadID: "thread-\(id)", sender: "Sender", senderEmail: "sender@example.com",
      subject: "Update", body: body, date: Date(timeIntervalSince1970: Double(id)), labels: labels)
  }

  func testRetrievalFindsOlderMessagesAndLatePassagesAcrossDifferentThreads() throws {
    let detail = "The café launch deadline is Friday at 3 PM."
    var old = mail(0, body: String(repeating: "Unrelated introduction.\n", count: 3_000) + detail)
    old.subject = "Café website"
    let messages = (1...45).map { mail($0) } + [old]
    let result = try SourcePassages(mailbox: messages, query: "What is the cafe launch deadline?")
    XCTAssertEqual(result.totalMessages, 46)
    XCTAssertEqual(result.entries.count, 20)
    XCTAssertEqual(result.entries.first?.mail.id, old.id)
    XCTAssertTrue(result.entries.first?.passages.first?.contains(detail) == true)
    XCTAssertTrue(result.limited)
    XCTAssertEqual(Set(result.entries.map { $0.mail.threadID }).count, 20)
    XCTAssertTrue(
      result.entries.allSatisfy { entry in entry.passages.allSatisfy(entry.mail.body.contains) })
    let bytes = result.entries.flatMap(\.passages).reduce(0) { $0 + $1.utf8.count + 1 }
    XCTAssertLessThanOrEqual(bytes, 24_000)
  }

  func testEligibilityAndUnicodeBudgetExcludePrivateDrafts() throws {
    var local = mail(4, body: "PRIVATE LOCAL")
    local.id = "local-unsent"
    let kept = mail(5, body: String(repeating: "Café 🌊 launch\n", count: 3_000), labels: ["SENT"])
    let result = try SourcePassages(
      mailbox: [
        mail(1, body: "PRIVATE DRAFT", labels: ["DRAFT"]),
        mail(2, body: "PRIVATE SPAM", labels: ["SPAM"]),
        mail(3, body: "PRIVATE TRASH", labels: ["TRASH"]), local, kept, kept,
        mail(6, body: "\n \u{200B}"),
      ], query: "cafe")
    XCTAssertEqual(result.totalMessages, 2)
    XCTAssertEqual(result.entries.map { $0.mail.id }, ["5"])
    XCTAssertTrue(result.limited)
    XCTAssertTrue(
      result.entries[0].passages.allSatisfy { kept.body.contains($0) && $0.utf8.count <= 1_000 })
    XCTAssertFalse(result.entries.flatMap(\.passages).joined().contains("PRIVATE"))
  }

  func testNoKeywordOverlapFallsBackToRecentMessagesDeterministically() throws {
    let messages = (0..<30).map { mail($0) }
    let first = try SourcePassages(mailbox: messages, query: "What should I do?")
    let reversed = try SourcePassages(mailbox: messages.reversed(), query: "What should I do?")
    XCTAssertEqual(first.entries.map { $0.mail.id }, (10..<30).reversed().map(String.init))
    XCTAssertEqual(first.entries.map { $0.mail.id }, reversed.entries.map { $0.mail.id })
  }

  func testCandidateWindowsKeepAdjacentDatesAndWordsAtBoundaries() throws {
    let body =
      String(repeating: "x", count: 795)
      + "\nCafé community launch\nThursday, September 24 at 3 PM\nPlease confirm."
    let prepared = try SourcePassages(
      mailbox: [mail(1, body: body)], query: "When is the cafe community launch?")
    XCTAssertTrue(
      prepared.entries[0].passages.contains {
        $0.contains("Café community launch\nThursday, September 24 at 3 PM")
      })
    XCTAssertTrue(prepared.entries[0].passages.allSatisfy(body.contains))
  }

  func testMailboxModelUsesIndependentSourcesAndReturnsOnlyOriginalChoices() async throws {
    let prepared = try SourcePassages(
      mailbox: [mail(1, body: "Launch Friday"), mail(2, body: "Launch Monday")], query: "launch")
    let client = JevClient(
      transport: MockHTTP { request in
        let payload = try XCTUnwrap(
          try JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
        let state = try XCTUnwrap(payload["state"] as? [String: Any])
        XCTAssertEqual(state["scope"] as? String, "downloaded_mail_from_different_conversations")
        let questions = try XCTUnwrap(payload["questions"] as? [String: [String: Any]])
        XCTAssertTrue(
          (questions["message_0"]?["instructions"] as? String)?.contains("unrelated conversations")
            == true)
        XCTAssertTrue(
          (questions["message_0"]?["instructions"] as? String)?.contains("untrusted") == true)
        XCTAssertLessThanOrEqual((state["question"] as! String).utf8.count, 2_000)
        return Data(
          #"{"model":"fixture","answers":{"message_0":{"choice":"0","confidence":0.9},"message_1":{"choice":"none","confidence":0.9}}}"#
            .utf8)
      })
    let result = try await client.findMailboxPassages(
      query: String(repeating: "launch ", count: 1_000), prepared: prepared, key: "fixture")
    XCTAssertEqual(result.map { $0.mail.id }, ["2"])
    XCTAssertEqual(result.first?.text, "Launch Monday")
  }
}
