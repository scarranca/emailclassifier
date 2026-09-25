import CoveCore
import XCTest
@testable import Cove

@MainActor final class WritingFollowUpTests: XCTestCase {
  let zone = TimeZone(identifier: "America/Los_Angeles")!
  func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
  func answer(_ prompt: AIPrompt) -> String {
    let labels = prompt.user.components(separatedBy: "\n\nCurrent draft (text to edit):")[0].components(separatedBy: "\n").filter { $0.hasPrefix("- Thursday,") }
    return "Hi Martha,\nWhich of these works for you?\n" + labels.joined(separator: "\n")
  }
  func testThreeSlotFollowUpRetainsDayAndRechecksChangedCalendarEvenWithEmptyPlan() async throws {
    var reads = 0
    var prompts: [AIPrompt] = []
    let agent = WritingAgent(complete: { p in
      prompts.append(p)
      return prompts.count % 2 == 1 ? #"{"tools":[]}"# : self.answer(p)
    }, search: { _ in XCTFail("No search needed"); return [] }, calendar: { from, to in
      reads += 1
      XCTAssertEqual(from, self.date("2026-09-24T07:00:00Z"))
      XCTAssertEqual(to, self.date("2026-09-25T07:00:00Z"))
      return [LocalEvent(title: "Private", start: self.date("2026-09-24T16:00:00Z"),
                        end: self.date(reads == 1 ? "2026-09-24T17:00:00Z" : "2026-09-24T18:00:00Z"))]
    }, calendarAvailable: true, now: date("2026-09-23T17:00:00Z"), timeZone: zone)
    let first = try await agent.draft(instruction: "Ask to meet at my first available time tomorrow", draft: "", mails: [], envelope: "To: Martha", useTools: true) { _ in }
    XCTAssertTrue(first.text.contains("10:00 AM PDT"))
    let next = try await agent.draft(instruction: "suggest 3 timeslots", draft: first.text, mails: [], envelope: "To: Martha", useTools: true, session: first.session) { _ in }
    XCTAssertEqual(reads, 2)
    XCTAssertEqual(next.session.availability?.slotCount, 3)
    XCTAssertEqual(next.session.availability?.dayString, "2026-09-24")
    for time in ["11:00 AM PDT", "11:30 AM PDT", "12:00 PM PDT"] { XCTAssertTrue(next.text.contains(time)) }
    XCTAssertFalse(next.text.contains("10:00 AM PDT"), "Must not repeat stale prior opening")
    XCTAssertTrue(prompts[2].user.contains("Ask to meet at my first available time tomorrow"))
    XCTAssertFalse(prompts[2].user.contains("Which of these works"), "Generated draft is not promoted into planner instructions")
    XCTAssertEqual(next.session.requests.count, 2)
  }
  func testMissingAnyOfThreeVerifiedChoicesGetsCorrection() async throws {
    let prior = WritingSession(availability: try WritingAvailability(day: "2026-09-24", timeZone: zone))
    var calls = 0
    let agent = WritingAgent(complete: { p in
      calls += 1
      if calls == 1 { return #"{"tools":[]}"# }
      if calls == 2 { return "Thursday, September 24, 2026 at 9:00 AM PDT" }
      return self.answer(p)
    }, search: { _ in [] }, calendar: { _, _ in [] }, calendarAvailable: true, now: date("2026-09-23T17:00:00Z"), timeZone: zone)
    let result = try await agent.draft(instruction: "suggest three time slots", draft: "Old", mails: [], envelope: "", useTools: true, session: prior) { _ in }
    XCTAssertEqual(calls, 3)
    XCTAssertTrue(result.text.contains("9:00 AM PDT"))
    XCTAssertTrue(result.text.contains("9:30 AM PDT"))
    XCTAssertTrue(result.text.contains("10:00 AM PDT"))
  }
  func testOnlyTwoOptionsAreReportedWhenThreeDoNotFit() async throws {
    let previous = try WritingAvailability(day: "2026-09-24", startMinute: 960, endMinute: 1020, timeZone: zone)
    var calls = 0
    let agent = WritingAgent(complete: { p in
      calls += 1
      if calls == 1 { return #"{"tools":[]}"# }
      XCTAssertTrue(p.user.contains("Only 2 of the requested 3"))
      return self.answer(p)
    }, search: { _ in [] }, calendar: { _, _ in [] }, calendarAvailable: true, now: date("2026-09-23T17:00:00Z"), timeZone: zone)
    let result = try await agent.draft(instruction: "suggest 3 timeslots", draft: "", mails: [], envelope: "", useTools: true, session: WritingSession(availability: previous)) { _ in }
    XCTAssertEqual(result.activity.filter { $0.hasPrefix("Available ·") }.count, 2)
    XCTAssertTrue(result.activity.contains { $0.contains("Only 2 of 3") })
  }
  func testFollowUpCannotBypassDisabledCalendarOrDiscardContextOnFailure() async throws {
    let previous = WritingSession(requests: ["First available tomorrow"], availability: try WritingAvailability(day: "2026-09-24", timeZone: zone))
    let agent = WritingAgent(complete: { _ in XCTFail("No completion permitted"); return "" }, search: { _ in [] }, calendar: { _, _ in XCTFail(); return [] }, calendarAvailable: true)
    do {
      _ = try await agent.draft(instruction: "suggest 3 timeslots", draft: "", mails: [], envelope: "", useTools: false, session: previous) { _ in }
      XCTFail("Expected missing lookup error")
    } catch { XCTAssertTrue(error.localizedDescription.contains("Turn on")) }
    XCTAssertEqual(previous.availability?.slotCount, 1)
    XCTAssertEqual(previous.requests.count, 1)
  }
  func testHistoryIsBoundedAndOnlySuccessfulRequestValuesAreStored() {
    var session = WritingSession()
    for _ in 0..<20 { session = session.recording(String(repeating: "👋", count: 1000), availability: nil) }
    XCTAssertEqual(session.requests.count, 4)
    XCTAssertLessThanOrEqual(session.requests.joined().utf8.count, 2000)
  }
}
