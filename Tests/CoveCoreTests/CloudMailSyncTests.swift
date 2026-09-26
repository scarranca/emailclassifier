import Foundation
import XCTest
@testable import CoveCore

final class CloudMailSyncTests: XCTestCase {
  let now = Date(timeIntervalSince1970: 1_790_338_400)
  func mail(_ id: String = "abcdef") -> Mail {
    Mail(id: id, sender: "Sender", senderEmail: "sender@example.com", to: "me@example.com",
      subject: "Private subject", body: "Body", date: now, draft: "DO NOT UPLOAD THIS DRAFT")
  }
  func testExportUsesAllowlistAndNeverIncludesDraftOrAttachments() throws {
    var m = mail()
    m.htmlBody = "<p>Body</p>"
    m.decision = Decision(category: .work, confidence: 0.9, needsReply: 0.8, urgent: 0.3, model: "jev")
    let record = try XCTUnwrap(CloudMailRecord(m, now: now))
    let encoded = try JSONEncoder().encode(record)
    let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    XCTAssertEqual(Set(raw.keys), ["id", "threadID", "receivedAt", "labels", "metadata", "body"])
    XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("DO NOT UPLOAD"))
    XCTAssertEqual(record.metadata.decision?.category, .work)
    m.draft = "A different private draft"
    XCTAssertEqual(try record.fingerprint, try XCTUnwrap(CloudMailRecord(m, now: now)).fingerprint)
  }
  func testRecentWindowAndMessageTypes() throws {
    for labels: Set<String> in [["DRAFT"], ["TRASH"], ["SPAM"]] {
      var m = mail(); m.labels = labels
      XCTAssertNil(CloudMailRecord(m, now: now))
    }
    XCTAssertNil(CloudMailRecord(mail("local-abc"), now: now))
    var old = mail(); old.date = now.addingTimeInterval(-31 * 86400)
    XCTAssertNil(CloudMailRecord(old, now: now))
    var future = mail(); future.date = now.addingTimeInterval(2 * 86400)
    XCTAssertNil(CloudMailRecord(future, now: now))
    let records = CloudMailRecord.recent((0..<1100).map { mail(String($0, radix: 16)) }, now: now)
    XCTAssertEqual(records.count, 1000)
  }
  func testUnicodeBodiesAreBoundedAndMarkedTruncated() throws {
    var m = mail(); m.body = String(repeating: "🎈", count: 20000)
    m.htmlBody = String(repeating: "漢", count: 50000)
    let record = try XCTUnwrap(CloudMailRecord(m, now: now))
    XCTAssertLessThanOrEqual(record.body.text.utf8.count, 48000)
    XCTAssertLessThanOrEqual(record.body.html!.utf8.count, 96000)
    XCTAssertFalse(record.body.text.contains("�"))
    XCTAssertTrue(record.body.truncated)
  }
  func testJSONEscapingStaysBelowBatchLimit() throws {
    var m = mail(); m.body = String(repeating: "\u{0001}", count: 48000)
    m.htmlBody = String(repeating: "\u{0002}", count: 96000)
    let record = try XCTUnwrap(CloudMailRecord(m, now: now))
    XCTAssertLessThanOrEqual(try JSONEncoder().encode(record).count, 200000)
    XCTAssertTrue(record.body.truncated)
  }
  func testHTTPSOriginRequired() {
    for url in ["http://localhost", "https://token@example.com", "https://example.com/path", "https://example.com?token=x"] {
      XCTAssertThrowsError(try CloudMailClient(baseURL: URL(string: url)!))
    }
  }
  func testClientRequestsAndSanitizedFailure() async throws {
    let id = UUID()
    let transport = CloudTransport { request in
      XCTAssertEqual(request.url?.path, "/v1/connection")
      XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fixture")
      XCTAssertEqual(request.httpMethod, "POST")
      XCTAssertEqual(String(data: request.httpBody!, encoding: .utf8), #"{"consentVersion":"cloud-mail-v1"}"#)
      return (200, Data("{\"accountID\":\"\(id)\",\"revision\":\"0\"}".utf8))
    }
    let client = try CloudMailClient(baseURL: URL(string: "https://sync.example.com")!, transport: transport)
    let connected = try await client.connect(token: "fixture")
    XCTAssertEqual(connected.accountID, id)
    let failing = try CloudMailClient(baseURL: URL(string: "https://sync.example.com")!,
      transport: CloudTransport { _ in (503, Data(#"{"error":"private server content and credentials"}"#.utf8)) })
    do { _ = try await failing.connection(token: "fixture"); XCTFail("Expected failure") }
    catch { XCTAssertFalse(error.localizedDescription.contains("credentials")); XCTAssertTrue(error.localizedDescription.contains("still on this Mac")) }
  }
}
private struct CloudTransport: HTTPTransport {
  var handler: (URLRequest) throws -> (Int, Data)
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (status, data) = try handler(request)
    return (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
  }
}
