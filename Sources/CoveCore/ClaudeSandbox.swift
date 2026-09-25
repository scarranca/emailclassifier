import Foundation

/// Same filesystem boundary as the Codex helper, plus read-only Anthropic managed policy.
/// Claude fails closed if its administrator policy is unreadable, even when the file is absent.
public enum ClaudeSandbox {
  public static func profile(runtime: String, executable: String, keychain: String? = nil) throws -> String {
    try ChatGPTSandbox.profile(runtime: runtime, executable: executable, keychain: keychain)
      + "\n(allow file-read* (subpath \"/Library/Application Support/ClaudeCode\"))\n"
  }
}
