import CoveCore
import XCTest

@testable import Cove

@MainActor final class AIMailSearchTests: XCTestCase {
  private var directories: [URL] = []
  override func tearDown() {
    directories.forEach { try? FileManager.default.removeItem(at: $0) }
    directories = []
    super.tearDown()
  }

  private func fixture(_ transport: HTTPTransport) throws -> (AppStore, Database) {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    directories.append(directory)
    let db = try Database(url: directory.appendingPathComponent("mail.sqlite"))
    let existing = Mail(id: "existing", sender: "Maya", senderEmail: "maya@example.com",
      subject: "Current local version", body: "Cached body", labels: ["INBOX"], draft: "Unsent private draft")
    try db.saveMailSnapshot([existing], historyID: "cursor-keep", nextPage: "page-keep", updatesPagination: true)
    return (try AppStore(database: db, accountEmail: "me@example.com", gmail: GmailClient(transport: transport),
      gmailTokenProvider: { "fixture-token" }, syncClock: { Date() }), db)
  }

  func testSearchReachesGmailAndPreservesDraftLabelsAndSyncCursor() async throws {
    let http = SearchHTTP()
    let (store, db) = try fixture(http)
    let results = try await store.aiSearchMail("from:maya@example.com after:2026/01/01")
    XCTAssertEqual(Set(results.map(\.id)), ["existing", "discovered"])
    let cached = try XCTUnwrap(store.mails.first { $0.id == "existing" })
    XCTAssertEqual(cached.draft, "Unsent private draft")
    XCTAssertEqual(cached.subject, "Current local version")
    XCTAssertFalse(cached.isUnread)
    XCTAssertTrue(try db.loadMail().contains { $0.id == "discovered" })
    XCTAssertEqual(try db.load(String.self, key: "gmailHistoryID"), "cursor-keep")
    XCTAssertEqual(try db.load(String.self, key: "gmailNextPage"), "page-keep")
    let requests = await http.requests
    XCTAssertTrue(requests.allSatisfy { $0.httpMethod == "GET" })
    let query = URLComponents(url: requests[0].url!, resolvingAgainstBaseURL: false)!.queryItems!
    XCTAssertEqual(query.first { $0.name == "q" }?.value,
      "(from:maya@example.com after:2026/01/01) -in:trash -in:spam -in:drafts")
    XCTAssertEqual(query.first { $0.name == "maxResults" }?.value, "20")
    store.chooseFolder("All mail")
    store.select(try XCTUnwrap(results.first { $0.id == "discovered" }))
    XCTAssertTrue(store.visible.contains { $0.id == store.selectedID })
  }

  func testSearchRejectsBlankAndSampleWithoutRequests() async throws {
    let http = SearchHTTP()
    let (store, _) = try fixture(http)
    do { _ = try await store.aiSearchMail("   "); XCTFail("Empty query accepted") } catch {}
    store.isSample = true
    do { _ = try await store.aiSearchMail("launch"); XCTFail("Sample searched Google") } catch {}
    let requests = await http.requests
    XCTAssertTrue(requests.isEmpty)
  }

  func testSearchDropsCancelledResultsBeforeSaving() async throws {
    let started = expectation(description: "Search started")
    let http = SearchHTTP(started: started)
    let (store, db) = try fixture(http)
    let before = try db.loadMail()
    let task = Task { try await store.aiSearchMail("launch") }
    await fulfillment(of: [started], timeout: 2)
    task.cancel()
    await http.release()
    do { _ = try await task.value; XCTFail("Cancelled search published") }
    catch { XCTAssertTrue(error is CancellationError) }
    XCTAssertEqual(try db.loadMail(), before)
  }
}

private actor SearchHTTP: HTTPTransport {
  var requests: [URLRequest] = []
  let started: XCTestExpectation?
  var continuation: CheckedContinuation<Void, Never>?
  init(started: XCTestExpectation? = nil) { self.started = started }
  func release() { continuation?.resume(); continuation = nil }
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    requests.append(request)
    let object: [String: Any]
    if request.url!.lastPathComponent == "messages" {
      if let started {
        await withCheckedContinuation { continuation in
          self.continuation = continuation
          started.fulfill()
        }
      }
      object = ["messages": [["id": "existing"], ["id": "discovered"], ["id": "excluded"]]]
    } else {
      let id = request.url!.lastPathComponent
      object = ["id": id, "threadId": "thread-\(id)", "labelIds": id == "excluded" ? ["DRAFT"] : ["UNREAD"],
        "payload": ["mimeType": "text/plain", "headers": [["name": "Subject", "value": "Search result"]],
          "body": ["data": Data("Search body".utf8).base64URL]]]
    }
    return (try JSONSerialization.data(withJSONObject: object),
      HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
  }
}
