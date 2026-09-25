import XCTest

@testable import CoveCore

final class JevInputBoundsTests: XCTestCase {
  private func mail(_ body: String) -> Mail {
    Mail(sender: "Sender", senderEmail: "sender@example.com", subject: "Review", body: body)
  }

  func testPassagesSkipInvisibleFillerAndKeepExactSourceSubstringsWithinBudget() throws {
    let body =
      String(repeating: "\u{200B}\u{00AD}\u{2060}\n", count: 120)
      + "  Please review the launch plan by Friday.  \n"
      + String(repeating: String(repeating: "Café 🌊 ", count: 3_000) + "\n", count: 30)
    let passages = JevClient.passages(mail(body))
    XCTAssertEqual(passages.first, "Please review the launch plan by Friday.")
    XCTAssertLessThanOrEqual(passages.count, 100)
    XCTAssertLessThanOrEqual(passages.joined(separator: "\n").utf8.count, 24_000)
    XCTAssertTrue(passages.allSatisfy { $0.utf8.count <= 4_000 && body.contains($0) })
    XCTAssertFalse(passages.contains { $0.contains("�") })
  }

  func testClassificationBoundsBodyPreferencesAndHeadersWhileKeepingExcerptIndexMapping()
    async throws
  {
    let text =
      "  First actual passage.  \n\u{200B}\u{00AD}\n  Send your approval by Friday.  \n"
      + String(repeating: String(repeating: "long email content ", count: 2_000) + "\n", count: 20)
    var message = mail(text)
    message.senderEmail = String(repeating: "s", count: 50_000)
    message.subject = String(repeating: "Title ", count: 50_000)
    var preferences = Preferences()
    preferences.instructions = [String(repeating: "Instruction ", count: 30_000)]
    preferences.memories = Array(repeating: String(repeating: "Memory ", count: 30_000), count: 10)
    let transport = MockHTTP { request in
      let payload = try XCTUnwrap(
        try JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
      let state = try XCTUnwrap(payload["state"] as? [String: Any])
      let email = try XCTUnwrap(state["email"] as? [String: String])
      let notes =
        try XCTUnwrap(state["userPreferences"] as? [String])
        + XCTUnwrap(state["memories"] as? [String])
      XCTAssertLessThanOrEqual(email["body"]!.utf8.count, 24_000)
      XCTAssertLessThanOrEqual(email["from"]!.utf8.count, 320)
      XCTAssertLessThanOrEqual(email["subject"]!.utf8.count, 1_000)
      XCTAssertLessThanOrEqual(notes.reduce(0) { $0 + $1.utf8.count }, 8_000)
      XCTAssertTrue(notes.allSatisfy { $0.utf8.count <= 2_000 })
      let questions = try XCTUnwrap(payload["questions"] as? [String: [String: Any]])
      let options = try XCTUnwrap(questions["excerpt"]?["criteria"] as? [String: String])
      XCTAssertEqual(options["1"], "Send your approval by Friday.")
      let numeric = options.keys.compactMap(Int.init).sorted().map { options[String($0)]! }
      XCTAssertEqual(email["body"], numeric.joined(separator: "\n"))
      XCTAssertLessThan(
        request.httpBody!.count, 64_000, "Large inputs must produce a bounded request")
      return Data(
        #"{"model":"jev-test","answers":{"category":{"choice":"Work","confidence":0.9},"reply":{"noul":0.8},"urgent":{"noul":0.1},"excerpt":{"choice":"1","confidence":0.95}}}"#
          .utf8)
    }
    let decision = try await JevClient(transport: transport).classify(
      message, key: "fixture", preferences: preferences)
    XCTAssertEqual(decision.excerpt, "Send your approval by Friday.")
    XCTAssertTrue(text.contains(try XCTUnwrap(decision.excerpt)))
  }

  func testLongSingleParagraphKeepsLateActionInStateAndExcerptOptions() async throws {
    let action = "Please approve the launch by Friday."
    let body = String(repeating: "a", count: 10_000) + " " + action
    let message = mail(body)
    let passages = JevClient.passages(message)
    XCTAssertEqual(passages.count, 3)
    XCTAssertEqual(
      passages.joined(), body, "Long lines must continue across candidates, not truncate at 4KB")
    let client = JevClient(
      transport: MockHTTP { request in
        let payload = try XCTUnwrap(
          try JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
        let state = try XCTUnwrap(payload["state"] as? [String: Any])
        let email = try XCTUnwrap(state["email"] as? [String: String])
        XCTAssertTrue(try XCTUnwrap(email["body"]).contains(action))
        let questions = try XCTUnwrap(payload["questions"] as? [String: [String: Any]])
        let options = try XCTUnwrap(questions["excerpt"]?["criteria"] as? [String: String])
        XCTAssertEqual(options["2"], passages[2])
        XCTAssertTrue(try XCTUnwrap(options["2"]).contains(action))
        return Data(
          #"{"model":"jev-test","answers":{"category":{"choice":"Work","confidence":0.9},"reply":{"noul":0.8},"urgent":{"noul":0.1},"excerpt":{"choice":"2","confidence":0.95}}}"#
            .utf8)
      })
    let decision = try await client.classify(message, key: "fixture", preferences: Preferences())
    XCTAssertEqual(decision.excerpt, passages[2])
    XCTAssertTrue(body.contains(try XCTUnwrap(decision.excerpt)))
  }

  func testLongSingleParagraphChunksPreserveUnicodeCharacterBoundaries() {
    let body = String(repeating: "🌊e\u{301}", count: 2_000) + "Review the final section."
    let passages = JevClient.passages(mail(body))
    XCTAssertGreaterThan(passages.count, 1)
    XCTAssertEqual(passages.joined(), body)
    XCTAssertTrue(passages.allSatisfy { $0.utf8.count <= 4_000 && body.contains($0) })
    XCTAssertTrue(passages.last!.hasSuffix("Review the final section."))
  }

  func testQABoundsQueryAndUsesIdenticalPassageCriteriaAndResponseMapping() async throws {
    let message = mail(
      "\u{200B}\n  First passage  \n  Approval is due Friday.  \n"
        + String(repeating: "Large body 🌊 ", count: 40_000))
    let expected = JevClient.passages(message)
    let client = JevClient(
      transport: MockHTTP { request in
        let payload = try XCTUnwrap(
          try JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
        let state = try XCTUnwrap(payload["state"] as? [String: Any])
        let passages = try XCTUnwrap(state["passages"] as? [String])
        XCTAssertEqual(passages, expected)
        XCTAssertLessThanOrEqual((state["question"] as! String).utf8.count, 2_000)
        let questions = try XCTUnwrap(payload["questions"] as? [String: [String: Any]])
        let criteria = try XCTUnwrap(questions["passage"]?["criteria"] as? [String: String])
        for (index, passage) in passages.enumerated() {
          XCTAssertEqual(criteria[String(index)], passage)
        }
        XCTAssertEqual(criteria.count, passages.count + 1)
        XCTAssertLessThan(request.httpBody!.count, 64_000)
        return Data(
          #"{"model":"jev-test","answers":{"passage":{"choice":"1","confidence":0.9}}}"#.utf8)
      })
    let answer = try await client.findPassage(
      query: String(repeating: "Question 🌊 ", count: 30_000), mail: message, key: "fixture")
    XCTAssertEqual(answer, "Approval is due Friday.")
  }

  func testDisabledMemoriesAreOmittedAndInvisibleNotesDoNotConsumeBudget() async throws {
    var preferences = Preferences()
    preferences.instructions = ["\u{200B}\u{00AD}", "   ", "Keep requests concise."]
    preferences.memories = [String(repeating: "Private memory", count: 100_000)]
    preferences.useMemories = false
    let client = JevClient(
      transport: MockHTTP { request in
        let payload = try XCTUnwrap(
          try JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
        let state = try XCTUnwrap(payload["state"] as? [String: Any])
        XCTAssertEqual(state["userPreferences"] as? [String], ["Keep requests concise."])
        XCTAssertEqual(state["memories"] as? [String], [])
        return Data(
          #"{"model":"jev-test","answers":{"category":{"choice":"Other","confidence":0.8},"reply":{"noul":0.1},"urgent":{"noul":0.1}}}"#
            .utf8)
      })
    _ = try await client.classify(
      mail("An informational message."), key: "fixture", preferences: preferences)
  }
}
