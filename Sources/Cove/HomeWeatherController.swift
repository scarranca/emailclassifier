import CoreLocation
import CoveCore
import Foundation
import Observation

@MainActor final class WeatherLocation: NSObject, @preconcurrency CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private var pending: CheckedContinuation<CLLocation, Error>?
  private var timeout: Task<Void, Never>?
  private var updating = false
  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
  }
  func locate() async throws -> CLLocation {
    guard pending == nil else { throw CoveError.message("A location request is already in progress.") }
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        pending = continuation
        requestIfAllowed()
      }
    } onCancel: { Task { @MainActor in self.finish(.failure(CancellationError())) } }
  }
  private func requestIfAllowed() {
    guard pending != nil else { return }
    guard CLLocationManager.locationServicesEnabled() else {
      finish(.failure(CoveError.message("Location Services is off on this Mac. Enable it in System Settings, or choose a city below.")))
      return
    }
    switch manager.authorizationStatus {
    case .notDetermined: manager.requestWhenInUseAuthorization()
    case .authorizedAlways, .authorizedWhenInUse:
      guard !updating else { return }
      if let cached = manager.location, cached.horizontalAccuracy >= 0, abs(cached.timestamp.timeIntervalSinceNow) < 300 {
        finish(.success(cached)); return
      }
      updating = true
      // Start the timeout after authorization, so reading the permission prompt doesn't consume it.
      timeout = Task { [weak self] in
        do { try await Task.sleep(for: .seconds(20)) } catch { return }
        self?.finish(.failure(CoveError.message("Your Mac couldn’t determine its location. Make sure Wi-Fi is on, or choose a city below.")))
      }
      manager.startUpdatingLocation()
    case .denied, .restricted:
      finish(.failure(CoveError.message("Location access is off. Enable Cove in System Settings → Privacy & Security → Location Services, or enter a city.")))
    @unknown default: finish(.failure(CoveError.message("Location isn’t available. Enter a city instead.")))
    }
  }
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { requestIfAllowed() }
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last(where: { $0.horizontalAccuracy >= 0 && abs($0.timestamp.timeIntervalSinceNow) < 300 }) else { return }
    finish(.success(location))
  }
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    // LocationUnknown is temporary; keep listening until a fix or the bounded timeout.
    if (error as? CLError)?.code == .locationUnknown { return }
    finish(.failure(CoveError.message("Couldn’t find your location. Check Location Services or enter a city.")))
  }
  func cancel() { finish(.failure(CancellationError())) }
  private func finish(_ result: Result<CLLocation, Error>) {
    let continuation = pending
    pending = nil
    timeout?.cancel(); timeout = nil
    updating = false
    manager.stopUpdatingLocation()
    continuation?.resume(with: result)
  }
}

struct WeatherPlace {
  let coordinate: WeatherCoordinate
  let name: String
}

@MainActor final class WeatherCitySearch {
  private let geocoder = CLGeocoder()
  private var pending: CheckedContinuation<WeatherPlace, Error>?
  private var timeout: Task<Void, Never>?
  private var requestID = UUID()
  func find(_ city: String) async throws -> WeatherPlace {
    cancel()
    let id = UUID(); requestID = id
    return try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        pending = continuation
        timeout = Task { [weak self] in
          do { try await Task.sleep(for: .seconds(15)) } catch { return }
          guard let self, self.requestID == id else { return }
          self.finish(.failure(CoveError.message("City search took too long. Check your connection and try again.")))
        }
        geocoder.geocodeAddressString(city) { [weak self] places, error in
          Task { @MainActor in
            guard let self, self.requestID == id, self.pending != nil else { return }
            if let place = places?.first, let point = place.location {
              do {
                let coordinate = try WeatherCoordinate(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude)
                let name = [place.locality ?? place.name, place.administrativeArea, place.country].compactMap { $0 }.joined(separator: ", ")
                self.finish(.success(WeatherPlace(coordinate: coordinate, name: name.isEmpty ? city : name)))
              } catch { self.finish(.failure(error)) }
            } else if (error as? CLError)?.code == .network {
              self.finish(.failure(CoveError.message("City search couldn’t connect. Check your internet connection and try again.")))
            } else {
              self.finish(.failure(CoveError.message("That city wasn’t found. Try a city and state or country, such as San Francisco, California.")))
            }
          }
        }
      }
    } onCancel: { Task { @MainActor in if self.requestID == id { self.cancel() } } }
  }
  func cancel() { requestID = UUID(); finish(.failure(CancellationError())) }
  private func finish(_ result: Result<WeatherPlace, Error>) {
    let continuation = pending; pending = nil
    timeout?.cancel(); timeout = nil
    geocoder.cancelGeocode()
    continuation?.resume(with: result)
  }
}

