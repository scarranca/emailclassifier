import AppKit
import CoveCore
import SwiftUI
import XCTest
@testable import Cove

@MainActor final class AssistantAgendaTests: XCTestCase {
  private let iso = ISO8601DateFormatter()
  private let zone = TimeZone(identifier: "America/Los_Angeles")!
  private func date(_ text: String) -> Date { iso.date(from: text)! }
  private func fixture() -> AssistantAgenda {
    let start = date("2026-09-25T00:00:00-07:00"), end = date("2026-09-26T00:00:00-07:00")
    var allDay = LocalEvent(title: "Working from home", start: start, end: end); allDay.allDay = true
    let titles = ["Founder conversations — Alex Lee and Morgan Chen", "Team daily", "Product review", "Customer questions", "Partnership call with Arianna and the team", "Operations check-in", "Infrastructure", "Lunch", "Coffee & learnings ☕"]
    let hours: [(Double, Double)] = [(7.5,8.5), (9,9.5), (9.5,10), (9.5,10), (10,10.75), (10.75,11.5), (12,13), (13,14), (14,14.75)]
    let timed = zip(titles,hours).map { title, hours in
      LocalEvent(title: title, start: start.addingTimeInterval(hours.0 * 3600), end: start.addingTimeInterval(hours.1 * 3600))
    }
    return AssistantAgenda(start: start, end: end, events: [allDay] + timed, totalCount: 10,
      now: start.addingTimeInterval(-3600), timeZone: zone)
  }
  func testDayHeadingAllDayAndOverlapsAreGroundedInCalendarData() throws {
    let agenda = fixture()
    XCTAssertEqual(agenda.title, "Tomorrow’s schedule")
    XCTAssertTrue(agenda.singleDay); XCTAssertEqual(agenda.days.count, 1)
    XCTAssertNil(agenda.rangeLabel); XCTAssertEqual(agenda.zoneLabel, "PDT")
    XCTAssertEqual(agenda.summary, "10 events · 1 all day")
    let day = try XCTUnwrap(agenda.days.first)
    XCTAssertEqual(agenda.timeLabel(day.events[0], on: day.date), "All day")
    XCTAssertFalse(agenda.overlaps(day.events[0], on: day))
    XCTAssertFalse(agenda.overlaps(day.events[1], on: day))
    XCTAssertTrue(agenda.overlaps(day.events[3], on: day))
    XCTAssertTrue(agenda.overlaps(day.events[4], on: day))
    XCTAssertFalse(agenda.overlaps(day.events[5], on: day), "Adjacent events do not overlap")
    XCTAssertTrue(agenda.plainText.contains("• All day — Working from home\n"))
    XCTAssertEqual(agenda.plainText.components(separatedBy: "\n").filter { $0.hasPrefix("• ") }.count, 10)
    XCTAssertTrue(agenda.plainText.contains("Founder conversations"))
  }
  func testEmptyTruncatedMultidayAndDaylightSavingRanges() throws {
    let start = date("2026-11-01T00:00:00-07:00"), end = date("2026-11-03T00:00:00-08:00")
    let overnight = LocalEvent(title: "Overnight", start: date("2026-11-01T23:00:00-08:00"), end: date("2026-11-02T01:00:00-08:00"))
    let repeatedHour = LocalEvent(title: "Clock change", start: date("2026-11-01T01:30:00-07:00"), end: date("2026-11-01T01:45:00-08:00"))
    let agenda = AssistantAgenda(start: start, end: end, events: [repeatedHour,overnight], totalCount: 45, now: start, timeZone: zone)
    XCTAssertFalse(agenda.singleDay); XCTAssertEqual(agenda.days.count, 2)
    XCTAssertEqual(agenda.zoneLabel, "America/Los_Angeles")
    XCTAssertTrue(agenda.plainText.contains("Showing the first 2 of 45"))
    XCTAssertTrue(agenda.timeLabel(overnight, on: agenda.days[0].date).hasSuffix("onward"))
    XCTAssertTrue(agenda.timeLabel(overnight, on: agenda.days[1].date).hasPrefix("Until"))
    XCTAssertTrue(agenda.timeLabel(repeatedHour, on: start).contains("PDT"))
    XCTAssertTrue(agenda.timeLabel(repeatedHour, on: start).contains("PST"))
    let empty = AssistantAgenda(start: start, end: end, events: [], totalCount: 0, now: start, timeZone: zone)
    XCTAssertTrue(empty.plainText.contains("No events found")); XCTAssertTrue(empty.days.isEmpty)
  }
  func testTransparentAndDeclinedEventsDoNotShowFalseOverlap() throws {
    let original = fixture(); let day = try XCTUnwrap(original.days.first)
    var a = day.events[3], b = day.events[4]
    a.blocksTime = false
    var changed = AssistantAgenda.Day(date: day.date, events: [a,b])
    XCTAssertFalse(original.overlaps(a, on: changed)); XCTAssertFalse(original.overlaps(b, on: changed))
    a.blocksTime = true; b.attendees = [CalendarAttendee(response: "declined", isSelf: true)]
    changed = AssistantAgenda.Day(date: day.date, events: [a,b])
    XCTAssertFalse(original.overlaps(a, on: changed))
  }
  func testAgendaAndChatRenderAtWideAndNarrowWidthsWithoutForegroundWindow() async throws {
    _ = NSApplication.shared; DesignAssets.registerFonts()
    let agenda = fixture()
    for width: CGFloat in [680, 340] {
      let view = AssistantAgendaView(agenda: agenda).padding(24).frame(width: width).background(Palette.canvas)
      let host = NSHostingView(rootView: view); let size = host.fittingSize
      XCTAssertEqual(size.width, width, accuracy: 1); XCTAssertGreaterThan(size.height, 600); XCTAssertLessThan(size.height, 1500)
      try await capture(host, size: size, path: "/tmp/cove-agenda-\(Int(width)).png")
    }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let db = try Database(url: directory.appendingPathComponent("mail.sqlite"))
    let store = try AppStore(database: db, accountEmail: "test@example.com", gmail: GmailClient(), gmailTokenProvider: { XCTFail("No account access for rendering"); return "" }, syncClock: Date.init)
    store.isSample = true; store.screen = "home"
    let suite = "Cove-Agenda-Rendering-" + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let settings = AIProviderSettings(defaults: defaults, readSecret: { _ in nil })
    var exchange = ChatExchange(question: "What do I have tomorrow?", mail: nil, scope: .email)
    exchange.agenda = agenda; exchange.isCalendar = true; exchange.answer = agenda.plainText; exchange.source = "Calendar · sample data"
    for width: CGFloat in [800, 560] {
      let view = AssistantView(store: store, availableSize: CGSize(width: width, height: 848), settings: settings, initialExchanges: [exchange])
      let host = NSHostingView(rootView: view)
      try await capture(host, size: CGSize(width: width - 48, height: 800), path: "/tmp/cove-agenda-chat-\(Int(width)).png")
    }
  }
  private func capture<V: View>(_ host: NSHostingView<V>, size: CGSize, path: String) async throws {
    let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = host
    defer { window.close() }
    for _ in 0..<8 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(30)) }
    XCTAssertFalse(window.isVisible)
    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds)); host.cacheDisplay(in: host.bounds, to: bitmap)
    try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: path))
  }
}
