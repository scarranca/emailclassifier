import CoveCore
import Security
import XCTest
@testable import Cove

@MainActor final class LiveCustomAgentTests: XCTestCase {
  func testSyntheticInvoiceThroughConfiguredJevWithoutGmailWrites() async throws {
    guard ProcessInfo.processInfo.environment["COVE_RUN_JEV_AGENT_SMOKE"] == "1" else { throw XCTSkip("Live Jev check is opt-in") }
    SecKeychainSetUserInteractionAllowed(false)
    defer { SecKeychainSetUserInteractionAllowed(true) }
    var value: CFTypeRef?
    let status = SecItemCopyMatching([
      kSecClass: kSecClassGenericPassword, kSecAttrService: "ai.cove.mac", kSecAttrAccount: "typesafeKey",
      kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne, kSecUseAuthenticationUI: kSecUseAuthenticationUIFail
    ] as CFDictionary, &value)
    guard status == errSecSuccess, let data = value as? Data, let key = String(data: data, encoding: .utf8), !key.isEmpty else {
      throw XCTSkip("Configured key is unavailable to the test runner without interaction")
    }
    let answer = try await JevClient().classify(CustomAgentEditor.example, agent: .invoiceTemplate, key: key)
    XCTAssertEqual(answer.outcome, .match)
    XCTAssertNotNil(answer.excerpt)
    // This test has no Gmail client and cannot apply labels or read real mail.
    try "Synthetic invoice: \(answer.outcome.rawValue); confidence \(answer.confidence); model \(answer.model). No Gmail requests.\n".write(toFile: "/tmp/cove-live-custom-agent.txt", atomically: true, encoding: .utf8)
  }
}