@MainActor @Observable final class HomeWeatherController {
  var cache: WeatherCache?
  var working = false
  var error: String?
  var phase = ""
  var name: String
  var enabled: Bool
  var usesLocation: Bool
  var fahrenheit: Bool { didSet { defaults.set(fahrenheit, forKey: "homeWeather.fahrenheit") } }
  private let defaults: UserDefaults
  private let client: HomeWeatherClient
  private let location = WeatherLocation()
  private let citySearch = WeatherCitySearch()
  private let locationProvider: (() async throws -> CLLocation)?
  private let cityProvider: ((String) async throws -> WeatherPlace)?
  private var requestID = UUID()
  private var retryAfter = Date.distantPast
  init(defaults: UserDefaults = .standard, client: HomeWeatherClient = HomeWeatherClient(), locationProvider: (() async throws -> CLLocation)? = nil, cityProvider: ((String) async throws -> WeatherPlace)? = nil) {
    self.locationProvider = locationProvider
    self.cityProvider = cityProvider
    self.defaults = defaults; self.client = client
    enabled = defaults.bool(forKey: "homeWeather.enabled")
    usesLocation = defaults.bool(forKey: "homeWeather.location")
    name = defaults.string(forKey: "homeWeather.name") ?? "Your area"
    fahrenheit = defaults.object(forKey: "homeWeather.fahrenheit") as? Bool ?? (Locale.current.region?.identifier == "US")
    if enabled, let data = defaults.data(forKey: "homeWeather.cache") { cache = try? JSONDecoder().decode(WeatherCache.self, from: data) }
  }
  func turnOff() {
    cancelLookup()
    enabled = false; cache = nil
    defaults.set(false, forKey: "homeWeather.enabled")
    defaults.removeObject(forKey: "homeWeather.cache")
    defaults.removeObject(forKey: "homeWeather.name")
  }
  func cancelLookup() {
    requestID = UUID()
    location.cancel()
    citySearch.cancel()
    error = nil; working = false; phase = ""
  }
  func refresh(city: String? = nil, useLocation: Bool = false) async {
    guard !working else { return }
    let explicit = city != nil || useLocation
    guard explicit || enabled else { return }
    if !explicit, let cache, cache.expires > Date() { return }
    if !explicit, retryAfter > Date() { return }
    let id = UUID(); requestID = id
    working = true; error = nil
    defer { if id == requestID { working = false; phase = "" } }
    do {
      let coordinate: WeatherCoordinate
      var locationName = name
      let automaticLocation = useLocation || (city == nil && usesLocation)
      if automaticLocation {
        phase = "Finding your location…"
        let point: CLLocation
        if let locationProvider { point = try await locationProvider() } else { point = try await location.locate() }
        coordinate = try WeatherCoordinate(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude)
        locationName = "Your area"
      } else if let city {
        let query = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { throw CoveError.message("Enter a city to find its weather.") }
        phase = "Finding \(query)…"
        let place: WeatherPlace
        if let cityProvider { place = try await cityProvider(query) } else { place = try await citySearch.find(query) }
        coordinate = place.coordinate
        locationName = place.name
      } else if let cached = cache { coordinate = cached.coordinate }
      else { throw CoveError.message("Choose Use my location or enter a city.") }
      try Task.checkCancellation()
      guard id == requestID else { return }
      phase = "Loading the forecast…"
      let forecast = try await client.forecast(at: coordinate, cached: cache)
      guard id == requestID, !Task.isCancelled else { return }
      cache = forecast; name = locationName; enabled = true; usesLocation = automaticLocation
      defaults.set(true, forKey: "homeWeather.enabled")
      defaults.set(usesLocation, forKey: "homeWeather.location")
      defaults.set(name, forKey: "homeWeather.name")
      defaults.set(try JSONEncoder().encode(forecast), forKey: "homeWeather.cache")
      retryAfter = .distantPast
    } catch {
      guard id == requestID, !Task.isCancelled else { return }
      self.error = error.localizedDescription
      retryAfter = Date().addingTimeInterval(1800)
    }
  }
}
