import CoveCore
import XCTest

final class OutgoingMessageTests: XCTestCase {
  func testRequiredOriginHeadersAndSenderInjectionRejection() throws {
    let raw = try GmailClient.rawMessage(
      from: "me@example.com", to: "friend@example.com", subject: "Hello", body: "Café 🌊",
      date: Date(timeIntervalSince1970: 0))
    let data = try XCTUnwrap(Data(base64URL: raw))
    let mime = try XCTUnwrap(String(data: data, encoding: .utf8))
    XCTAssertTrue(
      mime.hasPrefix("From: me@example.com\r\nDate: Thu, 01 Jan 1970 00:00:00 +0000\r\n"))
    XCTAssertTrue(mime.contains("\r\nTo: friend@example.com\r\n"))
    let encodedBody = try XCTUnwrap(mime.components(separatedBy: "\r\n\r\n").last)
    XCTAssertEqual(
      Data(base64Encoded: encodedBody, options: .ignoreUnknownCharacters), Data("Café 🌊".utf8))
    for sender in ["", "missing-address", "me@example.com\r\nBcc: other@example.com"] {
      XCTAssertThrowsError(
        try GmailClient.rawMessage(
          from: sender, to: "friend@example.com", subject: "Hello", body: "Body"))
    }
  }

  func testLongUnicodeAndEmptySubjectsProduceValidFoldedHeaders() throws {
    let subjects = [
      "", String(repeating: "Revisión 🌊 東京 — ", count: 60),
      "a" + String(repeating: "\u{301}", count: 100),
    ]
    let expression = try NSRegularExpression(pattern: #"=\?UTF-8\?B\?([A-Za-z0-9+/=]+)\?="#)
    for subject in subjects {
      let raw = try GmailClient.rawMessage(
        from: "me@example.com", to: "friend@example.com", subject: subject, body: "Body")
      let mime = try XCTUnwrap(String(data: XCTUnwrap(Data(base64URL: raw)), encoding: .utf8))
      let header = try XCTUnwrap(mime.components(separatedBy: "\r\n\r\n").first)
      XCTAssertTrue(header.components(separatedBy: "\r\n").allSatisfy { $0.utf8.count <= 76 })
      let matches = expression.matches(in: header, range: NSRange(header.startIndex..., in: header))
      var restored = ""
      for match in matches {
        let word = String(header[try XCTUnwrap(Range(match.range, in: header))])
        XCTAssertLessThanOrEqual(word.utf8.count, 75)
        let encoded = String(header[try XCTUnwrap(Range(match.range(at: 1), in: header))])
        restored += try XCTUnwrap(
          String(data: XCTUnwrap(Data(base64Encoded: encoded)), encoding: .utf8))
      }
      XCTAssertEqual(restored, subject)
      if subject.isEmpty { XCTAssertTrue(header.contains("Subject: \r\n")) }
    }
  }
}
