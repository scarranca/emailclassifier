import XCTest

@testable import CoveCore

final class MailboxQuestionsTests: XCTestCase {
  private func query(_ text: String) throws -> MailboxCountQuery {
    guard case .count(let query) = MailboxQuestion.parse(text) else {
      throw CoveError.message("Expected a count query")
    }
    return query
  }

  func testUnreadAndFolderQuestionsRouteWithoutAnEmailContext() throws {
    let allUnread = try query("How many unread emails do I have?")
    XCTAssertEqual(allUnread.labelID, "UNREAD")
    XCTAssertTrue(allUnread.unreadOnly)
    let inboxUnread = try query("Can you tell me how many unread emails are in my inbox?")
    XCTAssertEqual(inboxUnread.labelID, "INBOX")
    XCTAssertTrue(inboxUnread.unreadOnly)
    let all = try query("How many emails do I have?")
    XCTAssertNil(all.labelID)
    XCTAssertFalse(all.unreadOnly)
    XCTAssertEqual(try query("How many emails are in sent?").labelID, "SENT")
    XCTAssertNil(MailboxQuestion.parse("What does this sender need from me?"))
    XCTAssertNil(MailboxQuestion.parse("How many meetings are mentioned in this email?"))
  }

  func testUnsupportedFiltersNeverBecomeUnfilteredTotals() {
    for text in [
      "How many unread emails from Maya?", "How many unread emails today?",
      "How many unread emails with attachments?", "How many unread threads?",
      "How many emails are important?", "How many emails in inbox and spam?",
      "How many unread emails in Purchases?", "How many important unread emails?",
      "This email has how many unread messages?", "How many unread emails in inbox and starred?",
      "How many unread emails in 2024?", "How many unread and total emails?",
    ] {
      XCTAssertEqual(MailboxQuestion.parse(text), .unsupportedCount, text)
    }
  }

  func testGmailUnreadCountUsesAuthoritativeMessagesNotThreadsOrCachedPage() async throws {
    let transport = MailboxFixtureHTTP { request in
      XCTAssertEqual(request.httpMethod, "GET")
      XCTAssertEqual(request.url?.path, "/gmail/v1/users/me/labels/UNREAD")
      XCTAssertNil(request.httpBody)
      return (200, ["messagesTotal": 1234, "messagesUnread": 1234, "threadsUnread": 987])
    }
    let count = try await GmailClient(transport: transport).mailboxCount(
      query("How many unread emails do I have?"), token: "fixture")
    XCTAssertEqual(count, 1234)
  }

  func testInboxUnreadUsesUnreadFieldWhileTotalUsesProfile() async throws {
    let transport = MailboxFixtureHTTP { request in
      switch request.url!.lastPathComponent {
      case "INBOX":
        return (200, ["messagesTotal": 900, "messagesUnread": 125, "threadsUnread": 50])
      case "profile": return (200, ["messagesTotal": 20000, "threadsTotal": 10000])
      default: throw CoveError.message("Unexpected request")
      }
    }
    let client = GmailClient(transport: transport)
    let unread = try await client.mailboxCount(
      query("How many unread emails in my inbox?"), token: "fixture")
    let total = try await client.mailboxCount(query("How many emails do I have?"), token: "fixture")
    XCTAssertEqual(unread, 125)
    XCTAssertEqual(total, 20000)
  }

  func testMissingOrInvalidStatisticsNeverBecomeZero() async throws {
    for response in [[:], ["threadsUnread": 5], ["messagesTotal": -1]] {
      let client = GmailClient(transport: MailboxFixtureHTTP { _ in (200, response) })
      do {
        _ = try await client.mailboxCount(query("How many unread emails?"), token: "fixture")
        XCTFail("Missing or invalid message statistics must fail")
      } catch {}
    }
    let client = GmailClient(transport: MailboxFixtureHTTP { _ in (401, [:]) })
    do {
      _ = try await client.mailboxCount(query("How many unread emails?"), token: "fixture")
      XCTFail("An authentication failure must not be reported as a count")
    } catch let error as HTTPFailure {
      XCTAssertEqual(error.statusCode, 401)
    }
  }

  func testLocalSampleCountsHonorLabelAndUnreadScope() throws {
    let mail = [
      Mail(
        sender: "A", senderEmail: "a@example.com", subject: "A", body: "",
        labels: ["INBOX", "UNREAD"]),
      Mail(sender: "B", senderEmail: "b@example.com", subject: "B", body: "", labels: ["UNREAD"]),
      Mail(sender: "C", senderEmail: "c@example.com", subject: "C", body: "", labels: ["INBOX"]),
    ]
    XCTAssertEqual(try query("How many unread emails?").count(in: mail), 2)
    XCTAssertEqual(try query("How many unread emails in my inbox?").count(in: mail), 1)
    XCTAssertEqual(try query("How many emails in my inbox?").count(in: mail), 2)
  }
}

private struct MailboxFixtureHTTP: HTTPTransport {
  let respond: (URLRequest) throws -> (Int, [String: Int])
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (status, object) = try respond(request)
    return (
      try JSONSerialization.data(withJSONObject: object),
      HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
    )
  }
}
