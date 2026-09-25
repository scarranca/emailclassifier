import Darwin
import Foundation

/// Outer Seatbelt boundary for the subscription helper, independent of Codex's tool policy.
public enum ChatGPTSandbox {
  public static func profile(runtime: String, executable: String, keychain: String? = nil) throws
    -> String
  {
    func quoted(_ value: String) throws -> String {
      guard value.hasPrefix("/"), !value.contains(where: { $0 == "\n" || $0 == "\r" || $0 == "\0" })
      else { throw CoveError.message("Invalid ChatGPT helper path.") }
      return "\""
        + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(
          of: "\"", with: "\\\"") + "\""
    }
    func canonical(_ path: String) throws -> String {
      _ = try quoted(path)
      guard let resolved = realpath(path, nil) else {
        throw CoveError.message("ChatGPT helper path does not exist.")
      }
      defer { free(resolved) }
      return String(cString: resolved)
    }
    let root = try quoted(canonical(runtime))
    let binary = try quoted(canonical(executable))
    var keychainAccess = ""
    if let keychain {
      let path = try canonical(keychain)
      let directory = URL(fileURLWithPath: path).deletingLastPathComponent().path
      func pattern(_ value: String) -> String {
        "\""
          + value.replacingOccurrences(of: "\\", with: "\\\\")
          .replacingOccurrences(of: "\"", with: "\\\"") + "\""
      }
      // Security.framework rewrites the encrypted database atomically and uses .fl locks.
      // Permit that one keychain and its bookkeeping, never the whole Keychains directory.
      let atomic = pattern(
        "^" + NSRegularExpression.escapedPattern(for: path) + "\\.sb-[A-Za-z0-9-]+$")
      let lock = pattern(
        "^" + NSRegularExpression.escapedPattern(for: directory) + "/\\.fl[0-9A-Fa-f]+$")
      keychainAccess =
        "(allow file-read* file-write* (literal \(try quoted(path))) (regex \(atomic)) (regex \(lock)))"
    }
    return """
      (version 1)
      (allow default)
      (deny file-read* file-write*)
      (allow file-read-metadata)
      (allow file-read* (literal "/") (literal "/var") (literal "/tmp") (literal "/etc") (subpath "/System/Library") (subpath "/System/Cryptexes") (subpath "/usr/lib") (subpath "/usr/bin") (subpath "/usr/libexec") (subpath "/usr/share") (subpath "/bin") (subpath "/sbin") (subpath "/dev") (subpath "/Library/Apple") (subpath "/private/var/db/timezone") (literal "/private/etc/hosts") (literal "/private/etc/resolv.conf") (literal "/private/etc/localtime") (literal \(binary)) (subpath \(root)))
      (allow file-write* (subpath \(root)) (literal "/dev/null"))
      \(keychainAccess)
      """
  }
}
