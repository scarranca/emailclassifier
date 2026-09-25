import AppKit
import CoveCore
import SwiftUI
import XCTest
@testable import Cove

@MainActor final class AssistantModelPickerTests: XCTestCase {
  func testCatalogShowsAllReturnedModelsAndPreservesSavedAndSelectedChoices() async {
    let catalog = AssistantModelCatalog()
    await catalog.refresh(providers: [.chatGPT]) { provider in
      XCTAssertEqual(provider, .chatGPT)
      XCTAssertTrue(catalog.loading.contains(provider))
      return ["model-a", "model-b", " model-c ", "model-b", ""]
    }
    XCTAssertEqual(catalog.choices(provider: .chatGPT, saved: "model-a", selected: "custom-model").map(\.model),
                   ["model-a", "custom-model", "model-b", "model-c"])
    XCTAssertTrue(catalog.loading.isEmpty)
    XCTAssertTrue(catalog.errors.isEmpty)
  }

  func testFailureKeepsSavedChoiceAndRefreshRecovers() async {
    let catalog = AssistantModelCatalog()
    await catalog.refresh(providers: [.chatGPT]) { _ in throw CoveError.message("Connection unavailable") }
    XCTAssertNotNil(catalog.errors[.chatGPT])
    XCTAssertEqual(catalog.choices(provider: .chatGPT, saved: "saved", selected: nil).map(\.model), ["saved"])
    XCTAssertTrue(catalog.loading.isEmpty)
    await catalog.refresh(providers: [.chatGPT]) { _ in ["saved", "another"] }
    XCTAssertNil(catalog.errors[.chatGPT])
    XCTAssertEqual(catalog.choices(provider: .chatGPT, saved: "saved", selected: nil).count, 2)
  }

  func testOneProviderFailureDoesNotHideAnotherProviderModels() async {
    let catalog = AssistantModelCatalog()
    await catalog.refresh(providers: [.openAI, .chatGPT]) { provider in
      if provider == .openAI { throw CoveError.message("Unavailable") }
      return ["one", "two"]
    }
    XCTAssertEqual(catalog.models[.chatGPT], ["one", "two"])
    XCTAssertNotNil(catalog.errors[.openAI])
    await catalog.refresh(providers: [.chatGPT]) { _ in [] }
    XCTAssertNotNil(catalog.errors[.chatGPT], "An empty result needs visible feedback")
  }

  func testCancellationDoesNotReportProviderFailure() async {
    let catalog = AssistantModelCatalog()
    await catalog.refresh(providers: [.chatGPT]) { _ in throw CancellationError() }
    XCTAssertTrue(catalog.loading.isEmpty)
    XCTAssertTrue(catalog.errors.isEmpty)
  }

  func testConversationChoiceDoesNotChangeSavedDefaultsAndDisconnectedAccountFallsBack() throws {
    let suite = "cove-model-choice-" + UUID().uuidString
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let settings = AIProviderSettings(defaults: defaults, readSecret: { _ in XCTFail("No Keychain reads in model selection"); return nil })
    settings.provider = .chatGPT
    settings.setModel("model-a", provider: .chatGPT)
    let preferred = AssistantModelChoice(provider: .chatGPT, model: "model-b")
    XCTAssertEqual(settings.assistantChoice(preferred: preferred, chatGPTConnected: true), preferred)
    XCTAssertEqual(settings.model(.chatGPT), "model-a")
    XCTAssertEqual(settings.provider, .chatGPT)
    XCTAssertNil(settings.assistantChoice(preferred: preferred, chatGPTConnected: false))
    defaults.set(true, forKey: "ai.saved.openAI")
    settings.setModel("api-default", provider: .openAI)
    XCTAssertEqual(settings.assistantChoice(preferred: preferred, chatGPTConnected: false),
                   AssistantModelChoice(provider: .openAI, model: "api-default"))
  }

  func testSelectedModelReachesProviderRequestWithoutOverwritingDefault() async throws {
    let suite = "cove-model-request-" + UUID().uuidString
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let transport = PickerHTTP()
    let settings = AIProviderSettings(defaults: defaults, readSecret: { _ in "fixture" }, client: AIProviderClient(transport: transport))
    defaults.set(true, forKey: "ai.saved.openAI")
    settings.setModel("default-model", provider: .openAI)
    let choice = try XCTUnwrap(settings.assistantChoice(preferred: AssistantModelChoice(provider: .openAI, model: "chosen-model")))
    _ = try await settings.complete(AIPrompt(intent: .answer, instruction: "Synthetic check", mails: []), provider: choice.provider, model: choice.model)
    let selected = await transport.model
    XCTAssertEqual(selected, "chosen-model")
    XCTAssertEqual(settings.model(.openAI), "default-model")
  }

  func testSettingsDiscoveryPopulatesTheSameCatalogUsedByChat() async throws {
    let suite = "cove-model-shared-" + UUID().uuidString
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let settings = AIProviderSettings(defaults: defaults, readSecret: { _ in "fixture" },
      saveSecret: { _, _ in }, client: AIProviderClient(transport: PickerModelsHTTP()))
    settings.setModel("saved", provider: .openAI)
    let settingsList = try await settings.models(.openAI)
    let chatList = settings.modelCatalog.choices(provider: .openAI, saved: "saved", selected: nil).map(\.model)
    XCTAssertEqual(Set(settingsList), Set(chatList))
    XCTAssertEqual(chatList.count, 3)
    try settings.saveKey("replacement", provider: .openAI)
    XCTAssertNil(settings.modelCatalog.models[.openAI], "Changing credentials invalidates the account's catalog")
  }

