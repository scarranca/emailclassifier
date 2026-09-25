import Foundation

extension GmailClient {
  /// Fetch only sender identities, never signatures or SMTP configuration.
  public func sendingAddresses(token: String) async throws -> [String] {
    struct Alias: Decodable {
      var sendAsEmail: String
      var isPrimary: Bool?
      var verificationStatus: String?
    }
    struct Response: Decodable { var sendAs: [Alias] }
    let result = try JSONDecoder().decode(Response.self, from: await request(
      "settings/sendAs", token: token,
      query: [URLQueryItem(name: "fields", value: "sendAs(sendAsEmail,isPrimary,verificationStatus)")]))
    var seen = Set<String>()
    return result.sendAs.compactMap { alias in
      let address = alias.sendAsEmail
      guard alias.isPrimary == true || alias.verificationStatus == "accepted",
        address.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
        address.rangeOfCharacter(from: .controlCharacters) == nil,
        !address.contains(","), !address.contains("<"), !address.contains(">"),
        address.split(separator: "@", omittingEmptySubsequences: false).count == 2,
        address.split(separator: "@").count == 2,
        seen.insert(address.lowercased()).inserted
      else { return nil }
      return address
    }
  }
}
