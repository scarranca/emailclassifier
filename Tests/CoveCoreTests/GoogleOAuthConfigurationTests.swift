import XCTest

@testable import CoveCore

final class GoogleOAuthConfigurationTests: XCTestCase {
  let bundled = GoogleOAuthConfiguration(
    clientID: "123-cove.apps.googleusercontent.com", clientSecret: "desktop-public-value")

  func testFreshInstallUsesBundledConfigurationWithoutMixingOldCustomSecret() {
    XCTAssertTrue(bundled.isConfigured)
    for custom: String? in [nil, "", "  \n"] {
      XCTAssertEqual(
        GoogleOAuthConfiguration.selected(
          customClientID: custom, customSecret: "stale", bundled: bundled), bundled)
    }
  }

  func testExistingCustomConfigurationRetainsItsOwnClientAndSecret() {
    let result = GoogleOAuthConfiguration.selected(
      customClientID: " 456-custom.apps.googleusercontent.com ", customSecret: " custom-value ",
      bundled: bundled)
    XCTAssertEqual(result.clientID, "456-custom.apps.googleusercontent.com")
    XCTAssertEqual(result.clientSecret, "custom-value")
    XCTAssertNotEqual(result.clientSecret, bundled.clientSecret)
  }

  func testInvalidCustomClientDoesNotSilentlySwitchToBundledIdentity() {
    for id in [
      "wrong", "bad\n.apps.googleusercontent.com", "https://123.apps.googleusercontent.com",
      "123.apps.googleusercontent.com.attacker.example",
    ] {
      XCTAssertFalse(
        GoogleOAuthConfiguration.selected(customClientID: id, customSecret: nil, bundled: bundled)
          .isConfigured)
    }
    XCTAssertFalse(GoogleOAuthConfiguration().isConfigured)
  }
}
