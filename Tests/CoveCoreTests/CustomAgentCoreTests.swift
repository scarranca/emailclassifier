import XCTest
@testable import CoveCore

final class CustomAgentCoreTests: XCTestCase {
  func testValidationAllowsIncompleteDraftButNotActivation() throws {
    var draft = CustomAgent(); draft.name = "  My classifier  "
    XCTAssertEqual(try draft.validated(allowIncomplete: true).name, "My classifier")
    XCTAssertThrowsError(try draft.validated())
    draft.instructions = String(repeating: "é", count: 5000)
    XCTAssertThrowsError(try draft.validated(allowIncomplete: true))
    for name in ["SPAM", "inbox", "CATEGORY_PERSONAL", "bad\nlabel"] {
      var agent = CustomAgent.invoiceTemplate; agent.labelName = name
      XCTAssertThrowsError(try agent.validated())
    }
  }
  func testMalformedDecisionsFailClosed() async throws {
    for response in [
      "{\"model\":\"test\",\"answers\":{}}",
      "{\"model\":\"test\",\"answers\":{\"classification\":{\"choice\":\"delete\",\"confidence\":0.99}}}",
      "{\"model\":\"test\",\"answers\":{\"classification\":{\"choice\":\"match\",\"confidence\":1.1}}}"
    ] {
      let client = JevClient(transport: AgentCoreHTTP(response: response))
      do {
        _ = try await client.classify(Mail(sender: "A", senderEmail: "a@b.com", subject: "Invoice", body: "Invoice."), agent: .invoiceTemplate, key: "test")
        XCTFail("Malformed decision accepted")
      } catch { XCTAssertTrue(error.localizedDescription.contains("incomplete")) }
    }
  }
  func testLegacyLibraryDecodesAndBranchesValidate() throws {
    let agent = CustomAgent.invoiceTemplate
    let legacy = try JSONEncoder().encode(agent)
    XCTAssertNil(try JSONDecoder().decode(CustomAgent.self, from: legacy).rules)
    var branched = agent
    branched.labelName = ""
    branched.rules = [CustomAgentRule(condition: "US buyer", labelName: "US EXPENSE"),
      CustomAgentRule(condition: "MX buyer", action: .draftReply, replyInstructions: "Ask for the purchase order.")]
    XCTAssertNoThrow(try branched.validated())
    branched.rules![1].replyInstructions = ""
    XCTAssertThrowsError(try branched.validated())
    XCTAssertNoThrow(try branched.validated(allowIncomplete: true))
    branched.rules = []
    XCTAssertThrowsError(try branched.validated())
  }
  func testRuleChoiceRoutesOnlyKnownConfidentMatches() async throws {
    var agent = CustomAgent.invoiceTemplate
    agent.rules = [CustomAgentRule(condition: "Buyer is Happy Finances for All or Cherry", labelName: "US EXPENSE"),
      CustomAgentRule(condition: "Buyer is Disruptive Learning or Gigstack", labelName: "MX expense")]
    let cases: [(String, Double, String?)] = [("rule_0", 0.98, "US EXPENSE"), ("rule_1", 0.98, "MX expense"), ("rule_0", 0.5, nil), ("review", 0.98, nil)]
    for (choice, confidence, label) in cases {
      let response = "{\"model\":\"test\",\"answers\":{\"classification\":{\"choice\":\"\(choice)\",\"confidence\":\(confidence)}}}"
      let result = try await JevClient(transport: AgentCoreHTTP(response: response)).classify(
        Mail(sender: "Vendor", senderEmail: "vendor@example.com", subject: "Invoice", body: "Buyer Gigstack"), agent: agent, key: "test")
      XCTAssertEqual(result.label(for: agent), label)
      if confidence < 0.8 || choice == "review" { XCTAssertNil(result.ruleID) }
    }
    for choice in ["match", "rule_9", "send"] {
      let response = "{\"model\":\"test\",\"answers\":{\"classification\":{\"choice\":\"\(choice)\",\"confidence\":0.99}}}"
      do {
        _ = try await JevClient(transport: AgentCoreHTTP(response: response)).classify(
          Mail(sender: "A", senderEmail: "a@example.com", subject: "Invoice", body: "Invoice"), agent: agent, key: "test")
        XCTFail("Unknown rule accepted")
      } catch {}
    }
  }
  func testExistingCustomLabelIsReusedAndSystemLabelRejected() async throws {
    let http = AgentCoreHTTP(response: "{\"labels\":[{\"id\":\"Label_42\",\"name\":\"Finance / Invoices\",\"type\":\"user\"}]}")
    let label = try await GmailClient(transport: http).ensureUserLabel(named: "finance / invoices", token: "test")
    XCTAssertEqual(label.id, "Label_42")
    let requests = await http.requests; XCTAssertEqual(requests.count, 1); XCTAssertEqual(requests[0].httpMethod, "GET")
    let system = AgentCoreHTTP(response: "{\"labels\":[{\"id\":\"INBOX\",\"name\":\"INBOX\",\"type\":\"system\"}]}")
    do { _ = try await GmailClient(transport: system).ensureUserLabel(named: "Inbox", token: "test"); XCTFail("System label allowed") } catch {}
    let systemRequests = await system.requests; XCTAssertEqual(systemRequests.count, 1)
  }
}
private actor AgentCoreHTTP: HTTPTransport {
  let response: String
  var requests: [URLRequest] = []
  init(response: String) { self.response = response }
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    requests.append(request)
    return (Data(response.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
  }
}
