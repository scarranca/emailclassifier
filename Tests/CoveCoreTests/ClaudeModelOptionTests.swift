import XCTest
@testable import CoveCore

final class ClaudeModelOptionTests: XCTestCase {
  private func response(_ rows: [[String: String]]) throws -> Data {
    try JSONSerialization.data(withJSONObject: ["type": "control_response", "response": [
      "request_id": "cove-models", "subtype": "success", "response": ["models": rows]]])
  }
  func testLiveMetadataPinsVersionsAndKeepsAutomaticDistinct() throws {
    let options = try ClaudeModelOption.parse(response([
      ["value": "default", "resolvedModel": "claude-opus-5-5[1m]"],
      ["value": "opus[1m]", "resolvedModel": "claude-opus-5-5[1m]"],
      ["value": "haiku", "resolvedModel": "claude-haiku-4-5-20251001"],
      ["value": "other-alias", "resolvedModel": "claude-opus-5-5[1m]"]
    ]))
    XCTAssertEqual(options.map(\.id), ["default", "claude-opus-5-5[1m]", "claude-haiku-4-5-20251001"])
    XCTAssertEqual(options[0].label, "Automatic · Claude Opus 5.5 · 1M context")
    XCTAssertEqual(options[1].label, "Claude Opus 5.5 · 1M context")
    XCTAssertEqual(options[2].label, "Claude Haiku 4.5")
  }
  func testOlderMetadataDoesNotInventVersionsAndMalformedOutputIsRedacted() throws {
    let options = try ClaudeModelOption.parse(response([["value": "sonnet", "displayName": "Sonnet"]]))
    XCTAssertEqual(options[0].id, "sonnet")
    XCTAssertEqual(options[0].label, "sonnet · automatic version")
    for data in [Data("private error".utf8), try response([]), try response([["value": "--unsafe"]])] {
      XCTAssertThrowsError(try ClaudeModelOption.parse(data)) { error in
        XCTAssertFalse(error.localizedDescription.contains("private error"))
      }
    }
  }
}
