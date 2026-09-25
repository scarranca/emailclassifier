import Foundation

enum CoveRuntime {
  // A separately signed QA bundle can be launched through Finder without command-line
  // flags while keeping sample storage and Keychain entries apart from the real app.
  static var isQA: Bool {
    ProcessInfo.processInfo.arguments.contains("--qa") || Bundle.main.bundleIdentifier == "ai.cove.qa"
  }
}
