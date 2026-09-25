import Foundation
import XCTest

@testable import CoveCore

private final class PrivacyProtocol: URLProtocol {
  static let lock = NSLock()
  static var requests: [URLRequest] = []
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    Self.lock.lock()
    Self.requests.append(request)
    Self.lock.unlock()
    if request.url?.path == "/redirect" {
      let response = HTTPURLResponse(
        url: request.url!, statusCode: 307, httpVersion: nil,
        headerFields: ["Location": "https://untrusted.example/collect"])!
      client?.urlProtocol(
        self, wasRedirectedTo: URLRequest(url: URL(string: "https://untrusted.example/collect")!),
        redirectResponse: response)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocolDidFinishLoading(self)
    } else {
      let response = HTTPURLResponse(
        url: request.url!, statusCode: 200, httpVersion: nil,
        headerFields: [
          "Cache-Control": "public, max-age=86400", "Set-Cookie": "private=mail; Secure; Path=/",
        ])!
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
      client?.urlProtocol(self, didLoad: Data("private mail response".utf8))
      client?.urlProtocolDidFinishLoading(self)
    }
  }
  override func stopLoading() {}
}

final class PrivateHTTPTests: XCTestCase {
  private func transport() -> LiveHTTP {
    PrivacyProtocol.lock.lock()
    PrivacyProtocol.requests = []
    PrivacyProtocol.lock.unlock()
    let config = LiveHTTP.privateConfiguration()
    XCTAssertNil(config.urlCache)
    XCTAssertNil(config.httpCookieStorage)
    XCTAssertNil(config.urlCredentialStorage)
    XCTAssertFalse(config.httpShouldSetCookies)
    XCTAssertEqual(config.requestCachePolicy, .reloadIgnoringLocalCacheData)
    config.protocolClasses = [PrivacyProtocol.self]
    return LiveHTTP(configuration: config)
  }

  func testMailResponsesAreNotCachedAndCookiesAreNotReused() async throws {
    let http = transport()
    let request = URLRequest(url: URL(string: "https://cove-test.example/mail")!)
    for _ in 0..<2 {
      let (data, _) = try await http.data(for: request)
      XCTAssertEqual(data, Data("private mail response".utf8))
    }
    let requests = PrivacyProtocol.requests
    XCTAssertEqual(requests.count, 2)
    XCTAssertTrue(requests.allSatisfy { $0.value(forHTTPHeaderField: "Cookie") == nil })
  }

  func testHTTPIsRejectedBeforeAnyTransmission() async throws {
    let http = transport()
    var request = URLRequest(url: URL(string: "http://cove-test.example/mail")!)
    request.setValue("Bearer synthetic-secret", forHTTPHeaderField: "Authorization")
    do {
      _ = try await http.data(for: request)
      XCTFail("Insecure transport accepted")
    } catch { XCTAssertTrue(PrivacyProtocol.requests.isEmpty) }
  }

  func testRedirectCannotForwardCredentialsOrBodyToAnotherHost() async throws {
    let http = transport()
    var request = URLRequest(url: URL(string: "https://cove-test.example/redirect")!)
    request.httpMethod = "POST"
    request.httpBody = Data("private email".utf8)
    request.setValue("Bearer synthetic-secret", forHTTPHeaderField: "Authorization")
    do {
      _ = try await checked(request, transport: http)
      XCTFail("Redirect was accepted")
    } catch { XCTAssertEqual((error as? HTTPFailure)?.statusCode, 307) }
    XCTAssertEqual(PrivacyProtocol.requests.map { $0.url?.host }, ["cove-test.example"])
  }
}
