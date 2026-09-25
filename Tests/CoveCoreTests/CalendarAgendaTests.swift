import XCTest
@testable import CoveCore

final class CalendarAgendaTests: XCTestCase {
  private var calendar: Calendar {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    return value
  }
  private func date(_ text: String) -> Date {
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.timeZone = calendar.timeZone
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter.date(from: text)!
  }
  private func event(_ start: String, _ end: String) -> LocalEvent {
    LocalEvent(title: "Meeting", start: date(start), end: date(end))
  }
  func testMonthGridIsMondayFirstAndSpansDSTWithoutMissingDates() {
    let days = CalendarAgenda.monthDays(containing: date("2026-03-15 00:00:00"), calendar: calendar)
    XCTAssertEqual(days.count, 42)
    XCTAssertEqual(days.first, date("2026-02-23 00:00:00"))
    XCTAssertEqual(days.last, date("2026-04-05 00:00:00"))
    XCTAssertEqual(Set(days).count, 42)
    XCTAssertTrue(days.allSatisfy { calendar.component(.hour, from: $0) == 0 })
    XCTAssertEqual(CalendarAgenda.weekStart(containing: date("2026-03-08 23:00:00"), calendar: calendar), date("2026-03-02 00:00:00"))
  }
  func testAgendaIncludesOvernightButExcludesEventsEndingAtMidnight() {
    let day = date("2026-09-23 00:00:00")
    let overnight = event("2026-09-22 23:30:00", "2026-09-23 01:00:00")
    let boundary = event("2026-09-22 23:00:00", "2026-09-23 00:00:00")
    var allDay = event("2026-09-23 00:00:00", "2026-09-24 00:00:00")
    allDay.allDay = true
    let invalid = event("2026-09-23 09:00:00", "2026-09-23 08:00:00")
    XCTAssertEqual(CalendarAgenda.events([overnight, boundary, allDay, invalid], on: day, calendar: calendar).map(\.id), [allDay.id, overnight.id])
  }
  func testScheduledTimeUnionsOverlapsAndClipsToDay() {
    let events = [
      event("2026-09-22 23:30:00", "2026-09-23 01:00:00"),
      event("2026-09-23 09:00:00", "2026-09-23 11:00:00"),
      event("2026-09-23 10:00:00", "2026-09-23 12:00:00"),
      event("2026-09-23 23:00:00", "2026-09-24 01:00:00")
    ]
    XCTAssertEqual(CalendarAgenda.scheduledMinutes(events, on: date("2026-09-23 00:00:00"), calendar: calendar), 300)
  }
  func testFocusFindsFirstLongEnoughGapAndRoundsUp() {
    let day = date("2026-09-23 00:00:00")
    let events = [event("2026-09-23 10:00:00", "2026-09-23 11:01:00"), event("2026-09-23 12:30:00", "2026-09-23 15:00:00")]
    let result = CalendarAgenda.focusInterval(events, on: day, now: date("2026-09-23 09:20:00"), calendar: calendar)
    XCTAssertEqual(result?.start, date("2026-09-23 11:15:00"))
    XCTAssertEqual(result?.end, date("2026-09-23 12:30:00"))
    let fractional = CalendarAgenda.focusInterval([], on: day, now: date("2026-09-23 09:15:00").addingTimeInterval(0.25), calendar: calendar)
    XCTAssertEqual(fractional?.start, date("2026-09-23 09:30:00"))
    XCTAssertEqual(fractional?.duration, 7200)
  }
  func testFocusHonorsAllDayBusyButIgnoresExplicitlyFreeAndPastDays() {
    let day = date("2026-09-23 00:00:00")
    var busy = event("2026-09-23 00:00:00", "2026-09-24 00:00:00")
    busy.allDay = true
    XCTAssertNil(CalendarAgenda.focusInterval([busy], on: day, now: day, calendar: calendar))
    busy.blocksTime = false
    XCTAssertEqual(CalendarAgenda.focusInterval([busy], on: day, now: day, calendar: calendar)?.start, date("2026-09-23 09:00:00"))
    XCTAssertNil(CalendarAgenda.focusInterval([], on: day, now: date("2026-09-24 08:00:00"), calendar: calendar))
    XCTAssertNil(CalendarAgenda.focusInterval([], on: day, now: date("2026-09-23 16:15:00"), calendar: calendar))
  }
  func testGoogleAvailabilityAndLegacyCacheDecoding() throws {
    let base: [String: Any] = ["id": "event", "start": ["dateTime": "2026-09-23T09:00:00-07:00"], "end": ["dateTime": "2026-09-23T10:00:00-07:00"]]
    func decode(_ changes: [String: Any]) throws -> LocalEvent? {
      let data = try JSONSerialization.data(withJSONObject: base.merging(changes) { _, new in new })
      return try JSONDecoder().decode(GoogleCalendarClient.Event.self, from: data).local()
    }
    XCTAssertEqual(try decode([:])?.blocksTime, true)
    XCTAssertEqual(try decode(["transparency": "transparent"])?.blocksTime, false)
    XCTAssertEqual(try decode(["attendees": [["self": true, "responseStatus": "declined"]]])?.blocksTime, false)
    XCTAssertEqual(try decode(["attendees": [["self": false, "responseStatus": "declined"]]])?.blocksTime, true)
    XCTAssertNil(try decode(["status": "cancelled"]))
    let metadata = try XCTUnwrap(decode([
      "description": "<p>Review &amp; plan</p><script>ignore()</script>", "location": "Room 1",
      "attendees": [["displayName": "Alex", "email": "alex@example.com", "responseStatus": "accepted"]]
    ]))
    XCTAssertEqual(metadata.details, "Review & plan")
    XCTAssertEqual(metadata.location, "Room 1")
    XCTAssertEqual(metadata.attendees?.first?.name, "Alex")
    XCTAssertEqual(metadata.attendees?.first?.response, "accepted")
    let legacy = Data(#"{"id":"old","title":"Old","start":0,"end":3600}"#.utf8)
    let decoded = try JSONDecoder().decode(LocalEvent.self, from: legacy)
    XCTAssertNil(decoded.blocksTime)
    XCTAssertNil(decoded.localCalendar)
    XCTAssertEqual(decoded.effectiveLocalCalendar, .personal)
  }
}
