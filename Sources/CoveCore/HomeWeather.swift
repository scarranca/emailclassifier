import Foundation

public struct WeatherCoordinate: Codable, Equatable, Sendable {
  public let latitude: Double
  public let longitude: Double
  public init(latitude: Double, longitude: Double) throws {
    guard latitude.isFinite, longitude.isFinite, (-90...90).contains(latitude), (-180...180).contains(longitude) else {
      throw CoveError.message("The weather location is invalid.")
    }
    self.latitude = (latitude * 100).rounded() / 100
    self.longitude = (longitude * 100).rounded() / 100
  }
}
public struct WeatherForecast: Codable, Sendable {
  public struct Point: Codable, Sendable {
    public let time: Date
    public let celsius: Double
    public let wind: Double
    public let symbol: String
    public let rain: Double?
  }
  public let points: [Point]
  public func current(at date: Date) -> Point? {
    points.min { abs($0.time.timeIntervalSince(date)) < abs($1.time.timeIntervalSince(date)) }
      .flatMap { abs($0.time.timeIntervalSince(date)) <= 3 * 3600 ? $0 : nil }
  }
}
public struct WeatherCache: Codable, Sendable {
  public let coordinate: WeatherCoordinate
  public let forecast: WeatherForecast
  public let fetched: Date
  public let expires: Date
  public let modified: String?
}
public struct HomeWeatherClient {
  private let transport: HTTPTransport
  public init(transport: HTTPTransport = WeatherHTTP()) { self.transport = transport }
  public func forecast(at coordinate: WeatherCoordinate, cached: WeatherCache?, now: Date = Date()) async throws -> WeatherCache {
    let prior = cached?.coordinate == coordinate ? cached : nil
    if let prior, prior.expires > now { return prior }
    var url = URLComponents(string: "https://api.met.no/weatherapi/locationforecast/2.0/compact")!
    url.queryItems = [URLQueryItem(name: "lat", value: String(coordinate.latitude)), URLQueryItem(name: "lon", value: String(coordinate.longitude))]
    var request = URLRequest(url: url.url!)
    request.timeoutInterval = 25
    request.setValue("Cove/0.1.17 (ai.cove.mac; https://gigstack.io)", forHTTPHeaderField: "User-Agent")
    if let modified = prior?.modified { request.setValue(modified, forHTTPHeaderField: "If-Modified-Since") }
    let (data, response) = try await transport.data(for: request)
    let dates = DateFormatter()
    dates.locale = Locale(identifier: "en_US_POSIX")
    dates.timeZone = TimeZone(secondsFromGMT: 0)
    dates.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
    let expires = max(now.addingTimeInterval(1800), response.value(forHTTPHeaderField: "Expires").flatMap { dates.date(from: $0) } ?? now)
    if response.statusCode == 304, let prior {
      return WeatherCache(coordinate: coordinate, forecast: prior.forecast, fetched: now, expires: expires, modified: prior.modified)
    }
    guard response.statusCode == 200, data.count <= 2_000_000 else {
      throw CoveError.message("Weather is unavailable right now. Try again later.")
    }
    struct Payload: Decodable {
      struct Properties: Decodable {
        struct Item: Decodable {
          struct Values: Decodable {
            struct Instant: Decodable { struct Details: Decodable { var air_temperature: Double; var wind_speed: Double }; var details: Details }
            struct Period: Decodable {
              struct Summary: Decodable { var symbol_code: String }
              struct Details: Decodable { var precipitation_amount: Double? }
              var summary: Summary
              var details: Details?
            }
            var instant: Instant
            var next_1_hours: Period?
            var next_6_hours: Period?
          }
          var time: String
          var data: Values
        }
        var timeseries: [Item]
      }
      var properties: Properties
    }
    let decoded = try JSONDecoder().decode(Payload.self, from: data)
    let iso = ISO8601DateFormatter()
    let points = decoded.properties.timeseries.compactMap { item -> WeatherForecast.Point? in
      guard let time = iso.date(from: item.time), (-100...80).contains(item.data.instant.details.air_temperature), item.data.instant.details.wind_speed >= 0 else { return nil }
      return .init(time: time, celsius: item.data.instant.details.air_temperature, wind: item.data.instant.details.wind_speed,
        symbol: item.data.next_1_hours?.summary.symbol_code ?? item.data.next_6_hours?.summary.symbol_code ?? "unknown",
        rain: item.data.next_1_hours?.details?.precipitation_amount)
    }
    let forecast = WeatherForecast(points: points)
    guard forecast.current(at: now) != nil else { throw CoveError.message("The weather forecast is out of date. Try again later.") }
    return WeatherCache(coordinate: coordinate, forecast: forecast, fetched: now, expires: expires, modified: response.value(forHTTPHeaderField: "Last-Modified"))
  }
}

/// Weather has no account credentials; redirects remain on the HTTPS forecast host.
public struct WeatherHTTP: HTTPTransport {
  private static let session: URLSession = {
    let config = URLSessionConfiguration.ephemeral
    config.urlCache = nil
    config.httpCookieStorage = nil
    config.urlCredentialStorage = nil
    return URLSession(configuration: config, delegate: WeatherRedirects(), delegateQueue: nil)
  }()
  public init() {}
  public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    guard request.url?.scheme == "https", request.url?.host == "api.met.no" else { throw CoveError.message("Invalid weather endpoint.") }
    let (data, response) = try await Self.session.data(for: request)
    guard let response = response as? HTTPURLResponse else { throw CoveError.message("Invalid weather response.") }
    return (data, response)
  }
}
private final class WeatherRedirects: NSObject, URLSessionTaskDelegate {
  func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
    completionHandler(request.url?.scheme == "https" && request.url?.host == "api.met.no" ? request : nil)
  }
}
