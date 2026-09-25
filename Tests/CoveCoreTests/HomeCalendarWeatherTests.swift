import XCTest
@testable import CoveCore

final class HomeCalendarWeatherTests: XCTestCase {
  private let invitation = #"{"id":"instance_123","etag":"\"rev1\"","recurringEventId":"series1","summary":"Design review","organizer":{"email":"organizer@example.com","displayName":"Alex"},"start":{"dateTime":"2026-09-24T17:00:00Z"},"end":{"dateTime":"2026-09-24T17:30:00Z"},"attendees":[{"email":"alias@example.com","self":true,"responseStatus":"needsAction"},{"email":"other@example.com","responseStatus":"accepted"}]}"#
  func testCalendarReadIncludesHiddenInvitations() async throws {
    let http = HomeFixtureHTTP([Data(("{\"items\":[" + invitation + "]}").utf8)])
    let events = try await GoogleCalendarClient(transport: http).events(token: "fixture", from: Date(), to: Date().addingTimeInterval(86400), maxPages: 2)
    XCTAssertTrue(events.first?.isPendingInvitation == true)
    let request = await http.requests.first
    XCTAssertTrue(request?.url?.absoluteString.contains("showHiddenInvitations=true") == true)
  }
  func testInvitationMetadataAndOnlyOwnRSVPIsPatched() async throws {
    for response in CalendarRSVP.allCases {
      let http = HomeFixtureHTTP([Data(invitation.utf8), Data(invitation.replacingOccurrences(of: "needsAction", with: response.rawValue).utf8)])
      let updated = try await GoogleCalendarClient(transport: http).respond(token: "fixture", id: "instance_123", response: response)
      XCTAssertEqual(updated.ownResponse, response.rawValue)
      XCTAssertEqual(updated.recurringEventID, "series1")
      XCTAssertEqual(updated.organizerName, "Alex")
      XCTAssertFalse(updated.isPendingInvitation)
      XCTAssertEqual(updated.blocksTime, response != .declined)
      let requests = await http.requests
      XCTAssertEqual(requests.map(\.httpMethod), ["GET", "PATCH"])
      let patch = requests[1]
      XCTAssertEqual(patch.value(forHTTPHeaderField: "If-Match"), "\"rev1\"")
      XCTAssertTrue(patch.url!.absoluteString.contains("sendUpdates=all"))
      XCTAssertTrue(patch.url!.path.hasSuffix("instance_123"))
      let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(patch.httpBody)) as? [String: Any])
      XCTAssertEqual(Set(body.keys), ["attendeesOmitted", "attendees"])
      XCTAssertEqual(body["attendeesOmitted"] as? Bool, true)
      let attendees = try XCTUnwrap(body["attendees"] as? [[String: String]])
      XCTAssertEqual(attendees, [["email": "alias@example.com", "responseStatus": response.rawValue]])
    }
  }
  func testNoSelfOrCancelledInvitationCannotWriteAndRepeatIsIdempotent() async throws {
    for text in [invitation.replacingOccurrences(of: "\"self\":true", with: "\"self\":false"), invitation.replacingOccurrences(of: "\"summary\"", with: "\"status\":\"cancelled\",\"summary\"")] {
      let http = HomeFixtureHTTP([Data(text.utf8)])
      do { _ = try await GoogleCalendarClient(transport: http).respond(token: "fixture", id: "instance_123", response: .accepted); XCTFail() } catch {}
      let count = await http.requests.count
      XCTAssertEqual(count, 1)
    }
    let http = HomeFixtureHTTP([Data(invitation.replacingOccurrences(of: "needsAction", with: "accepted").utf8)])
    _ = try await GoogleCalendarClient(transport: http).respond(token: "fixture", id: "instance_123", response: .accepted)
    let count = await http.requests.count
    XCTAssertEqual(count, 1)
  }
  func testPendingOnlyMeansSelfNeedsActionAndOldCachesDecode() throws {
    let event = try JSONDecoder().decode(GoogleCalendarClient.Event.self, from: Data(invitation.utf8)).local()!
    XCTAssertTrue(event.isPendingInvitation)
    var old = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(event)) as? [String: Any])
    old["attendees"] = [["email": "alias@example.com", "response": "needsAction"]]
    let restored = try JSONDecoder().decode(LocalEvent.self, from: JSONSerialization.data(withJSONObject: old))
    XCTAssertFalse(restored.isPendingInvitation, "A response for an unidentified guest is not the user's invitation")
  }
  func testWeatherRoundsCoordinatesCachesAndRevalidates() async throws {
    let now = ISO8601DateFormatter().date(from: "2026-09-24T12:00:00Z")!
    let weather = Data(#"{"properties":{"timeseries":[{"time":"2026-09-24T12:00:00Z","data":{"instant":{"details":{"air_temperature":20,"wind_speed":3}},"next_1_hours":{"summary":{"symbol_code":"partlycloudy_day"},"details":{"precipitation_amount":0}}}}]}}"#.utf8)
    let http = HomeFixtureHTTP([weather, Data()], statuses: [200, 304], headers: ["Expires":"Thu, 24 Sep 2026 13:00:00 GMT", "Last-Modified":"Thu, 24 Sep 2026 11:00:00 GMT"])
    let client = HomeWeatherClient(transport: http)
    let coordinate = try WeatherCoordinate(latitude: 59.9139876, longitude: 10.7523456)
    XCTAssertEqual(coordinate.latitude, 59.91)
    XCTAssertEqual(coordinate.longitude, 10.75)
    let cache = try await client.forecast(at: coordinate, cached: nil, now: now)
    XCTAssertEqual(cache.forecast.current(at: now)?.celsius, 20)
    _ = try await client.forecast(at: coordinate, cached: cache, now: now.addingTimeInterval(300))
    let cachedRequests = await http.requests.count
    XCTAssertEqual(cachedRequests, 1)
    _ = try await client.forecast(at: coordinate, cached: cache, now: now.addingTimeInterval(3601))
    let requests = await http.requests
    XCTAssertEqual(requests.count, 2)
    XCTAssertTrue(requests[0].url!.absoluteString.contains("lat=59.91"))
    XCTAssertTrue(requests[0].value(forHTTPHeaderField: "User-Agent")!.contains("Cove"))
    XCTAssertNil(requests[0].value(forHTTPHeaderField: "Authorization"))
    XCTAssertEqual(requests[1].value(forHTTPHeaderField: "If-Modified-Since"), "Thu, 24 Sep 2026 11:00:00 GMT")
    XCTAssertNil(cache.forecast.current(at: now.addingTimeInterval(4 * 3600)))
    XCTAssertThrowsError(try WeatherCoordinate(latitude: .nan, longitude: 0))
  }
  func testWeatherFailureDoesNotInventForecast() async {
    let http = HomeFixtureHTTP([Data()], statuses: [429])
    do { _ = try await HomeWeatherClient(transport: http).forecast(at: WeatherCoordinate(latitude: 0, longitude: 0), cached: nil); XCTFail() } catch {}
  }
}
private actor HomeFixtureHTTP: HTTPTransport {
  let data: [Data]
  let statuses: [Int]
  let headers: [String: String]
  private(set) var requests: [URLRequest] = []
  init(_ data: [Data], statuses: [Int] = [], headers: [String: String] = [:]) { self.data = data; self.statuses = statuses; self.headers = headers }
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let index = requests.count
    requests.append(request)
    guard data.indices.contains(index) else { XCTFail("Unexpected request"); throw URLError(.badServerResponse) }
    return (data[index], HTTPURLResponse(url: request.url!, statusCode: statuses.indices.contains(index) ? statuses[index] : 200, httpVersion: nil, headerFields: headers)!)
  }
}
