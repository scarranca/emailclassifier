import CoveCore
import Foundation
import XCTest
@testable import Cove

/// Uses the saved model with a synthetic invitation. No Gmail or Calendar access or writes.
@MainActor final class LiveAssistantContextTests: XCTestCase {
  func testInvitationAdviceDetailsAndExplicitSchedulingWithSelectedMail() async throws {
    guard ProcessInfo.processInfo.environment["COVE_RUN_CHATGPT_SMOKE"] == "1" else {
      throw XCTSkip("Live subscription check is opt-in")
    }
    let defaults = try XCTUnwrap(UserDefaults(suiteName: "ai.cove.mac"))
    let model = AIProviderSettings(defaults: defaults).model(.chatGPT)
    let connection = ChatGPTConnection()
    defer { connection.shutdown() }
    try await connection.refresh()
    let iso = ISO8601DateFormatter()
    let invitation = Mail(id: "synthetic-showcase", sender: "Startup Showcase", senderEmail: "events@example.com",
      subject: "You're invited to meet 12 global startups from Japan",
      body: """
      Hi Alex, you previously expressed interest in Find Your Match-a during SF Tech Week. We also invite you to the J-StarX Startup Showcase. Meet 12 early-stage Japanese startups building for global markets across AI, enterprise software, biotech, defense and consumer technology.
      Event details: October 15, 2026, 5:30pm–8:30pm San Francisco local time. San Francisco, CA; venue provided after registration approval.
      This is direct conversation with founders, investors and operators, with live demos rather than startup presentations. Request to attend; approval required.
      """)
    var reads = 0
    let router = AssistantCalendar(complete: { prompt in
      try await connection.complete(model: model, prompt: prompt)
    }, calendar: { start, end in
      reads += 1
      XCTAssertEqual(start, iso.date(from: "2026-10-16T00:30:00Z"))
      XCTAssertEqual(end, iso.date(from: "2026-10-16T03:30:00Z"))
      return []
    }, calendarAvailable: true, now: iso.date(from: "2026-09-24T17:00:00Z")!, timeZone: TimeZone(identifier: "America/Los_Angeles")!)
    let question = "this event is worth attending?"
    for request in [question, "When is this event and where is it?"] {
      guard case .email = try await router.respond(request, mails: [invitation], progress: { _ in }) else {
        return XCTFail("Invitation questions must reach the email answer: \(request)")
      }
    }
    XCTAssertEqual(reads, 0)
    let answer = try await connection.complete(model: model,
      prompt: AIPrompt(intent: .answer, instruction: question, mails: [invitation]))
    XCTAssertFalse(answer.localizedCaseInsensitiveContains("which event"))
    XCTAssertTrue(answer.contains("[1]"), "Advice must reference the invitation")
    XCTAssertTrue(answer.localizedCaseInsensitiveContains("founder") || answer.localizedCaseInsensitiveContains("network"))
    XCTAssertTrue(answer.localizedCaseInsensitiveContains("approv") || answer.localizedCaseInsensitiveContains("regist"))
    guard case .proposal(let proposal) = try await router.respond("Add this showcase to my calendar", mails: [invitation],
      history: "User: \(question)\nCove: \(answer)", progress: { _ in }) else {
      return XCTFail("An explicit request uses invitation details and still requires review")
    }
    XCTAssertEqual(reads, 1)
    try "Model: \(model)\n\nAdvice:\n\(answer)\n\nProposal: \(proposal.title), \(proposal.start) to \(proposal.end)\nCalendar reads: \(reads) (synthetic only); no writes.\n"
      .write(toFile: "/tmp/cove-live-assistant-context.txt", atomically: true, encoding: .utf8)
  }
}
