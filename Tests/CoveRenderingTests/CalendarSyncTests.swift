import CSQLite
import CoveCore
import XCTest

@testable import Cove

@MainActor
final class CalendarSyncTests: XCTestCase {
  private var directories: [URL] = []
  private let day = Calendar.current.startOfDay(for: Date())
  override func tearDown() {
    directories.forEach { try? FileManager.default.removeItem(at: $0) }
    directories = []
    super.tearDown()
  }
  private func fixture(_ http: CalendarHTTP) throws -> (AppStore, Database) {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    directories.append(directory)
    let db = try Database(url: directory.appendingPathComponent("calendar.sqlite"))
    let store = try AppStore(
      database: db, accountEmail: "calendar@example.com",
      gmail: GmailClient(transport: http), gmailTokenProvider: { "test-token" },
      syncClock: { self.day }, calendarClient: GoogleCalendarClient(transport: http))
    store.calendarConnected = true
    store.now = day
    store.calendarDay = day
    return (store, db)
  }
  func testMonthViewSyncsEveryVisibleDayIncludingAdjacentMonths() async throws {
    let http = CalendarHTTP()
    let (store, _) = try fixture(http)
    await CalendarView(store: store, mode: .month).refresh()
    let requestURL = await http.lastURL
    let components = try XCTUnwrap(URLComponents(url: XCTUnwrap(requestURL), resolvingAgainstBaseURL: false))
    let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    let expected = CalendarDisplayMode.month.range(containing: day)
    let formatter = ISO8601DateFormatter()
    XCTAssertEqual(query["timeMin"].flatMap(formatter.date(from:)), expected.start)
    XCTAssertEqual(query["timeMax"].flatMap(formatter.date(from:)), expected.end)
    XCTAssertTrue(store.calendarAvailabilityReady)
  }

