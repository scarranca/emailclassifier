import Foundation

/// Desktop OAuth identifiers are public application configuration, never user credentials.
public struct GoogleOAuthConfiguration: Equatable {
  public let clientID: String
  public let clientSecret: String

  public init(clientID: String = "", clientSecret: String = "") {
    self.clientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
    self.clientSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  public var isConfigured: Bool {
    clientID.range(
      of: #"^[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$"#, options: .regularExpression) != nil
  }

  public static func selected(
    customClientID: String?, customSecret: String?, bundled: GoogleOAuthConfiguration
  ) -> GoogleOAuthConfiguration {
    let custom = GoogleOAuthConfiguration(
      clientID: customClientID ?? "", clientSecret: customSecret ?? "")
    // Never attach a previous custom client's secret to a bundled client.
    return custom.clientID.isEmpty ? bundled : custom
  }
}
