import Foundation
import XCTest
@testable import CoveCore

final class GmailSenderTests: XCTestCase {
  func testListsOnlyVerifiedUniqueSafeSendersWithMinimalFields() async throws {
    let client = GmailClient(transport: MockHTTP { request in
      XCTAssertEqual(request.httpMethod, "GET")
      XCTAssertEqual(request.url?.path, "/gmail/v1/users/me/settings/sendAs")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fixture")
      XCTAssertEqual(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value,
        "sendAs(sendAsEmail,isPrimary,verificationStatus)")
      return Data(#"{"sendAs":[{"sendAsEmail":"me@example.com","isPrimary":true},{"sendAsEmail":"work@example.com","verificationStatus":"accepted"},{"sendAsEmail":"WORK@example.com","verificationStatus":"accepted"},{"sendAsEmail":"pending@example.com","verificationStatus":"pending"},{"sendAsEmail":"unknown@example.com"},{"sendAsEmail":"bad@example.com\r\nBcc:x@example.com","verificationStatus":"accepted"},{"sendAsEmail":"@example.com","verificationStatus":"accepted"}]}"#.utf8)
    })
    let addresses = try await client.sendingAddresses(token: "fixture")
    XCTAssertEqual(addresses, ["me@example.com", "work@example.com"])
  }
}
