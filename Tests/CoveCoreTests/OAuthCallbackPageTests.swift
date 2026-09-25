import XCTest
@testable import CoveCore

final class OAuthCallbackPageTests: XCTestCase {
  func testSuccessAndFailurePagesHaveDistinctTruthfulOutcomes() {
    XCTAssertTrue(OAuthCallbackPage.connected.html.contains("Thank you. You’re in."))
    XCTAssertTrue(OAuthCallbackPage.connected.html.contains("Gmail is connected."))
    for page in [OAuthCallbackPage.denied, .failed, .invalid] {
      XCTAssertFalse(page.html.contains("Gmail is connected."))
      XCTAssertFalse(page.html.contains("Thank you. You’re in."))
      XCTAssertTrue(page.html.contains("Return to Cove"))
    }
    XCTAssertTrue(OAuthCallbackPage.denied.html.contains("wasn’t approved"))
    XCTAssertTrue(OAuthCallbackPage.invalid.html.contains("continue in that tab"))
  }

  func testResponsesAreSelfContainedUncacheableAndHaveCorrectByteLengths() throws {
    for page in OAuthCallbackPage.allCases {
      let response = String(decoding: page.httpResponse, as: UTF8.self)
      let boundary = try XCTUnwrap(response.range(of: "\r\n\r\n"))
      let headers = String(response[..<boundary.lowerBound])
      let body = String(response[boundary.upperBound...])
      XCTAssertTrue(headers.contains("Content-Length: \(body.utf8.count)"))
      XCTAssertTrue(headers.contains("Content-Type: text/html; charset=utf-8"))
      XCTAssertTrue(headers.contains("Cache-Control: no-store"))
      XCTAssertTrue(headers.contains("Referrer-Policy: no-referrer"))
      XCTAssertTrue(headers.contains("frame-ancestors 'none'"))
      XCTAssertTrue(headers.contains("default-src 'none'"))
      XCTAssertFalse(body.contains("<script"))
      XCTAssertFalse(body.contains("https://"))
      XCTAssertFalse(body.contains("http://"))
      XCTAssertFalse(body.contains("href="))
      XCTAssertTrue(body.contains("prefers-reduced-motion: reduce"))
      XCTAssertTrue(body.contains("aria-hidden=\"true\""))
      XCTAssertTrue(body.contains("<html lang=\"en\">"))
      XCTAssertFalse(body.contains("infinite"))
    }
  }
}
