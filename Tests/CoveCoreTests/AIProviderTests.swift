import Foundation
import XCTest

@testable import CoveCore

final class AIProviderTests: XCTestCase {
  private final class Transport: HTTPTransport {
    var requests: [URLRequest] = []
    let response: String
    let status: Int
    init(_ response: String, status: Int = 200) {
      self.response = response
      self.status = status
    }
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
      requests.append(request)
      return (
        Data(response.utf8),
        HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
      )
    }
  }
  func testEachProviderUsesItsOfficialShapeAndExtractsOnlyText() async throws {
    let cases: [(AIProvider, String, String)] = [
      (.openRouter, "openrouter.ai", #"{"choices":[{"message":{"content":"draft"}}]}"#),
      (
        .openAI, "api.openai.com",
        #"{"output":[{"type":"message","content":[{"type":"output_text","text":"draft"}]}]}"#
      ),
      (
        .anthropic, "api.anthropic.com",
        #"{"content":[{"type":"thinking","thinking":"private"},{"type":"text","text":"draft"}]}"#
      ),
    ]
    for (provider, host, response) in cases {
      let transport = Transport(response)
      let text = try await AIProviderClient(transport: transport).complete(
        provider: provider, key: "fake-test-key", model: "test-model",
        prompt: AIPrompt(intent: .write, instruction: "Write a greeting", mails: []))
      XCTAssertEqual(text, "draft")
      let request = try XCTUnwrap(transport.requests.first)
      XCTAssertEqual(request.url?.host, host)
      XCTAssertEqual(request.httpMethod, "POST")
      let body = try XCTUnwrap(
        JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
      XCTAssertEqual(body["model"] as? String, "test-model")
      XCTAssertNil(body["tools"])
      if provider == .openAI {
        XCTAssertEqual(body["store"] as? Bool, false)
        XCTAssertEqual(body["max_output_tokens"] as? Int, 2048)
      }
      if provider == .anthropic {
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "fake-test-key")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
      } else {
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fake-test-key")
      }
    }
  }
  func testPromptBoundsUntrustedMailAndExcludesSpamTrashDrafts() throws {
    let mails =
      (0..<30).map {
        Mail(
          id: "m\($0)", sender: "Sender", senderEmail: "sender@example.com", subject: "Subject",
          body: String(repeating: "🤔", count: 8_000))
      } + [
        Mail(
          id: "spam", sender: "Spam", senderEmail: "spam@example.com", subject: "spam",
          body: "SPAM-CANARY", labels: ["SPAM"])
      ]
    let prompt = try AIPrompt(intent: .answer, instruction: "Summarize", mails: mails)
    let evidence = try JSONDecoder().decode([AIEmailContext].self, from: Data(prompt.emails.utf8))
    XCTAssertLessThanOrEqual(evidence.count, 20)
    XCTAssertEqual(prompt.sourceMails.count, evidence.count)
    XCTAssertEqual(prompt.sourceMails.map(\.body), evidence.map(\.body))
    XCTAssertLessThanOrEqual(evidence.reduce(0) { $0 + $1.body.utf8.count }, 48_000)
    XCTAssertTrue(evidence.allSatisfy { $0.body.utf8.count <= 6_000 })
    XCTAssertFalse(prompt.emails.contains("SPAM-CANARY"))
    XCTAssertFalse(prompt.system.contains("Sender"))
    XCTAssertThrowsError(
      try AIPrompt(intent: .write, instruction: String(repeating: "x", count: 8_001), mails: []))
  }
  func testAPIErrorDoesNotEchoProviderBodyOrKey() async throws {
    let transport = Transport("PRIVATE-MAIL fake-test-key", status: 401)
    do {
      _ = try await AIProviderClient(transport: transport).complete(
        provider: .openRouter, key: "fake-test-key", model: "test",
        prompt: AIPrompt(intent: .answer, instruction: "hi", mails: []))
      XCTFail("Expected authorization failure")
    } catch {
      XCTAssertFalse(error.localizedDescription.contains("PRIVATE-MAIL"))
      XCTAssertFalse(error.localizedDescription.contains("fake-test-key"))
      XCTAssertTrue(error.localizedDescription.contains("401"))
    }
  }
  func testSubscriptionCannotAccidentallyUseAPIAndBadHeaderNeverLeavesDevice() async throws {
    let transport = Transport("{}")
    let client = AIProviderClient(transport: transport)
    let prompt = try AIPrompt(intent: .answer, instruction: "hello", mails: [])
    for (provider, key) in [(AIProvider.chatGPT, "fake"), (.claudeSubscription, "fake"), (.openAI, "key\r\nInjected: header")] {
      do {
        _ = try await client.complete(provider: provider, key: key, model: "test", prompt: prompt)
        XCTFail("Should reject invalid request")
      } catch {}
    }
    for provider in [AIProvider.chatGPT, .claudeSubscription] {
      do { _ = try await client.models(provider: provider, key: "fake"); XCTFail("Subscription catalogs must use the CLI") }
      catch {}
    }
    XCTAssertTrue(transport.requests.isEmpty)
  }
  func testModelsUseProviderCatalog() async throws {
    let transport = Transport(#"{"data":[{"id":"z-model"},{"id":"a-model"}]}"#)
    let models = try await AIProviderClient(transport: transport).models(
      provider: .anthropic, key: "test-key")
    XCTAssertEqual(models, ["a-model", "z-model"])
    XCTAssertEqual(
      transport.requests.first?.url?.absoluteString, "https://api.anthropic.com/v1/models")
    XCTAssertEqual(transport.requests.first?.httpMethod, "GET")
  }
  func testOuterChatGPTSandboxBlocksReadingAndWritingOutsideRuntime() throws {
    let parent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      .resolvingSymlinksInPath()
    let runtime = parent.appendingPathComponent("runtime")
    try FileManager.default.createDirectory(at: runtime, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: parent) }
    let privateFile = parent.appendingPathComponent("private.txt")
    try "PRIVATE-CANARY".write(to: privateFile, atomically: true, encoding: .utf8)
    let profile = try ChatGPTSandbox.profile(
      runtime: runtime.resolvingSymlinksInPath().path, executable: "/bin/cat")
    func execute(_ arguments: [String]) throws -> (Int32, Data) {
      let process = Process()
      let output = Pipe()
      process.executableURL = URL(fileURLWithPath: "/usr/bin/sandbox-exec")
      process.arguments = ["-p", profile] + arguments
      process.standardOutput = output
      process.standardError = FileHandle.nullDevice
      try process.run()
      process.waitUntilExit()
      return (process.terminationStatus, output.fileHandleForReading.readDataToEndOfFile())
    }
    let denied = try execute(["/bin/cat", privateFile.path])
    XCTAssertNotEqual(denied.0, 0)
    XCTAssertTrue(denied.1.isEmpty)
    // A broad /System allowance would accidentally include the writable Data volume.
    if let resolved = realpath(privateFile.path, nil) {
      let alias = "/System/Volumes/Data" + String(cString: resolved)
      free(resolved)
      if FileManager.default.fileExists(atPath: alias) {
        let aliased = try execute(["/bin/cat", alias])
        XCTAssertNotEqual(aliased.0, 0)
        XCTAssertTrue(aliased.1.isEmpty)
      }
    }
    let escaped = parent.appendingPathComponent("escaped")
    let write = try execute(["/usr/bin/touch", escaped.path])
    XCTAssertNotEqual(write.0, 0)
    XCTAssertFalse(FileManager.default.fileExists(atPath: escaped.path))
    let ownFile = runtime.appendingPathComponent("own.txt")
    try "allowed".write(to: ownFile, atomically: true, encoding: .utf8)
    let allowed = try execute(["/bin/cat", ownFile.path])
    XCTAssertEqual(allowed.0, 0)
    XCTAssertEqual(String(decoding: allowed.1, as: UTF8.self), "allowed")
    XCTAssertThrowsError(
      try ChatGPTSandbox.profile(runtime: "/invalid\npath", executable: "/bin/cat"))
  }
  func testClaudeSandboxPreservesPrivateFileBoundary() throws {
    let parent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let runtime = parent.appendingPathComponent("runtime")
    try FileManager.default.createDirectory(at: runtime, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: parent) }
    let privateFile = parent.appendingPathComponent("private.txt")
    try "PRIVATE-CANARY".write(to: privateFile, atomically: true, encoding: .utf8)
    let profile = try ClaudeSandbox.profile(runtime: runtime.path, executable: "/bin/cat")
    for arguments in [["/bin/cat", privateFile.path], ["/usr/bin/touch", parent.appendingPathComponent("escaped").path]] {
      let worker = Process(), pipe = Pipe()
      worker.executableURL = URL(fileURLWithPath: "/usr/bin/sandbox-exec")
      worker.arguments = ["-p", profile] + arguments
      worker.standardOutput = pipe; worker.standardError = FileHandle.nullDevice
      try worker.run(); worker.waitUntilExit()
      XCTAssertNotEqual(worker.terminationStatus, 0)
      XCTAssertTrue(pipe.fileHandleForReading.readDataToEndOfFile().isEmpty)
    }
    XCTAssertFalse(FileManager.default.fileExists(atPath: parent.appendingPathComponent("escaped").path))
  }
  func testChatGPTSandboxCanPersistCredentialsInOnlyTheSelectedKeychain() throws {
    let parent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      .resolvingSymlinksInPath()
    let runtime = parent.appendingPathComponent("runtime")
    let keychain = parent.appendingPathComponent("fixture.keychain-db")
    try FileManager.default.createDirectory(at: runtime, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: parent) }
    func run(_ arguments: [String], profile: String? = nil) throws -> (Int32, Data) {
      let process = Process()
      let output = Pipe()
      process.executableURL = URL(
        fileURLWithPath: profile == nil ? arguments[0] : "/usr/bin/sandbox-exec")
      process.arguments = profile.map { ["-p", $0] + arguments } ?? Array(arguments.dropFirst())
      process.environment = ProcessInfo.processInfo.environment.merging(["TMPDIR": runtime.path]) {
        _, new in new
      }
      process.standardOutput = output
      process.standardError = FileHandle.nullDevice
      try process.run()
      let data = output.fileHandleForReading.readDataToEndOfFile()
      process.waitUntilExit()
      return (process.terminationStatus, data)
    }
    let originalSearchList = try run(["/usr/bin/security", "list-keychains", "-d", "user"]).1
    XCTAssertEqual(
      try run([
        "/usr/bin/security", "create-keychain", "-p", "disposable-fixture-password", keychain.path,
      ]).0, 0)
    defer {
      _ = try? run(["/usr/bin/security", "delete-keychain", keychain.path])
      XCTAssertEqual(
        try? run(["/usr/bin/security", "list-keychains", "-d", "user"]).1, originalSearchList)
    }
    let restrictive = try ChatGPTSandbox.profile(
      runtime: runtime.path, executable: "/usr/bin/security")
    XCTAssertNotEqual(
      try run(["/usr/bin/security", "show-keychain-info", keychain.path], profile: restrictive).0, 0
    )
    let fixed = try ChatGPTSandbox.profile(
      runtime: runtime.path, executable: "/usr/bin/security", keychain: keychain.path)
    XCTAssertEqual(
      try run(
        [
          "/usr/bin/security", "add-generic-password", "-a", "fixture-account", "-s",
          "cove-fixture", "-w", "fixture-secret", keychain.path,
        ], profile: fixed
      ).0, 0)
    let read = try run(
      [
        "/usr/bin/security", "find-generic-password", "-a", "fixture-account", "-s", "cove-fixture",
        "-w", keychain.path,
      ], profile: fixed)
    XCTAssertEqual(read.0, 0)
    XCTAssertEqual(
      String(decoding: read.1, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines),
      "fixture-secret")
    let unrelated = parent.appendingPathComponent("private-mail.txt")
    try "PRIVATE-CANARY".write(to: unrelated, atomically: true, encoding: .utf8)
    let denied = try run(["/bin/cat", unrelated.path], profile: fixed)
    XCTAssertNotEqual(denied.0, 0)
    XCTAssertTrue(denied.1.isEmpty)
    XCTAssertNotEqual(
      try run(
        ["/usr/bin/touch", parent.appendingPathComponent("other.keychain-db").path], profile: fixed
      ).0, 0)
    XCTAssertEqual(
      try run(
        [
          "/usr/bin/security", "delete-generic-password", "-a", "fixture-account", "-s",
          "cove-fixture", keychain.path,
        ], profile: fixed
      ).0, 0)
  }
}
