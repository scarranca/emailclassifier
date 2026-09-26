import XCTest

@testable import CoveCore

final class CalendarCurrentTimeTests: XCTestCase {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    return calendar
  }

  private func date(_ iso: String) -> Date {
    ISO8601DateFormatter().date(from: iso)!
  }

  func testScrollTargetsNowAndSelectedEventInLocalTime() {
    let now = date("2026-09-23T22:45:00Z") // 3:45 PM local
    XCTAssertEqual(CalendarLayout.scrollHour(now: now, on: now, calendar: calendar), 14)
    XCTAssertEqual(CalendarLayout.scrollHour(now: date("2026-09-23T07:10:00Z"), on: now, calendar: calendar), 0)
    let spring = date("2026-03-08T10:30:00Z")
    XCTAssertEqual(CalendarLayout.scrollHour(now: spring, on: spring, calendar: calendar), 2)
    var event = LocalEvent(title: "Morning", start: date("2026-09-23T16:00:00Z"), end: now)
    XCTAssertEqual(CalendarLayout.scrollHour(now: now, selected: event, on: now, calendar: calendar), 8)
    event.start = date("2026-09-23T06:00:00Z")
    XCTAssertEqual(CalendarLayout.scrollHour(now: now, selected: event, on: now, calendar: calendar), 0)
    event.allDay = true
    XCTAssertEqual(CalendarLayout.scrollHour(now: now, selected: event, on: now, calendar: calendar), 14)
  }

  func testMonthlyCoverageAndNavigationAcrossDSTAndYearBoundary() {
    let march = date("2026-03-15T19:00:00Z")
    let range = CalendarDisplayMode.month.range(containing: march, calendar: calendar)
    let days = CalendarAgenda.monthDays(containing: march, calendar: calendar)
    XCTAssertEqual(range.start, days.first)
    XCTAssertEqual(range.end, calendar.date(byAdding: .day, value: 1, to: days.last!))
    XCTAssertEqual(calendar.dateComponents([.day], from: range.start, to: range.end).day, 42)
    XCTAssertEqual(CalendarDisplayMode.week.range(containing: march, calendar: calendar), CalendarDisplayMode.workweek.range(containing: march, calendar: calendar))
    let january = date("2026-01-31T20:00:00Z")
    let february = CalendarDisplayMode.month.moved(1, from: january, calendar: calendar)
    XCTAssertEqual(calendar.component(.month, from: february), 2)
    XCTAssertEqual(calendar.component(.day, from: february), 1)
    let december = CalendarDisplayMode.month.moved(-1, from: january, calendar: calendar)
    XCTAssertEqual(calendar.component(.month, from: december), 12)
    XCTAssertEqual(calendar.component(.year, from: december), 2025)
  }

  func testAgendaWidthClampsDraggingAndFitsCompactWindows() {
    XCTAssertEqual(CalendarLayout.agendaWidth(preferred: 280, available: 1196), 280)
    XCTAssertEqual(CalendarLayout.agendaWidth(preferred: -100, available: 1196), 240)
    XCTAssertEqual(CalendarLayout.agendaWidth(preferred: 2000, available: 1196), 480)
    // A 1040pt window minus the 224pt sidebar leaves 816pt for calendar panes.
    let compact = CalendarLayout.agendaWidth(preferred: 480, available: 816)
    XCTAssertEqual(compact, 464)
    XCTAssertEqual(816 - compact - CalendarLayout.agendaDividerWidth, 340)
    XCTAssertEqual(CalendarLayout.agendaWidth(preferred: .nan, available: 816), 280)
    // A temporarily tiny layout proposal must not produce negative or nonfinite dimensions.
    XCTAssertEqual(CalendarLayout.agendaWidth(preferred: 480, available: 0), 240)
  }

  func testIndicatorOnlyAppearsInCurrentLocalDay() {
    let now = date("2026-09-23T06:45:00Z")  // September 22, 11:45 PM in Los Angeles.
    XCTAssertEqual(CalendarLayout.currentTimeMinute(on: now, now: now, calendar: calendar), 1425)
    XCTAssertNil(
      CalendarLayout.currentTimeMinute(
        on: date("2026-09-23T08:00:00Z"), now: now, calendar: calendar))
    XCTAssertNil(
      CalendarLayout.currentTimeMinute(
        on: date("2026-09-21T08:00:00Z"), now: now, calendar: calendar))
  }

  func testIndicatorUsesWallTimeAcrossSpringForwardAndFallBack() {
    let spring = date("2026-03-08T10:30:00Z")  // 3:30 AM, only 2.5 elapsed hours.
    XCTAssertEqual(
      CalendarLayout.currentTimeMinute(on: spring, now: spring, calendar: calendar), 210)
    let fall = date("2026-11-01T09:30:00Z")  // Repeated 1:30 AM, 2.5 elapsed hours.
    XCTAssertEqual(CalendarLayout.currentTimeMinute(on: fall, now: fall, calendar: calendar), 90)
  }
}