  func testSyncWaitsForBusyWorkAndPublishesPersistedCoverage() async throws {
    let http = CalendarHTTP()
    let (store, db) = try fixture(http)
    let local = LocalEvent(title: "Local", start: day, end: day.addingTimeInterval(3600))
    var removed = local
    removed.id = "removed-google"
    removed.googleID = "gone"
    store.events = [local, removed]
    store.busy = true
    let operation = Task { await store.syncCalendar(from: day, to: day.addingTimeInterval(86400)) }
    await Task.yield()
    XCTAssertTrue(store.calendarSyncing)
    XCTAssertFalse(store.calendarAvailabilityReady)
    let initialRequests = await http.count
    XCTAssertEqual(initialRequests, 0)
    store.busy = false
    await operation.value
    XCTAssertFalse(store.calendarSyncing)
    XCTAssertTrue(store.calendarAvailabilityReady)
    XCTAssertEqual(store.events.map(\.id), [local.id])
    XCTAssertEqual(try db.load([LocalEvent].self, key: "events")?.map(\.id), [local.id])
    store.showLocalCalendar = false
    XCTAssertTrue(store.visibleEvents.isEmpty)
    XCTAssertEqual(store.events.count, 1)
    store.now = day.addingTimeInterval(300)
    XCTAssertFalse(store.calendarAvailabilityReady, "Stale availability needs a refresh")
  }
  func testSyncFailureKeepsCacheAndDoesNotClaimAvailability() async throws {
    let (store, _) = try fixture(CalendarHTTP(status: 503))
    let saved = LocalEvent(title: "Saved", start: day, end: day.addingTimeInterval(3600))
    store.events = [saved]
    await store.syncCalendar(from: day, to: day.addingTimeInterval(86400))
    XCTAssertNotNil(store.calendarSyncError)
    XCTAssertFalse(store.calendarAvailabilityReady)
    XCTAssertFalse(store.calendarSyncing)
    XCTAssertEqual(store.events.map(\.id), [saved.id])
  }
  func testNewerRangeWinsOverDelayedReadAndMutationsWait() async throws {
    let started = expectation(description: "first request")
    let http = CalendarHTTP(started: started)
    let (store, _) = try fixture(http)
    let first = Task { await store.syncCalendar(from: day, to: day.addingTimeInterval(86400)) }
    await fulfillment(of: [started], timeout: 2)
    let creation = await store.createEvent(
      title: "Wait", start: day, end: day.addingTimeInterval(3600), onGoogle: false)
    XCTAssertFalse(creation)
    let next = day.addingTimeInterval(86400)
    store.calendarDay = next
    await store.syncCalendar(from: next, to: next.addingTimeInterval(86400))
    XCTAssertTrue(store.calendarAvailabilityReady)
    await http.release()
    await first.value
    XCTAssertTrue(
      store.calendarAvailabilityReady, "A late old response must not replace current coverage")
    XCTAssertFalse(store.calendarSyncing)
  }
  func testCancelledReadAndDisconnectedCalendarNeverPublishCoverage() async throws {
    let started = expectation(description: "request")
    let http = CalendarHTTP(started: started)
    let (store, db) = try fixture(http)
    let operation = Task { await store.syncCalendar(from: day, to: day.addingTimeInterval(86400)) }
    await fulfillment(of: [started], timeout: 2)
    operation.cancel()
    await http.release()
    await operation.value
    XCTAssertFalse(store.calendarAvailabilityReady)
    XCTAssertFalse(store.calendarSyncing)
    XCTAssertNil(store.calendarSyncError)
    XCTAssertNil(try db.load([LocalEvent].self, key: "events"))
    store.calendarConnected = false
    await store.syncCalendar(from: day, to: day.addingTimeInterval(86400))
    let requests = await http.count
    XCTAssertEqual(requests, 1)
  }
  func testLocalEventEditPreservesMetadataAndPersistsBeforePublishing() async throws {
    let (store, db) = try fixture(CalendarHTTP())
    var event = LocalEvent(title: "Meeting", start: day, end: day.addingTimeInterval(3600))
    event.details = "Existing notes"
    event.location = "Room 1"
    event.blocksTime = false
    event.localCalendar = .work
    store.events = [event]
    store.showLocalCalendar = false
    let result = await store.createEvent(
      title: "Edited", start: day, end: day.addingTimeInterval(7200), onGoogle: false,
      editing: event)
    XCTAssertTrue(result)
    XCTAssertEqual(store.events.count, 1)
    XCTAssertEqual(store.events.first?.id, event.id)
    XCTAssertEqual(store.events.first?.details, event.details)
    XCTAssertEqual(store.events.first?.blocksTime, false)
    XCTAssertEqual(store.events.first?.localCalendar, .work)
    XCTAssertEqual(store.calendarEventID, event.id)
    XCTAssertEqual(store.calendarDay, day)
    XCTAssertTrue(store.showLocalCalendar)
    XCTAssertEqual(try db.load([LocalEvent].self, key: "events")?.first?.title, "Edited")
  }
  func testLocalCalendarMovesPersistAndSavingRevealsOnlyTheDestination() async throws {
    let (store, db) = try fixture(CalendarHTTP())
    let created = await store.createEvent(
      title: "Focused work", start: day, end: day.addingTimeInterval(3600),
      onGoogle: false, localCalendar: .focus)
    XCTAssertTrue(created)
    let original = try XCTUnwrap(store.events.first)
    XCTAssertEqual(original.localCalendar, .focus)
    store.hiddenLocalCalendars = [.work, .personal, .focus]
    let moved = await store.createEvent(
      title: original.title, start: original.start, end: original.end,
      onGoogle: false, editing: original, localCalendar: .work)
    XCTAssertTrue(moved)
    XCTAssertEqual(store.events.count, 1)
    XCTAssertEqual(store.events.first?.id, original.id)
    XCTAssertEqual(store.hiddenLocalCalendars, [.personal, .focus])
    XCTAssertEqual(store.visibleEvents.map(\.id), [original.id])
    let persisted = try XCTUnwrap(db.load([LocalEvent].self, key: "events")?.first)
    XCTAssertEqual(persisted.localCalendar, .work)
    XCTAssertEqual(persisted.calendarTitle, "Work · On this Mac")
  }
  func testHiddenGroupsStayBusyAndCanBeRevealedWithoutChangingOtherGroups() throws {
    let (store, _) = try fixture(CalendarHTTP())
    let start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: day)!
    let work = LocalEvent(
      title: "Work meeting", start: start, end: start.addingTimeInterval(7200), localCalendar: .work)
    let personal = LocalEvent(title: "Legacy", start: start, end: start.addingTimeInterval(3600))
    var google = LocalEvent(title: "Google", start: start, end: start.addingTimeInterval(3600))
    google.googleID = "remote"
    store.events = [work, personal, google]
    store.setLocalCalendar(.work, visible: false)
    store.setLocalCalendar(.personal, visible: false)
    XCTAssertEqual(store.visibleEvents.map(\.id), [google.id])
    XCTAssertEqual(
      CalendarAgenda.focusInterval(store.events, on: day, now: day)?.start,
      work.end, "Hiding a calendar must not make its busy intervals available")
    let search = try XCTUnwrap(CalendarSearch.matches(store.events, query: "Work", now: day).first)
    XCTAssertFalse(store.isCalendarVisible(for: search))
    store.revealCalendar(for: search)
    XCTAssertEqual(store.visibleEvents.map(\.id), [work.id, google.id])
    XCTAssertFalse(store.isCalendarVisible(for: personal))
    store.showGoogleCalendar = false
    XCTAssertFalse(store.isCalendarVisible(for: google))
    store.revealCalendar(for: google)
    XCTAssertTrue(store.isCalendarVisible(for: google))
    XCTAssertFalse(store.isCalendarVisible(for: personal))
  }
  func testStorageFailureDoesNotPublishSyncCoverageOrSuccessfulLocalCreation() async throws {
    let (store, db) = try fixture(CalendarHTTP())
    var handle: OpaquePointer?
    XCTAssertEqual(
      sqlite3_open(directories.last!.appendingPathComponent("calendar.sqlite").path, &handle),
      SQLITE_OK)
    defer { sqlite3_close(handle) }
    XCTAssertEqual(
      sqlite3_exec(
        handle,
        "CREATE TRIGGER fail_events BEFORE INSERT ON records WHEN NEW.key='events' BEGIN SELECT RAISE(ABORT,'test failure'); END;",
        nil, nil, nil), SQLITE_OK)
    await store.syncCalendar(from: day, to: day.addingTimeInterval(86400))
    XCTAssertFalse(store.calendarAvailabilityReady)
    XCTAssertNotNil(store.calendarSyncError)
    let created = await store.createEvent(
      title: "Unsaved", start: day, end: day.addingTimeInterval(3600), onGoogle: false)
    XCTAssertFalse(created)
    XCTAssertTrue(store.events.isEmpty)
    XCTAssertNotNil(store.error)
    XCTAssertNil(try db.load([LocalEvent].self, key: "events"))
  }
  func testCalendarCommandsFollowSelectedDayAndVisibility() throws {
    let (store, _) = try fixture(CalendarHTTP())
    store.screen = "calendar"
    store.startNewItem()
    XCTAssertTrue(store.showNewEvent)
    XCTAssertFalse(store.showComposer)
    store.calendarEventID = "old-selection"
    store.selectCalendarDay(day.addingTimeInterval(3600))
    XCTAssertEqual(store.calendarDay, day)
    XCTAssertNil(store.calendarEventID)
    XCTAssertEqual(store.newItemTitle, "New event")
  }
}

private actor CalendarHTTP: HTTPTransport {
  private let status: Int
  private let started: XCTestExpectation?
  private var pending: CheckedContinuation<Void, Never>?
  private(set) var count = 0
  private(set) var lastURL: URL?
  init(status: Int = 200, started: XCTestExpectation? = nil) {
    self.status = status
    self.started = started
  }
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    count += 1
    lastURL = request.url
    XCTAssertEqual(request.httpMethod, "GET")
    XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
    if count == 1, let started {
      await withCheckedContinuation { continuation in
        pending = continuation
        started.fulfill()
      }
    }
    return (
      Data(#"{"items":[]}"#.utf8),
      try XCTUnwrap(
        HTTPURLResponse(
          url: XCTUnwrap(request.url), statusCode: status, httpVersion: nil, headerFields: nil))
    )
  }
  func release() {
    pending?.resume()
    pending = nil
  }
}
