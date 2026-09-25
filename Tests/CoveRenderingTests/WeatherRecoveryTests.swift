import CoreLocation
import CoveCore
import XCTest
@testable import Cove

@MainActor final class WeatherRecoveryTests: XCTestCase {
  private var suites: [String] = []
  private func preferences() -> UserDefaults {
    let suite = "Cove-Weather-Recovery-" + UUID().uuidString
    suites.append(suite)
    return UserDefaults(suiteName: suite)!
  }
  override func tearDown() {
    suites.forEach { UserDefaults(suiteName: $0)?.removePersistentDomain(forName: $0) }
    super.tearDown()
  }
  func testCityRecoversFromLocationFailureAndPersistsWithoutLocationPermission() async throws {
    let defaults = preferences()
    let http = RecoveryWeatherHTTP()
    var searches: [String] = []
    let weather = HomeWeatherController(defaults: defaults, client: HomeWeatherClient(transport: http), locationProvider: {
      throw CoveError.message("Location access is off.")
    }, cityProvider: { query in
      searches.append(query)
      return WeatherPlace(coordinate: try WeatherCoordinate(latitude: 37.7749, longitude: -122.4194), name: "San Francisco, California")
    })
    await weather.refresh(useLocation: true)
    XCTAssertNotNil(weather.error)
    await weather.refresh(city: "  San Francisco California  ")
    XCTAssertNil(weather.error)
    XCTAssertTrue(weather.enabled)
    XCTAssertFalse(weather.usesLocation)
    XCTAssertFalse(weather.working)
    XCTAssertEqual(weather.phase, "")
    XCTAssertEqual(searches, ["San Francisco California"])
    XCTAssertEqual(weather.name, "San Francisco, California")
    XCTAssertEqual(weather.cache?.coordinate.latitude, 37.77)
    await weather.refresh()
    let requests = await http.requests
    XCTAssertEqual(requests.count, 1)
    XCTAssertTrue(requests[0].url!.absoluteString.contains("lon=-122.42"))
    XCTAssertNil(requests[0].value(forHTTPHeaderField: "Authorization"))
    let restored = HomeWeatherController(defaults: defaults)
    XCTAssertEqual(restored.name, weather.name)
    XCTAssertEqual(restored.cache?.coordinate, weather.cache?.coordinate)
    XCTAssertFalse(restored.usesLocation)
  }
  func testCancelledCitySearchCannotReplaceNewerCityOrFetchOldForecast() async throws {
    let http = RecoveryWeatherHTTP()
    let weather = HomeWeatherController(defaults: preferences(), client: HomeWeatherClient(transport: http), cityProvider: { query in
      if query == "Old city" { try await Task.sleep(for: .milliseconds(80)) }
      return WeatherPlace(coordinate: try WeatherCoordinate(latitude: query == "Old city" ? 20 : 40, longitude: 10), name: query)
    })
    let first = Task { await weather.refresh(city: "Old city") }
    while !weather.working { await Task.yield() }
    XCTAssertEqual(weather.phase, "Finding Old city…")
    weather.cancelLookup()
    await weather.refresh(city: "New city")
    await first.value
    XCTAssertEqual(weather.name, "New city")
    XCTAssertEqual(weather.cache?.coordinate.latitude, 40)
    XCTAssertNil(weather.error)
    let count = await http.requests.count
    XCTAssertEqual(count, 1)
  }
  func testTurningWeatherOffDuringCityLookupDiscardsResult() async throws {
    let http = RecoveryWeatherHTTP()
    let weather = HomeWeatherController(defaults: preferences(), client: HomeWeatherClient(transport: http), cityProvider: { _ in
      try await Task.sleep(for: .milliseconds(40))
      return WeatherPlace(coordinate: try WeatherCoordinate(latitude: 40, longitude: 10), name: "Example")
    })
    let task = Task { await weather.refresh(city: "Example") }
    while !weather.working { await Task.yield() }
    weather.turnOff()
    await task.value
    XCTAssertFalse(weather.enabled)
    XCTAssertFalse(weather.working)
    XCTAssertNil(weather.cache)
    let count = await http.requests.count
    XCTAssertEqual(count, 0)
  }
}
private actor RecoveryWeatherHTTP: HTTPTransport {
  private(set) var requests: [URLRequest] = []
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    requests.append(request)
    let date = ISO8601DateFormatter().string(from: Date())
    let payload = """
    {"properties":{"timeseries":[{"time":"\(date)","data":{"instant":{"details":{"air_temperature":18,"wind_speed":3}},"next_1_hours":{"summary":{"symbol_code":"partlycloudy_day"},"details":{"precipitation_amount":0}}}}]}}
    """
    return (Data(payload.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
  }
}
