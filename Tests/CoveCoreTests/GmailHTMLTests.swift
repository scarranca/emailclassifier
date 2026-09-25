import XCTest

@testable import CoveCore

final class GmailHTMLTests: XCTestCase {
  private func mail(_ payload: [String: Any]) throws -> Mail {
    try JSONDecoder().decode(
      GmailMessage.self,
      from: JSONSerialization.data(withJSONObject: [
        "id": "html-message", "threadId": "thread", "snippet": "Preview only", "payload": payload,
      ])
    ).mail()
  }

  private func part(_ mime: String, _ text: String) -> [String: Any] {
    ["mimeType": mime, "body": ["data": Data(text.utf8).base64URL]]
  }

  func testPreservesHTMLFormattingAlongsidePlainTextAlternative() throws {
    let html = """
      <html><head><style>td { padding: 12px; }</style></head><body>
      <h1>Receipt</h1><table><tr><td><strong>Café</strong></td><td>€20</td></tr></table>
      <p><a href="https://example.com/receipt">View receipt</a></p></body></html>
      """
    let plain = "Receipt\nCafé: €20\nhttps://example.com/receipt"
    let result = try mail([
      "mimeType": "multipart/alternative",
      "parts": [part("text/plain", plain), part("text/html", html)],
    ])
    XCTAssertEqual(result.body, plain, "Search and Jev continue to receive the plain alternative")
    XCTAssertEqual(result.htmlBody, html, "The renderer receives the original decoded HTML")
  }

  func testHTMLOnlyMailPreservesMarkupAndReadablePlainFallback() throws {
    let html =
      "<style>p{color:red}</style><p>Hello <strong>Maya</strong> &amp; team.</p><p>Thank you.</p>"
    let result = try mail(part("text/html", html))
    XCTAssertEqual(result.htmlBody, html)
    XCTAssertEqual(result.body, "Hello Maya & team.\nThank you.")
  }

  func testPollutedPlainAlternativeUsesCorroboratedHTMLText() throws {
    let fragment =
      #"<span data-element="ph.offer" style="font-size:16px">Your monthly account update is ready.</span>"#
    let plain = "Hello,\n\(fragment)\nView your account."
    let html = "<html><body><p>Hello,</p><p>\(fragment)</p><p>View your account.</p></body></html>"
    let result = try mail([
      "mimeType": "multipart/alternative",
      "parts": [part("text/plain", plain), part("text/html", html)],
    ])
    XCTAssertEqual(result.body, "Hello,\nYour monthly account update is ready.\nView your account.")
    XCTAssertEqual(result.htmlBody, html)
    XCTAssertFalse(result.body.contains("<span"))
  }

  func testPlainComparisonsAndEscapedHTMLCodeExamplesRemainUnchanged() throws {
    let plain = #"If x < 5 && y > 2, render <span style="color:red">Warning</span> in the example."#
    let html =
      "<p>"
      + plain.replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
      + "</p>"
    let result = try mail([
      "mimeType": "multipart/alternative",
      "parts": [part("text/plain", plain), part("text/html", html)],
    ])
    XCTAssertEqual(result.body, plain)
    XCTAssertNil(GmailMessage.corroboratedHTMLText(plain, html: html))
    XCTAssertEqual(try mail(part("text/plain", plain)).body, plain)
  }

  func testUnrelatedHTMLDoesNotAuthorizeStrippingPlainMarkup() throws {
    let plain = #"Example: <span style="color:red">Sample text</span>"#
    let html = #"<p>A different message.</p><span style="color:blue">Sample text</span>"#
    let result = try mail([
      "mimeType": "multipart/alternative",
      "parts": [part("text/plain", plain), part("text/html", html)],
    ])
    XCTAssertEqual(result.body, plain)
  }

  func testCorroboratedFragmentRepairLeavesSurroundingPlainComparisonsIntact() {
    let fragment = #"<span data-element="update" style="font-weight:bold">Read this update.</span>"#
    let plain = "x < 5 && y > 2\n\(fragment)\nUse <T> for a generic type."
    XCTAssertEqual(
      GmailMessage.corroboratedHTMLText(plain, html: "<div>\(fragment)</div>"),
      "x < 5 && y > 2\nRead this update.\nUse <T> for a generic type.")
  }

  func testLegacySnapshotsWithoutHTMLStillDecodeAndNewHTMLRoundTrips() throws {
    var message = Samples.mail[0]
    var legacy = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(message)) as? [String: Any])
    legacy.removeValue(forKey: "htmlBody")
    let decoded = try JSONDecoder().decode(
      Mail.self, from: JSONSerialization.data(withJSONObject: legacy))
    XCTAssertNil(decoded.htmlBody)
    XCTAssertEqual(decoded.body, message.body)
    message.htmlBody = "<p>Original <strong>formatting</strong>.</p>"
    XCTAssertEqual(
      try JSONDecoder().decode(Mail.self, from: JSONEncoder().encode(message)), message)
  }

  func testAttachedHTMLNeverOverridesTheMessageBody() throws {
    let mainHTML = "<p>This is the actual <strong>email</strong>.</p>"
    for marker in [
      ["filename": "report.html"] as [String: Any],
      [
        "headers": [["name": "Content-Disposition", "value": " Attachment ; filename=report.html"]]
      ],
    ] {
      var attachment = part("text/html", "<p>This is an attached report.</p>")
      attachment.merge(marker) { _, new in new }
      let result = try mail([
        "mimeType": "multipart/mixed", "parts": [attachment, part("text/html", mainHTML)],
      ])
      XCTAssertEqual(result.htmlBody, mainHTML)
      XCTAssertEqual(result.body, "This is the actual email.")
      XCTAssertEqual(result.availableAttachments.count, 1)
    }
  }

  func testAttachedMIMESubtreeAndPlainDocumentAreExcludedFromBodySelection() throws {
    var textAttachment = part("text/plain", "Attached text must not replace the email")
    textAttachment["filename"] = "notes.txt"
    let attachedMIME: [String: Any] = [
      "mimeType": "multipart/alternative",
      "headers": [["name": "Content-Disposition", "value": "attachment"]],
      "parts": [part("text/html", "<p>Attached HTML subtree</p>")],
    ]
    let result = try mail([
      "mimeType": "multipart/mixed",
      "parts": [textAttachment, attachedMIME, part("text/plain", "Actual email body")],
    ])
    XCTAssertEqual(result.body, "Actual email body")
    XCTAssertNil(result.htmlBody)
    XCTAssertEqual(result.availableAttachments.count, 2)
  }
}
