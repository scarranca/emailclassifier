import AppKit
import SwiftUI
import CoveCore
import Foundation
import XCTest
@testable import Cove

@MainActor final class ClaudeConnectionTests: XCTestCase {
  private let modelFixture = #"{"type":"control_response","response":{"subtype":"success","request_id":"cove-models","response":{"models":[{"value":"default","resolvedModel":"claude-opus-5-5[1m]"},{"value":"sonnet","resolvedModel":"claude-sonnet-5"},{"value":"opus","resolvedModel":"claude-opus-5-5[1m]"},{"value":"haiku","resolvedModel":"claude-haiku-4-5-20251001"}]}}}"#
  private func result(_ json: String, code: Int32 = 0) -> ClaudeProcess.Result {
    .init(code: code, output: Data(json.utf8))
  }
  func testOfficialSignInAndLogoutAreDelegatedWithoutCredentials() async throws {
    var commands: [[String]] = []
    let connection = ClaudeConnection(runner: { args, input, _ in
      commands.append(args)
      XCTAssertNil(input)
      if args.contains("status") {
        return self.result(#"{"loggedIn":true,"authMethod":"claude.ai"}"#)
      }
      return self.result("{}")
    })
    try await connection.login()
    XCTAssertTrue(connection.connected)
    XCTAssertEqual(commands, [["auth", "login"], ["auth", "status", "--json"]])
    try await connection.logout()
    XCTAssertFalse(connection.connected)
    XCTAssertEqual(commands.last, ["auth", "logout"])
  }
  func testAPIKeyLoginIsNotMisrepresentedAsSubscription() async throws {
    let connection = ClaudeConnection(runner: { _, _, _ in
      self.result(#"{"loggedIn":true,"authMethod":"api_key"}"#)
    })
    try await connection.refresh()
    XCTAssertFalse(connection.connected)
    do { _ = try await connection.models(); XCTFail("No subscription") } catch {}
  }
  func testGenerationRoutesContextOnlyOverStdinAndHasNoTools() async throws {
    let mail = Mail(id: "one", sender: "Maya", senderEmail: "maya@example.com", subject: "Private subject", body: "Private email evidence")
    let prompt = try AIPrompt(intent: .write, instruction: "Private instruction", mails: [mail], draft: "Private draft", evidence: "Private calendar evidence")
    var generationArgs: [String] = []
    var generationInput = ""
    let connection = ClaudeConnection(runner: { args, input, _ in
      if args.contains("status") { return self.result(#"{"loggedIn":true,"authMethod":"claude.ai"}"#) }
      if args.contains("--input-format") {
        XCTAssertEqual(input, ClaudeConnection.modelRequest)
        return self.result(self.modelFixture)
      }
      generationArgs = args; generationInput = input ?? ""
      return self.result(#"{"type":"result","is_error":false,"result":"A helpful reply"}"#)
    })
    let suite = "claude-settings-" + UUID().uuidString
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let settings = AIProviderSettings(defaults: defaults, readSecret: { _ in XCTFail("Must not read API keys"); return nil }, claude: connection)
    settings.setModel("sonnet", provider: .claudeSubscription)
    settings.provider = .claudeSubscription
    try await connection.refresh()
    XCTAssertEqual(settings.writingProvider(chatGPTConnected: false), .claudeSubscription)
    let text = try await settings.complete(prompt)
    XCTAssertEqual(text, "A helpful reply")
    for privateText in ["Private instruction", "Private draft", "Private email evidence", "Private calendar evidence"] {
      XCTAssertTrue(generationInput.contains(privateText))
      XCTAssertFalse(generationArgs.joined().contains(privateText))
    }
    for flag in ["--safe-mode", "--no-session-persistence", "--strict-mcp-config", "--disable-slash-commands"] {
      XCTAssertTrue(generationArgs.contains(flag))
    }
    XCTAssertEqual(generationArgs[generationArgs.firstIndex(of: "--tools")! + 1], "")
    XCTAssertEqual(generationArgs[generationArgs.firstIndex(of: "--model")! + 1], "sonnet")
    XCTAssertEqual(generationArgs[generationArgs.firstIndex(of: "--mcp-config")! + 1], #"{"mcpServers":{}}"#)
    let models = try await settings.models(.claudeSubscription)
    XCTAssertTrue(models.contains("claude-opus-5-5[1m]")); XCTAssertTrue(models.contains("claude-sonnet-5"))
    XCTAssertEqual(settings.modelCatalog.models[.claudeSubscription], models)
    XCTAssertEqual(connection.modelLabel("sonnet"), "Automatic · Claude Sonnet 5")
    XCTAssertEqual(connection.modelLabel("claude-sonnet-5"), "Claude Sonnet 5")
    try await connection.logout()
    XCTAssertFalse(settings.availableProviders(chatGPTConnected: false).contains(.claudeSubscription))
  }
  func testConnectionCheckDuringGenerationPreservesSignedInProvider() async throws {
    var resume: CheckedContinuation<Void, Never>?
    let connection = ClaudeConnection(runner: { args, _, _ in
      if args.contains("status") { return self.result(#"{"loggedIn":true,"authMethod":"claude.ai"}"#) }
      await withCheckedContinuation { resume = $0 }
      return self.result(#"{"is_error":false,"result":"OK"}"#)
    })
    let request = Task { try await connection.complete(model: "sonnet", prompt: AIPrompt(intent: .answer, instruction: "Hello", mails: [])) }
    for _ in 0..<100 where resume == nil { try await Task.sleep(for: .milliseconds(5)) }
    guard let finish = resume else { request.cancel(); return XCTFail("Generation did not start") }
    do { try await connection.refresh(); XCTFail("Expected busy feedback") } catch {}
    XCTAssertTrue(connection.connected, "A busy helper must not silently remove the selected provider")
    finish.resume()
    let answer = try await request.value
    XCTAssertEqual(answer, "OK")
  }
  func testDefaultModelAndInvalidModelValidation() throws {
    let prompt = try AIPrompt(intent: .answer, instruction: "Hello", mails: [])
    XCTAssertFalse(try ClaudeConnection.arguments(model: "default", prompt: prompt).contains("--model"))
    for model in ["", "--system-prompt", "bad\nmodel", String(repeating: "x", count: 201)] {
      XCTAssertThrowsError(try ClaudeConnection.arguments(model: model, prompt: prompt))
    }
  }
  func testFailedEmptyAndMalformedRepliesNeverBecomeSuccessOrLeakOutput() async throws {
    for output in [#"{"is_error":true,"result":"sensitive provider content"}"#, #"{"is_error":false,"result":" "}"#, "sensitive provider content"] {
      let connection = ClaudeConnection(runner: { args, _, _ in
        args.contains("status") ? self.result(#"{"loggedIn":true,"authMethod":"claude.ai"}"#) : self.result(output)
      })
      do {
        _ = try await connection.complete(model: "sonnet", prompt: AIPrompt(intent: .answer, instruction: "Hello", mails: []))
        XCTFail("Expected actionable failure")
      } catch {
        XCTAssertFalse(error.localizedDescription.contains("sensitive provider content"))
        XCTAssertFalse(error is CancellationError)
      }
    }
  }
  func testHelperReadsLargeInputAndCancellationAndTimeoutFinish() async throws {
    let directory = FileManager.default.temporaryDirectory
    let payload = String(repeating: "abc", count: 30_000)
    let result = try await ClaudeProcess().run(executable: "/bin/cat", arguments: [], directory: directory,
      environment: [:], input: payload, timeout: .seconds(5))
    XCTAssertEqual(String(decoding: result.output, as: UTF8.self), payload)
    for cancel in [false, true] {
      let request = Task { @MainActor in
        try await ClaudeProcess().run(executable: "/bin/sleep", arguments: ["10"], directory: directory,
          environment: [:], input: payload, timeout: .milliseconds(100))
      }
      if cancel { try await Task.sleep(for: .milliseconds(40)); request.cancel() }
      do { _ = try await request.value; XCTFail("Must finish with an error") }
      catch { XCTAssertEqual(error is CancellationError, cancel) }
    }
  }
  func testIntegrationsLayoutOffscreen() async throws {
    _ = NSApplication.shared
    DesignAssets.registerFonts()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let database = try Database(url: directory.appendingPathComponent("sample.sqlite"))
    let store = try AppStore(database: database, accountEmail: "alex@example.com", gmail: GmailClient(),
      gmailTokenProvider: { XCTFail("No live Gmail"); return "test" }, syncClock: Date.init)
    store.isSample = true
    let suite = "claude-render-" + UUID().uuidString
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let connection = ClaudeConnection(executable: "/fixture/claude", runner: { args, _, _ in
      self.result(args.contains("--input-format") ? self.modelFixture : #"{"loggedIn":true,"authMethod":"claude.ai"}"#)
    })
    let settings = AIProviderSettings(defaults: defaults, claude: connection)
    for width in [1100.0, 760.0, 620.0] {
      let host = NSHostingView(rootView: IntegrationsView(store: store, settings: settings, initialProvider: .claudeSubscription))
      let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 1400), styleMask: [.borderless], backing: .buffered, defer: false)
      window.isReleasedWhenClosed = false; window.contentView = host
      for _ in 0..<8 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(30)) }
      XCTAssertFalse(window.isVisible)
      XCTAssertEqual(host.bounds.width, width, accuracy: 1)
      let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
      host.cacheDisplay(in: host.bounds, to: bitmap)
      try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        .write(to: URL(fileURLWithPath: "/tmp/cove-claude-integrations-\(Int(width)).png"))
      window.close()
    }
  }
  func testRealConnectedAccountModelDiscovery() async throws {
    guard ProcessInfo.processInfo.environment["COVE_TEST_CLAUDE_ACCOUNT"] == "1" else {
      throw XCTSkip("Opt-in account model metadata check; no inference")
    }
    let connection = ClaudeConnection()
    let models = try await connection.models()
    XCTAssertTrue(connection.connected)
    XCTAssertTrue(models.contains { $0.hasPrefix("claude-") })
    print("Claude model metadata: " + connection.modelOptions.map(\.label).joined(separator: ", "))
  }
  func testRealInstalledCLIUnauthenticatedStatusInIsolatedSandbox() async throws {
    guard ProcessInfo.processInfo.environment["COVE_TEST_CLAUDE_CLI"] == "1" else {
      throw XCTSkip("Opt-in official Claude Code CLI compatibility check")
    }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("cove-claude-probe-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let connection = ClaudeConnection(runtimeDirectory: directory,
      executable: FileManager.default.homeDirectoryForCurrentUser.path + "/.local/bin/claude")
    try await connection.refresh()
    XCTAssertFalse(connection.connected)
    let binary = URL(fileURLWithPath: connection.executablePath).resolvingSymlinksInPath().path
    let profile = try ClaudeSandbox.profile(runtime: directory.path, executable: binary)
    let discovery = try await ClaudeProcess().run(executable: "/usr/bin/sandbox-exec",
      arguments: ["-p", profile, binary] + ClaudeConnection.modelArguments, directory: directory,
      environment: ["HOME": FileManager.default.homeDirectoryForCurrentUser.path,
                    "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "CLAUDE_CONFIG_DIR": directory.path,
                    "TMPDIR": directory.appendingPathComponent("tmp").path,
                    "CLAUDE_CODE_TMPDIR": directory.appendingPathComponent("tmp").path,
                    "DISABLE_AUTOUPDATER": "1", "DISABLE_TELEMETRY": "1", "DISABLE_ERROR_REPORTING": "1"],
      input: ClaudeConnection.modelRequest, timeout: .seconds(30))
    let options = try ClaudeModelOption.parse(discovery.output)
    XCTAssertTrue(options.contains { $0.id.hasPrefix("claude-") && $0.resolvedID != nil })
    let args = try ClaudeConnection.arguments(model: "sonnet", prompt: AIPrompt(intent: .answer, instruction: "Reply OK", mails: []))
    let result = try await ClaudeProcess().run(executable: "/usr/bin/sandbox-exec",
      arguments: ["-p", profile, binary] + args, directory: directory,
      environment: ["HOME": FileManager.default.homeDirectoryForCurrentUser.path,
                    "PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "CLAUDE_CONFIG_DIR": directory.path,
                    "TMPDIR": directory.appendingPathComponent("tmp").path,
                    "CLAUDE_CODE_TMPDIR": directory.appendingPathComponent("tmp").path,
                    "DISABLE_AUTOUPDATER": "1", "DISABLE_TELEMETRY": "1", "DISABLE_ERROR_REPORTING": "1"],
      input: "Reply OK", timeout: .seconds(30), captureDiagnostics: true)
    let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: result.output) as? [String: Any])
    XCTAssertEqual(json["is_error"] as? Bool, true, "An isolated, signed-out CLI cannot generate")
    XCTAssertNotEqual(result.code, 0)
    let message = json["result"] as? String ?? ""
    XCTAssertTrue(message.lowercased().contains("log") || message.lowercased().contains("auth"), "Expected authentication rejection after valid flags")
  }
}
