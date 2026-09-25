import CoveCore
import Foundation

enum BundledGoogleOAuth {
  static var configuration: GoogleOAuthConfiguration {
    GoogleOAuthConfiguration(
      clientID: Bundle.main.object(forInfoDictionaryKey: "CoveGoogleClientID") as? String ?? "",
      clientSecret: Bundle.main.object(forInfoDictionaryKey: "CoveGoogleClientSecret") as? String
        ?? "")
  }
}
