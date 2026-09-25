import Foundation

public struct HTTPFailure: LocalizedError {
  public let statusCode: Int
  public let message: String
  public var errorDescription: String? { message }
}

public protocol HTTPTransport {
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
public struct LiveHTTP: HTTPTransport {
  // No mail bodies, OAuth responses, cookies or API keys in shared disk caches.
  static func privateConfiguration() -> URLSessionConfiguration {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.urlCache = nil
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.httpCookieStorage = nil
    configuration.httpShouldSetCookies = false
    configuration.urlCredentialStorage = nil
    return configuration
  }
  private static let sharedSession = URLSession(
    configuration: privateConfiguration(), delegate: NoRedirects(), delegateQueue: nil)
  private let session: URLSession
  public init() { session = Self.sharedSession }
  // Allows deterministic transport tests without contacting providers.
  init(configuration: URLSessionConfiguration) {
    session = URLSession(configuration: configuration, delegate: NoRedirects(), delegateQueue: nil)
  }
  public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    guard request.url?.scheme?.lowercased() == "https" else {
      throw CoveError.message("API connections require HTTPS.")
    }
    let (data, response) = try await session.data(for: request)
    guard let response = response as? HTTPURLResponse else {
      throw CoveError.message("Invalid server response.")
    }
    return (data, response)
  }
}

private final class NoRedirects: NSObject, URLSessionTaskDelegate {
  func urlSession(
    _ session: URLSession, task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    // Provider endpoints are fixed. Never forward credentials or email to a redirect target.
    completionHandler(nil)
  }
}
public func checked(_ request: URLRequest, transport: HTTPTransport) async throws -> Data {
  let (data, response) = try await transport.data(for: request)
  guard (200..<300).contains(response.statusCode) else {
    // Avoid leaking server-echoed email bodies or credentials into diagnostics.
    let advice: String
    switch response.statusCode {
    case 401: advice = "Reconnect your account or check the API key."
    case 403: advice = "Check API access and granted permissions."
    case 429: advice = "The service is busy. Please retry in a moment."
    default: advice = "Please try again."
    }
    throw HTTPFailure(
      statusCode: response.statusCode,
      message: "\(request.url?.host ?? "Service") returned \(response.statusCode). \(advice)")
  }
  return data
}
extension Data {
  public var base64URL: String {
    base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(
      of: "/", with: "_"
    ).replacingOccurrences(of: "=", with: "")
  }
  public init?(base64URL: String) {
    var text = base64URL.replacingOccurrences(of: "-", with: "+").replacingOccurrences(
      of: "_", with: "/")
    text += String(repeating: "=", count: (4 - text.count % 4) % 4)
    self.init(base64Encoded: text)
  }
}
