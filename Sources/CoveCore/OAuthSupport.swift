import CryptoKit
import Foundation

public enum OAuthResponse: Equatable {
  case code(String)
  case denied
}
public enum OAuthSupport {
  public static func challenge(for verifier: String) -> String {
    Data(SHA256.hash(data: Data(verifier.utf8))).base64URL
  }
  /// Invalid callbacks do not terminate the pending sign-in session.
  public static func response(request: String, expectedState: String) -> OAuthResponse? {
    guard !expectedState.isEmpty, let firstLine = request.components(separatedBy: "\r\n").first
    else { return nil }
    let parts = firstLine.split(separator: " ")
    guard parts.count == 3, parts[0] == "GET", parts[1].hasPrefix("/oauth/callback?"),
      let url = URLComponents(string: "http://localhost\(parts[1])"), url.path == "/oauth/callback"
    else { return nil }
    let items = url.queryItems ?? []
    guard items.filter({ $0.name == "state" }).count == 1,
      items.first(where: { $0.name == "state" })?.value == expectedState
    else { return nil }
    if items.contains(where: { $0.name == "error" }) { return .denied }
    guard items.filter({ $0.name == "code" }).count == 1,
      let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty
    else { return nil }
    return .code(code)
  }
}
