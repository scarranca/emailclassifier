import XCTest

@testable import CoveCore

final class CalendarSearchTests: XCTestCase {
  func testSearchFindsGuestLocationAndNotesAcrossCaseAndAccents() throws {
    let data = Data(
      #"{"id":"review","title":"Design review","start":0,"end":3600,"details":"Discuss launch timing","location":"Café Central","attendees":[{"name":"Maya Chen","email":"maya@example.com","response":"accepted"}]}"#
        .utf8)
    let event = try JSONDecoder().decode(LocalEvent.self, from: data)
    let now = Date(timeIntervalSinceReferenceDate: 0)
    for query in ["CAFE maya", "launch Central", "maya@example.com", "  Design\nreview  "] {
      XCTAssertEqual(CalendarSearch.matches([event], query: query, now: now).map(\.id), [event.id])
    }
    XCTAssertTrue(CalendarSearch.matches([event], query: "Maya budget", now: now).isEmpty)
  }

  func testSearchOrdersOngoingUpcomingAndRecentPastWithoutDroppingMatches() {
    let now = Date(timeIntervalSinceReferenceDate: 10_000)
    func event(_ id: String, _ start: TimeInterval, _ end: TimeInterval) -> LocalEvent {
      var value = LocalEvent(
        title: "Review", start: now.addingTimeInterval(start), end: now.addingTimeInterval(end))
      value.id = id
      return value
    }
    let events = [
      event("later", 500, 600), event("old", -500, -400), event("now", -50, 50),
      event("soon", 100, 200), event("ended", -100, 0),
    ]
    XCTAssertEqual(
      CalendarSearch.matches(events, query: "review", now: now).map(\.id),
      ["now", "soon", "later", "ended", "old"])
    XCTAssertEqual(CalendarSearch.matches(events, query: "   ", now: now).count, events.count)
  }
}
