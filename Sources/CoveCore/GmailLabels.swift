import Foundation

public struct GmailLabel: Codable, Identifiable, Equatable, Sendable {
  public var id: String
  public var name: String
  public var type: String?
  public init(id: String, name: String, type: String? = "user") {
    self.id = id; self.name = name; self.type = type
  }
  public var title: String { name.split(separator: "/").last.map { $0.trimmingCharacters(in: .whitespaces) } ?? name }
  public var parent: String? {
    guard let slash = name.lastIndex(of: "/") else { return nil }
    return String(name[..<slash]).trimmingCharacters(in: .whitespaces)
  }
}
extension GmailClient {
  public func labels(token: String) async throws -> [GmailLabel] {
    struct List: Decodable { var labels: [GmailLabel]? }
    return try JSONDecoder().decode(List.self, from: await request("labels", token: token)).labels ?? []
  }
  public func ensureUserLabel(named name: String, token: String) async throws -> GmailLabel {
    func existing(_ labels: [GmailLabel]) throws -> GmailLabel? {
      guard let label = labels.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { return nil }
      guard label.type == "user" else { throw CoveError.message("Choose a custom Gmail label, not a system label.") }
      return label
    }
    if let found = try existing(await labels(token: token)) { return found }
    do {
      let label = try JSONDecoder().decode(GmailLabel.self, from: await request("labels", token: token, method: "POST",
        body: ["name": name, "labelListVisibility": "labelShow", "messageListVisibility": "show"]))
      guard !label.id.isEmpty, label.type == "user" else { throw CoveError.message("Gmail did not return a custom label.") }
      return label
    } catch let error as HTTPFailure where error.statusCode == 409 {
      if let found = try existing(await labels(token: token)) { return found }
      throw error
    }
  }
}
