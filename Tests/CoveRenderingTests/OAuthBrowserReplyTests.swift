import CoveCore
import XCTest
@testable import Cove

@MainActor final class OAuthBrowserReplyTests: XCTestCase {
  func testSuccessIsDeferredUntilExplicitCommitAndSentOnlyOnce() {
    var responses: [Data] = []
    let reply = OAuthBrowserReply { responses.append($0) }
    XCTAssertTrue(responses.isEmpty, "Receiving an OAuth code alone must not claim success")
    reply.finish(.connected)
    reply.finish(.failed)
    XCTAssertEqual(responses, [OAuthCallbackPage.connected.httpResponse])
  }

  func testPersistenceFailureDoesNotBecomeSuccess() {
    var responses: [Data] = []
    let reply = OAuthBrowserReply { responses.append($0) }
    reply.finish(.failed)
    reply.finish(.connected)
    XCTAssertEqual(responses, [OAuthCallbackPage.failed.httpResponse])
  }

  func testUnfinishedConnectionEventuallyReturnsFailureInsteadOfHanging() async throws {
    let sent = expectation(description: "browser response")
    var responses: [Data] = []
    let reply = OAuthBrowserReply(timeout: .milliseconds(10)) {
      responses.append($0)
      sent.fulfill()
    }
    await fulfillment(of: [sent], timeout: 2)
    reply.finish(.connected)
    XCTAssertEqual(responses, [OAuthCallbackPage.failed.httpResponse])
  }
}
