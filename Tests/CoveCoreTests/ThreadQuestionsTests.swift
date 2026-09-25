import XCTest

@testable import CoveCore

final class ThreadQuestionsTests: XCTestCase {
  private func mail(
    _ id: String, body: String = "Please approve the design by Friday.",
    labels: Set<String> = ["INBOX"]
  ) -> Mail {
    Mail(
      id: id, threadID: "thread1", sender: id, senderEmail: "\(id)@example.com",
      subject: "Launch", body: body, date: Date(timeIntervalSince1970: Double(id) ?? 0),
      labels: labels)
  }
  func testCandidatesShareBudgetAndRetainSelectedMessageInLongThreads() {
    let messages = (0..<40).map {
      mail(String($0), body: String(repeating: "Café 🌊 ", count: 5_000))
    }
    let prepared = SourcePassages(messages: messages, selectedID: "0")
    XCTAssertEqual(prepared.totalMessages, 40)
    XCTAssertEqual(prepared.entries.count, 20)
    XCTAssertTrue(prepared.entries.contains { $0.mail.id == "0" })
    XCTAssertTrue(prepared.entries.contains { $0.mail.id == "39" })
    XCTAssertTrue(prepared.limited)
    let passages = prepared.entries.flatMap(\.passages)
    XCTAssertLessThanOrEqual(passages.count, 100)
    XCTAssertLessThanOrEqual(passages.reduce(0) { $0 + $1.utf8.count + 1 }, 24_000)
    XCTAssertTrue(
      prepared.entries.allSatisfy { entry in
        entry.passages.allSatisfy { entry.mail.body.contains($0) && $0.utf8.count <= 1_000 }
      })
  }
  func testCandidatesExcludeDraftsTrashSpamAndDuplicates() {
    let prepared = SourcePassages(
      messages: [
        mail("1"), mail("1"), mail("2", labels: ["DRAFT"]),
        mail("3", labels: ["TRASH"]), mail("4", labels: ["SPAM"]), mail("local-draft"),
        mail("5", body: "Reply", labels: ["SENT"]),
      ], selectedID: "1")
    XCTAssertEqual(Set(prepared.entries.map { $0.mail.id }), ["1", "5"])
    XCTAssertEqual(prepared.totalMessages, 2)
    XCTAssertFalse(prepared.limited)
    let spaced = SourcePassages(
      messages: [mail("1", body: "Hi Alex,\n\nPlease review by Friday.\n\nThank you.\n")],
      selectedID: "1")
    XCTAssertFalse(spaced.limited, "Removing blank separators is not an input-limit truncation")
  }
  func testThreadSelectionMapsEachChoiceToItsOwnSourceAndCapsToThree() async throws {
    let prepared = SourcePassages(
      messages: (0..<4).map { mail(String($0), body: "First \($0).\nAnswer \($0).") },
      selectedID: "0")
    let client = JevClient(
      transport: MockHTTP { request in
        let payload = try XCTUnwrap(
          try JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
        let state = try XCTUnwrap(payload["state"] as? [String: Any])
        let messages = try XCTUnwrap(state["messages"] as? [[String: Any]])
        let questions = try XCTUnwrap(payload["questions"] as? [String: [String: Any]])
        XCTAssertEqual(questions.count, 4)
        XCTAssertEqual(messages.count, 4)
        var answers: [String: Any] = [:]
        for index in messages.indices {
          let key = "message_\(index)"
          let criteria = try XCTUnwrap(questions[key]?["criteria"] as? [String: String])
          XCTAssertEqual(criteria["1"], prepared.entries[index].passages[1])
          XCTAssertNotNil(criteria["none"])
          XCTAssertEqual(
            messages[index]["sender"] as? String, prepared.entries[index].mail.senderEmail)
          answers[key] = ["choice": "1", "confidence": 0.95 - Double(index) / 10]
        }
        return try JSONSerialization.data(withJSONObject: ["model": "fixture", "answers": answers])
      })
    let passages = try await client.findThreadPassages(
      query: "What are the answers?", prepared: prepared, key: "fixture")
    XCTAssertEqual(passages.map { $0.mail.id }, ["1", "2", "3"])
    XCTAssertTrue(passages.allSatisfy { $0.text == "Answer \($0.mail.id)." })
  }
  func testNoMatchLowConfidenceInvalidChoiceAndInvalidConfidenceAreIgnored() async throws {
    let prepared = SourcePassages(messages: (0..<5).map { mail(String($0)) }, selectedID: "0")
    let client = JevClient(
      transport: MockHTTP { _ in
        Data(
          #"{"model":"fixture","answers":{"message_0":{"choice":"none","confidence":0.99},"message_1":{"choice":"0","confidence":0.2},"message_2":{"choice":"900","confidence":0.99},"message_3":{"choice":"0","confidence":1.2},"message_4":{"choice":"0"}}}"#
            .utf8)
      })
    let result = try await client.findThreadPassages(
      query: "Unknown", prepared: prepared, key: "fixture")
    XCTAssertTrue(result.isEmpty)
  }
  func testThreadRequestBoundsHeadersQuestionAndTotalPassageInput() async throws {
    var messages = (0..<20).map {
      mail(String($0), body: String(repeating: "Email 🌊 ", count: 8_000))
    }
    for index in messages.indices {
      messages[index].senderEmail = String(repeating: "x", count: 10_000)
      messages[index].subject = String(repeating: "y", count: 10_000)
    }
    let client = JevClient(
      transport: MockHTTP { request in
        let payload = try XCTUnwrap(
          try JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
        let state = try XCTUnwrap(payload["state"] as? [String: Any])
        XCTAssertLessThanOrEqual((state["question"] as! String).utf8.count, 2_000)
        let messages = try XCTUnwrap(state["messages"] as? [[String: Any]])
        var totalBytes = 0
        for message in messages {
          XCTAssertLessThanOrEqual((message["sender"] as! String).utf8.count, 320)
          XCTAssertLessThanOrEqual((message["subject"] as! String).utf8.count, 500)
          totalBytes += (message["passages"] as! [String]).reduce(0) { $0 + $1.utf8.count }
        }
        XCTAssertLessThanOrEqual(totalBytes, 24_000)
        XCTAssertLessThan(request.httpBody!.count, 100_000)
        return Data(#"{"model":"fixture","answers":{}}"#.utf8)
      })
    _ = try await client.findThreadPassages(
      query: String(repeating: "q", count: 30_000),
      prepared: SourcePassages(messages: messages, selectedID: "0"), key: "fixture")
  }
  func testEmptyThreadMakesNoModelRequest() async throws {
    let client = JevClient(
      transport: MockHTTP { _ in
        XCTFail("No request expected")
        return Data()
      })
    let result = try await client.findThreadPassages(
      query: "Question", prepared: SourcePassages(messages: [], selectedID: ""), key: "")
    XCTAssertTrue(result.isEmpty)
  }
  func testGmailThreadFetchDecodesEveryMessageAndRequiresMatchingThread() async throws {
    let client = GmailClient(
      transport: MockHTTP { request in
        XCTAssertEqual(request.url?.path, "/gmail/v1/users/me/threads/thread1")
        XCTAssertEqual(
          URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first?
            .value, "full")
        XCTAssertEqual(request.httpMethod, "GET")
        return Data(
          #"{"id":"thread1","messages":[{"id":"m1","threadId":"thread1","labelIds":["INBOX"],"internalDate":"2000"},{"id":"m2","threadId":"thread1","labelIds":["SENT"],"internalDate":"1000"}]}"#
            .utf8)
      })
    let mails = try await client.thread(id: "thread1", token: "fixture")
    XCTAssertEqual(mails.map(\.id), ["m2", "m1"])
    let wrong = GmailClient(
      transport: MockHTTP { _ in Data(#"{"id":"other","messages":[]}"#.utf8) })
    do {
      _ = try await wrong.thread(id: "thread1", token: "fixture")
      XCTFail("Expected validation error")
    } catch { XCTAssertTrue(error.localizedDescription.contains("unexpected")) }
  }
  func testInvalidThreadIDNeverBecomesARequestPath() async throws {
    let client = GmailClient(
      transport: MockHTTP { _ in
        XCTFail("No request expected")
        return Data()
      })
    for id in ["", "../profile", "thread?token=secret", String(repeating: "a", count: 257)] {
      do {
        _ = try await client.thread(id: id, token: "fixture")
        XCTFail("Expected validation error")
      } catch { XCTAssertFalse(error.localizedDescription.contains("secret")) }
    }
  }
}
