import Foundation

/// Public model metadata from the official CLI initialize response. Never account/auth data.
public struct ClaudeModelOption: Equatable, Sendable {
  public let id: String
  public let name: String
  public let resolvedID: String?
  public var label: String { id == "default" ? "Automatic · \(name)" : name }

  public static func parse(_ data: Data) throws -> [ClaudeModelOption] {
    for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
      guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
            object["type"] as? String == "control_response",
            let response = object["response"] as? [String: Any],
            response["request_id"] as? String == "cove-models",
            response["subtype"] as? String == "success",
            let payload = response["response"] as? [String: Any],
            let rows = payload["models"] as? [[String: Any]] else { continue }
      var seen = Set<String>()
      let result = rows.prefix(100).compactMap { row -> ClaudeModelOption? in
        guard let value = row["value"] as? String, validID(value) else { return nil }
        let resolved = (row["resolvedModel"] as? String).flatMap { validID($0) ? $0 : nil }
        // Pin explicit choices to the version reported by this installation. Only Automatic floats.
        let id = value == "default" ? value : resolved ?? value
        guard seen.insert(id).inserted else { return nil }
        let name = resolved.map(displayName) ?? (value == "default" ? "Account default" : displayName(value) + " · automatic version")
        return .init(id: id, name: name, resolvedID: resolved)
      }
      if !result.isEmpty { return result }
    }
    throw CoveError.message("Couldn’t load Claude’s model versions. Refresh the list or update Claude Code in connection options.")
  }

  public static func validID(_ value: String) -> Bool {
    !value.isEmpty && value.count <= 200 && !value.hasPrefix("-")
      && value.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.[]:").contains($0) }
  }
  public static func displayName(_ id: String) -> String {
    guard id.hasPrefix("claude-") else { return id }
    let context = id.hasSuffix("[1m]") ? " · 1M context" : ""
    let pieces = id.replacingOccurrences(of: "[1m]", with: "").dropFirst(7).split(separator: "-")
    guard let family = pieces.first else { return id }
    let versions = pieces.dropFirst().filter { $0.count < 8 }
    return "Claude " + family.capitalized + (versions.isEmpty ? "" : " " + versions.joined(separator: ".")) + context
  }
}