  func testClosingAndReopeningPickerSharesDiscoveryInsteadOfLosingItsResult() async throws {
    let catalog = AssistantModelCatalog()
    var requests = 0
    let first = Task { await catalog.refresh(providers: [.chatGPT]) { _ in
      requests += 1
      try await Task.sleep(for: .milliseconds(120))
      return ["saved", "second", "third"]
    } }
    try await Task.sleep(for: .milliseconds(20))
    first.cancel()
    await catalog.refresh(providers: [.chatGPT]) { _ in XCTFail("Reopening should reuse the in-flight request"); return [] }
    await first.value
    XCTAssertEqual(requests, 1)
    XCTAssertEqual(catalog.models[.chatGPT], ["saved", "second", "third"])
    XCTAssertTrue(catalog.loading.isEmpty)
  }

  func testDisconnectDiscardsInFlightCatalog() async throws {
    let catalog = AssistantModelCatalog()
    let first = Task { await catalog.refresh(providers: [.chatGPT]) { _ in
      try? await Task.sleep(for: .milliseconds(100))
      return ["old-account-model"]
    } }
    try await Task.sleep(for: .milliseconds(20))
    catalog.clear(.chatGPT)
    await first.value
    XCTAssertNil(catalog.models[.chatGPT])
    XCTAssertTrue(catalog.loading.isEmpty)
  }

  func testPickerLoadsWhenConnectionBecomesAvailableAfterItAppears() async throws {
    _ = NSApplication.shared
    let suite = "cove-model-late-" + UUID().uuidString
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let settings = AIProviderSettings(defaults: defaults, saveSecret: { _, _ in })
    settings.setModel("saved", provider: .openAI)
    var requests = 0
    let host = NSHostingView(rootView: AssistantModelPicker(settings: settings, selected: nil, useAI: true,
      choose: { _ in }, choosePassages: {}, manage: {}, fetchModels: { _ in
        requests += 1
        return ["saved", "another", "third"]
      }))
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 475), styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = host
    defer { window.close() }
    for _ in 0..<5 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(30)) }
    XCTAssertEqual(requests, 0)
    try settings.saveKey("fixture", provider: .openAI)
    for _ in 0..<10 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(30)) }
    XCTAssertEqual(requests, 1, "Restoring a connection must trigger discovery without pressing Refresh")
    XCTAssertFalse(window.isVisible)
  }

  func testNaturalPopoverSizeReservesRoomForAsynchronouslyLoadedModels() async throws {
    _ = NSApplication.shared
    let suite = "cove-model-size-" + UUID().uuidString
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(true, forKey: "ai.saved.openAI")
    let settings = AIProviderSettings(defaults: defaults)
    settings.setModel("saved", provider: .openAI)
    let host = NSHostingView(rootView: AssistantModelPicker(settings: settings, selected: nil, useAI: true,
      choose: { _ in }, choosePassages: {}, manage: {}, fetchModels: { _ in
        try await Task.sleep(for: .milliseconds(250))
        return ["saved", "another", "third", "fourth"]
      }))
    let initialSize = host.fittingSize
    XCTAssertGreaterThan(initialSize.height, 400, "A popover must not size its scroll region to just the saved model")
    XCTAssertLessThan(initialSize.height, 550)
  }

  func testPickerRendersLongModelListOffscreenWithoutAccessingCredentials() async throws {
    _ = NSApplication.shared
    DesignAssets.registerFonts()
    let suite = "cove-model-render-" + UUID().uuidString
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(true, forKey: "ai.saved.openAI")
    let settings = AIProviderSettings(defaults: defaults, readSecret: { _ in XCTFail("No live request during rendering"); return nil })
    settings.setModel("fixture-model-1", provider: .openAI)
    let view = AssistantModelPicker(settings: settings, selected: AssistantModelChoice(provider: .openAI, model: "fixture-model-2"), useAI: true,
      choose: { _ in }, choosePassages: {}, manage: {}, fetchModels: { _ in (1...25).map { "fixture-model-\($0)" } })
    let host = NSHostingView(rootView: view)
    let window = NSWindow(contentRect: NSRect(origin: .zero, size: host.fittingSize), styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false; window.contentView = host
    defer { window.close() }
    for _ in 0..<8 { host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(30)) }
    XCTAssertFalse(window.isVisible)
    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
    host.cacheDisplay(in: host.bounds, to: bitmap)
    try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: "/tmp/cove-model-picker.png"))
  }
}

private actor PickerHTTP: HTTPTransport {
  var model: String?
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let body = try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any]
    model = body?["model"] as? String
    return (Data(#"{"output":[{"type":"message","content":[{"type":"output_text","text":"OK"}]}]}"#.utf8),
      try XCTUnwrap(HTTPURLResponse(url: XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)))
  }
}

private struct PickerModelsHTTP: HTTPTransport {
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    XCTAssertEqual(request.httpMethod, "GET")
    return (Data(#"{"data":[{"id":"saved"},{"id":"second"},{"id":"third"}]}"#.utf8),
      try XCTUnwrap(HTTPURLResponse(url: XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)))
  }
}
