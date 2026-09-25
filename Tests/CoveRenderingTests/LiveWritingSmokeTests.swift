import CoveCore
import Foundation
import NaturalLanguage
import XCTest
@testable import Cove

/// Explicitly opt in: uses the already-connected subscription with synthetic evidence only.
@MainActor final class LiveWritingSmokeTests: XCTestCase {
  func testAssistantClarifiesThenPreviewsFocusEventWithoutWriting() async throws {
    guard ProcessInfo.processInfo.environment["COVE_RUN_CHATGPT_SMOKE"] == "1" else { throw XCTSkip("Live subscription check is opt-in") }
    let defaults = try XCTUnwrap(UserDefaults(suiteName: "ai.cove.mac"))
    let model = AIProviderSettings(defaults: defaults).model(.chatGPT)
    let connection = ChatGPTConnection()
    defer { connection.shutdown() }
    try await connection.refresh()
    let iso = ISO8601DateFormatter()
    let now = try XCTUnwrap(iso.date(from: "2026-09-23T17:00:00Z"))
    var reads = 0
    let agent = AssistantCalendar(complete: { prompt in
      try await connection.complete(model: model, prompt: prompt)
    }, calendar: { from, to in
      reads += 1
      XCTAssertEqual(from, now.addingTimeInterval(1800))
      XCTAssertEqual(to, now.addingTimeInterval(3600))
      return []
    }, calendarAvailable: true, now: now, timeZone: TimeZone(identifier: "America/Los_Angeles")!)
    let request = "Please generate an event for today in the next half an hour, just to focus"
    guard case .clarification(let question) = try await agent.respond(request, progress: { _ in }) else {
      return XCTFail("Ambiguous timing needs clarification, not a guessed event")
    }
    XCTAssertEqual(reads, 0)
    guard case .proposal(let proposal) = try await agent.respond("Start in 30 minutes, for 30 minutes", history: "User: \(request)\nCove: \(question)", progress: { _ in }) else { return XCTFail("Expected event review") }
    XCTAssertEqual(reads, 1)
    XCTAssertTrue(proposal.title.localizedCaseInsensitiveContains("focus"))
    let email = try await agent.respond("Summarize the selected email about tomorrow's meeting", progress: { _ in })
    guard case .email = email else { return XCTFail("An email mentioning a meeting is not a calendar command") }
    try "Model: \(model)\nClarification: \(question)\nPreview: \(proposal.title) \(proposal.start) to \(proposal.end)\n\(proposal.availability)\nCalendar reads: \(reads). No real calendar or mail access; no write capability.\n"
      .write(to: URL(fileURLWithPath: "/tmp/cove-live-assistant-calendar.txt"), atomically: true, encoding: .utf8)
  }
  func testConnectedChatGPTProposesVerifiedTomorrowSlotAndThreeSlotFollowUp() async throws {
    guard ProcessInfo.processInfo.environment["COVE_RUN_CHATGPT_SMOKE"] == "1" else {
      throw XCTSkip("Live subscription check is opt-in")
    }
    let defaults = try XCTUnwrap(UserDefaults(suiteName: "ai.cove.mac"))
    let settings = AIProviderSettings(defaults: defaults)
    let model = settings.model(.chatGPT)
    XCTAssertFalse(model.isEmpty, "Use the user's saved subscription model")
    let connection = ChatGPTConnection()
    defer { connection.shutdown() }
    try await connection.refresh()
    XCTAssertTrue(connection.connected)
    let date = ISO8601DateFormatter()
    let now = try XCTUnwrap(date.date(from: "2026-09-23T17:00:00Z"))
    let zone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
    var calendarCalls = 0
    var completions = 0
    let agent = WritingAgent(complete: { prompt in
      completions += 1
      return try await connection.complete(model: model, prompt: prompt)
    }, search: { _ in [] }, calendar: { from, to in
      calendarCalls += 1
      XCTAssertEqual(from, date.date(from: "2026-09-24T07:00:00Z"))
      XCTAssertEqual(to, date.date(from: "2026-09-25T07:00:00Z"))
      return [LocalEvent(title: "Synthetic busy block", start: date.date(from: "2026-09-24T16:00:00Z")!, end: date.date(from: "2026-09-24T17:30:00Z")!)]
    }, calendarAvailable: true, now: now, timeZone: zone)
    let result = try await agent.draft(instruction: "Please ask to meet on my first tiem available tomorrow", draft: "", mails: [],
      envelope: "From: Santiago <santiago@example.com>\nTo: Martha <martha@example.com>\nSubject: Meeting", useTools: true) { _ in }
    XCTAssertGreaterThanOrEqual(calendarCalls, 1)
    XCTAssertTrue(result.text.contains("10:30"), "Must propose the first verified slot")
    XCTAssertTrue(result.text.contains("24"), "Must name the actual date")
    XCTAssertFalse(result.text.contains("at my first available time"))
    let followUp = try await agent.draft(instruction: "suggest 3 timeslots", draft: result.text, mails: [],
      envelope: "From: Santiago <santiago@example.com>\nTo: Martha <martha@example.com>\nSubject: Meeting", useTools: true, session: result.session) { _ in }
    XCTAssertEqual(calendarCalls, 2, "Follow-up must recheck the calendar")
    for time in ["10:30 AM PDT", "11:00 AM PDT", "11:30 AM PDT"] {
      XCTAssertTrue(followUp.text.contains(time), "Must include all three verified options")
    }
    XCTAssertEqual(followUp.session.availability?.dayString, "2026-09-24")
    XCTAssertEqual(followUp.session.availability?.slotCount, 3)
    try ("Model: \(model)\nCalendar reads: \(calendarCalls)\nCompletions: \(completions)\n" + followUp.activity.joined(separator: "\n") + "\n\nFirst draft:\n" + result.text + "\n\nFollow-up:\n" + followUp.text)
      .write(to: URL(fileURLWithPath: "/tmp/cove-live-scheduling-followup.txt"), atomically: true, encoding: .utf8)
  }
  func testConnectedModelChoosesMailAndCalendarAndRespectsLanguage() async throws {
    guard ProcessInfo.processInfo.environment["COVE_RUN_CHATGPT_SMOKE"] == "1" else {
      throw XCTSkip("Live subscription check is opt-in")
    }
    let defaults = try XCTUnwrap(UserDefaults(suiteName: "ai.cove.mac"))
    let settings = AIProviderSettings(defaults: defaults)
    let model = settings.model(.chatGPT)
    XCTAssertFalse(model.isEmpty)
    let connection = ChatGPTConnection()
    defer { connection.shutdown() }
    try await connection.refresh()
    let iso = ISO8601DateFormatter()
    let zone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
    let source = Mail(id: "synthetic-pine", sender: "Maya", senderEmail: "maya@example.com", subject: "Proyecto Pine — cotización",
      body: "Hola Santiago, la cotización actualizada para el proyecto Pine es de 4200 USD. Quedo pendiente para revisar los siguientes pasos. Saludos, Maya.")
    var queries: [String] = []
    var reads = 0
    var plans: [String] = []
    var completions = 0
    let agent = WritingAgent(complete: { prompt in
      completions += 1
      let answer = try await connection.complete(model: model, prompt: prompt)
      if prompt.system.contains("You plan read-only evidence") { plans.append(answer) }
      return answer
    }, search: { query in queries.append(query); return [source] }, calendar: { from, to in
      reads += 1
      XCTAssertEqual(from, iso.date(from: "2026-09-24T07:00:00Z"))
      XCTAssertEqual(to, iso.date(from: "2026-09-25T07:00:00Z"))
      return [LocalEvent(title: "Project Pine review", start: iso.date(from: "2026-09-24T16:00:00Z")!, end: iso.date(from: "2026-09-24T17:30:00Z")!)]
    }, calendarAvailable: true, now: iso.date(from: "2026-09-23T17:00:00Z")!, timeZone: zone)
    let request = "Find my latest conversation with Maya about Project Pine, then draft a follow-up mentioning her latest quote and proposing three free 30-minute times tomorrow."
    let first = try await agent.draft(instruction: ComposeSuggestion.instruction(request, voice: "Warm", instructions: [], selection: false),
      draft: "", mails: [source], envelope: "From: Santiago <santiago@example.com>\nTo: Maya <maya@example.com>\nSubject: Project Pine",
      useTools: true, userInstruction: request) { _ in }
    XCTAssertEqual(queries.count, 1, "Explicit fresh search must run despite already-selected mail")
    XCTAssertTrue(queries.first?.contains("maya@example.com") == true)
    XCTAssertFalse(queries.first?.contains("subject:") == true, "A topic must not become an invented exact-subject restriction")
    XCTAssertEqual(reads, 1)
    XCTAssertTrue(first.text.contains("4200") || first.text.contains("4,200"))
    XCTAssertEqual(NLLanguageRecognizer.dominantLanguage(for: first.text), .english, "Spanish evidence must not change a new English request's output language")
    XCTAssertEqual(first.session.availability?.slotCount, 3)

    let recapRequest = "Check tomorrow's calendar and draft a short recap of my existing meetings for Maya. Do not propose new times."
    let recap = try await agent.draft(instruction: recapRequest, draft: "", mails: [], envelope: "To: maya@example.com",
      useTools: true, userInstruction: recapRequest) { _ in }
    XCTAssertEqual(reads, 2)
    XCTAssertEqual(queries.count, 1, "Event facts do not require an unrelated mail search")
    XCTAssertTrue(recap.text.contains("Pine"))
    XCTAssertNil(recap.session.availability)
    XCTAssertEqual(NLLanguageRecognizer.dominantLanguage(for: recap.text), .english)

    let spanish = "Hola Maya, muchas gracias por enviarme todos los detalles del proyecto. Voy a revisarlos con cuidado y después te compartiré mis comentarios. Me alegra mucho que podamos seguir trabajando juntos. Un saludo, Santiago."
    let editRequest = "Make this shorter and keep the warm tone."
    let edit = try await agent.draft(instruction: ComposeSuggestion.instruction(editRequest, voice: "Warm", instructions: [], selection: false),
      draft: spanish, mails: [], envelope: "To: maya@example.com", useTools: true,
      userInstruction: editRequest, session: first.session) { _ in }
    XCTAssertEqual(reads, 2, "A wording edit must not repeat the earlier scheduling task")
    XCTAssertEqual(queries.count, 1)
    XCTAssertEqual(NLLanguageRecognizer.dominantLanguage(for: edit.text), .spanish, "A rewrite preserves the existing text's language")
    XCTAssertFalse(edit.text.contains("September"))
    try ("Model: \(model)\nCompletions: \(completions)\nQueries: \(queries)\nCalendar reads: \(reads)\n\nPlans:\n" + plans.joined(separator: "\n") + "\n\nCombined draft:\n" + first.text + "\n\nCalendar recap:\n" + recap.text + "\n\nSpanish rewrite:\n" + edit.text)
      .write(to: URL(fileURLWithPath: "/tmp/cove-live-tool-language.txt"), atomically: true, encoding: .utf8)
  }

}
