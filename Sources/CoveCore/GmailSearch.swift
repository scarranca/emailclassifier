import Foundation

extension GmailClient {
  /// Explicit, bounded Gmail search. This does not mark messages read or advance sync cursors.
  public func search(query: String, token: String, limit: Int = 20) async throws -> [Mail] {
    let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty, query.utf8.count <= 2_000 else {
      throw CoveError.message("Enter a Gmail search of up to 2,000 bytes.")
    }
    let limit = min(20, max(1, limit))
    struct Entry: Decodable { let id: String }
    struct Results: Decodable { let messages: [Entry]? }
    let response = try await request("messages", token: token, query: [
      URLQueryItem(name: "q", value: "(\(query)) -in:trash -in:spam -in:drafts"),
      URLQueryItem(name: "maxResults", value: String(limit)),
      URLQueryItem(name: "includeSpamTrash", value: "false"),
    ])
    let entries = try JSONDecoder().decode(Results.self, from: response).messages ?? []
    var found: [Mail] = []
    var seen = Set<String>()
    for entry in entries.prefix(limit) where seen.insert(entry.id).inserted {
      try Task.checkCancellation()
      if let mail = try await message(id: entry.id, token: token),
        mail.labels.isDisjoint(with: ["TRASH", "SPAM", "DRAFT"])
      {
        found.append(mail)
      }
    }
    return found.sorted { $0.date > $1.date }
  }
}
