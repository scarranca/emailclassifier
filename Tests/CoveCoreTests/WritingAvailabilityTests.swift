import XCTest
@testable import CoveCore

final class WritingAvailabilityTests: XCTestCase {
  let zone = TimeZone(identifier: "America/Los_Angeles")!
  func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
  func busy(_ start: String, _ end: String, transparent: Bool = false, allDay: Bool = false) -> LocalEvent {
    var event = LocalEvent(title: "Busy", start: date(start), end: date(end))
    event.blocksTime = !transparent
    event.allDay = allDay
    return event
  }
  func testTypoAndLocalTomorrowResolveAgainstLocalDateNotUTC() throws {
    let request = try XCTUnwrap(WritingAvailability.fallback(
      instruction: "Please ask to meet on my first tiem available tomorrow",
      now: date("2026-09-24T02:00:00Z"), timeZone: zone))
    XCTAssertEqual(request.dayString, "2026-09-24", "UTC is already Sept 24, but local today is Sept 23")
    XCTAssertEqual(request.dayRange.start, date("2026-09-24T07:00:00Z"))
    XCTAssertEqual(request.durationMinutes, 30)
    XCTAssertEqual(request.startMinute, 540)
    XCTAssertEqual(request.endMinute, 1020)
  }
  func testMergedOverlapAndBackToBackEventsProduceFirstActualGap() throws {
    let request = try WritingAvailability(day: "2026-09-24", timeZone: zone)
    let events = [
      busy("2026-09-24T16:00:00Z", "2026-09-24T17:00:00Z"),
      busy("2026-09-24T16:30:00Z", "2026-09-24T17:30:00Z"),
      busy("2026-09-24T17:30:00Z", "2026-09-24T18:10:00Z"),
      busy("2026-09-24T18:30:00Z", "2026-09-24T19:00:00Z"),
      busy("2026-09-24T19:00:00Z", "2026-09-24T20:00:00Z", transparent: true)
    ]
    let slot = try XCTUnwrap(request.firstSlot(events: events, now: date("2026-09-23T22:00:00Z")))
    XCTAssertEqual(slot.start, date("2026-09-24T19:00:00Z"))
    XCTAssertEqual(slot.duration, 1800)
    XCTAssertEqual(request.label(for: slot), "Thursday, September 24, 2026 at 12:00 PM PDT")
  }
  func testAllDayBusyAndOvernightEventsBlockTimeButTransparentAllDayDoesNot() throws {
    let request = try WritingAvailability(day: "2026-09-24", timeZone: zone)
    let now = date("2026-09-23T22:00:00Z")
    XCTAssertNil(try request.firstSlot(events: [busy("2026-09-24T07:00:00Z", "2026-09-25T07:00:00Z", allDay: true)], now: now))
    let transparent = busy("2026-09-24T07:00:00Z", "2026-09-25T07:00:00Z", transparent: true, allDay: true)
    let overnight = busy("2026-09-24T01:00:00Z", "2026-09-24T17:00:00Z")
    XCTAssertEqual(try request.firstSlot(events: [transparent, overnight], now: now)?.start, date("2026-09-24T17:00:00Z"))
  }
  func testDaylightSavingLocalDayBoundariesAndNoPastProposal() throws {
    let spring = try WritingAvailability(day: "2026-03-08", timeZone: zone)
    let fall = try WritingAvailability(day: "2026-11-01", timeZone: zone)
    XCTAssertEqual(spring.dayRange.duration, 23 * 3600)
    XCTAssertEqual(fall.dayRange.duration, 25 * 3600)
    let now = date("2026-11-01T18:12:31Z")
    XCTAssertEqual(try fall.firstSlot(events: [], now: now)?.start, date("2026-11-01T18:13:00Z"))
    XCTAssertNil(try spring.firstSlot(events: [], now: now))
  }
  func testExplicitDurationAndWindowHonoredAndAmbiguousConstraintRejected() throws {
    let request = try XCTUnwrap(WritingAvailability.fallback(instruction: "Ask to meet at my first available time tomorrow for 1 hour after 2 PM before 4:30 PM", now: date("2026-09-23T22:00:00Z"), timeZone: zone))
    XCTAssertEqual(request.durationMinutes, 60)
    XCTAssertEqual(request.startMinute, 840)
    XCTAssertEqual(request.endMinute, 990)
    let evening = try XCTUnwrap(WritingAvailability.fallback(instruction: "Find my first available meeting tomorrow evening for an hour", now: date("2026-09-23T22:00:00Z"), timeZone: zone))
    XCTAssertEqual(evening.durationMinutes, 60)
    XCTAssertEqual(evening.startMinute, 1020)
    XCTAssertEqual(evening.endMinute, 1260)
    XCTAssertThrowsError(try WritingAvailability.fallback(instruction: "Find first available meeting tomorrow after lunch", now: Date(), timeZone: zone))
    XCTAssertThrowsError(try WritingAvailability(day: "2026-02-30", timeZone: zone))
    XCTAssertThrowsError(try WritingAvailability(day: "2026-09-24", durationMinutes: 0, timeZone: zone))
    XCTAssertThrowsError(try WritingAvailability(day: "2026-09-24", startMinute: 900, endMinute: 800, timeZone: zone))
  }
  func testMultipleSlotsAreDistinctAndRetainFollowUpParameters() throws {
    let previous = try WritingAvailability(day: "2026-09-24", durationMinutes: 45, startMinute: 600, endMinute: 900, timeZone: zone)
    let request = try XCTUnwrap(WritingAvailability.fallback(instruction: "suggest 3 timeslots", now: date("2026-09-23T17:00:00Z"), timeZone: zone, previous: previous))
    XCTAssertEqual(request.dayString, previous.dayString)
    XCTAssertEqual(request.durationMinutes, 45)
    XCTAssertEqual(request.startMinute, 600)
    XCTAssertEqual(request.endMinute, 900)
    let slots = try request.slots(events: [busy("2026-09-24T18:00:00Z", "2026-09-24T19:00:00Z")], now: date("2026-09-23T17:00:00Z"))
    XCTAssertEqual(slots.map(\.start), [date("2026-09-24T17:00:00Z"), date("2026-09-24T19:00:00Z"), date("2026-09-24T19:45:00Z")])
    XCTAssertTrue(zip(slots, slots.dropFirst()).allSatisfy { $0.end <= $1.start })
    let changed = try XCTUnwrap(WritingAvailability.fallback(instruction: "suggest 2 timeslots tomorrow afternoon for an hour", now: date("2026-09-24T17:00:00Z"), timeZone: zone, previous: request))
    XCTAssertEqual(changed.dayString, "2026-09-25")
    XCTAssertEqual(changed.slotCount, 2)
    XCTAssertEqual(changed.durationMinutes, 60)
    XCTAssertEqual(changed.startMinute, 720)
    XCTAssertEqual(changed.endMinute, 1020)
    XCTAssertEqual(try WritingAvailability.requestedSlotCount("just my first available time"), 1)
    XCTAssertThrowsError(try WritingAvailability.requestedSlotCount("suggest 20 timeslots"))
    XCTAssertThrowsError(try WritingToolPlan.parse(#"{"tools":[{"name":"find_availability","day":"2026-09-24","slotCount":0}]}"#))
  }

  func testMalformedBusyEventCannotEstablishFreeTime() throws {
    let request = try WritingAvailability(day: "2026-09-24", timeZone: zone)
    XCTAssertThrowsError(try request.firstSlot(events: [busy("2026-09-24T17:00:00Z", "2026-09-24T16:00:00Z")], now: date("2026-09-23T22:00:00Z")))
  }
  func testSchedulingPlanHasBoundedValidatedSemanticParameters() throws {
    let plan = try WritingToolPlan.parse(#"{"tools":[{"name":"find_availability","day":"2026-09-24","durationMinutes":45,"startMinute":600,"endMinute":960}]}"#)
    XCTAssertEqual(try plan.tools.first?.availability(timeZone: zone).durationMinutes, 45)
    for json in [
      #"{"tools":[{"name":"find_availability","day":"tomorrow"}]}"#,
      #"{"tools":[{"name":"find_availability","day":"2026-09-24","durationMinutes":999}]}"#,
      #"{"tools":[{"name":"find_availability","day":"2026-09-24"},{"name":"find_availability","day":"2026-09-25"}]}"#
    ] { XCTAssertThrowsError(try WritingToolPlan.parse(json)) }
  }
  func testBoundedCalendarReadRejectsMalformedActiveEventButAllowsCancelled() async throws {
    for item in [
      #"{"id":"bad","start":{"dateTime":"not a date"},"end":{"dateTime":"2026-09-24T18:00:00Z"}}"#,
      #"{"id":"bad","start":{"dateTime":"2026-09-24T19:00:00Z"},"end":{"dateTime":"2026-09-24T18:00:00Z"}}"#
    ] {
      let client = GoogleCalendarClient(transport: MockHTTP { _ in Data("{\"items\":[\(item)]}".utf8) })
      do {
        _ = try await client.events(token: "synthetic", from: Date(), to: Date().addingTimeInterval(86400), maxPages: 2)
        XCTFail("Malformed active event silently established free time")
      } catch {}
    }
    let client = GoogleCalendarClient(transport: MockHTTP { _ in Data(#"{"items":[{"id":"deleted","status":"cancelled"}]}"#.utf8) })
    let events = try await client.events(token: "synthetic", from: Date(), to: Date().addingTimeInterval(86400), maxPages: 2)
    XCTAssertTrue(events.isEmpty)
  }
}
