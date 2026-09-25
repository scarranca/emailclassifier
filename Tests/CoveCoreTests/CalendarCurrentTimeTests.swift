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
