import XCTest

@testable import CoveCore

final class GmailAttachmentTests: XCTestCase {
  func testNestedMIMEAttachmentsPreserveNamesAndBody() throws {
    let text = Data("Please review the attached launch checklist.".utf8)
    let fixture: [String: Any] = [
      "id": "message-1", "threadId": "thread-1",
      "payload": [
        "mimeType": "multipart/mixed",
        "parts": [
          ["mimeType": "text/plain", "filename": "", "body": ["data": text.base64URL]],
          [
            "mimeType": "multipart/mixed",
            "parts": [
              [
                "mimeType": "application/pdf", "filename": "Launch résumé.pdf",
                "body": ["attachmentId": "remote-1", "size": 24576],
              ],
              [
                "mimeType": "text/plain", "filename": "checklist.txt",
                "body": ["data": Data("Review mobile layout".utf8).base64URL, "size": 20],
              ],
              [
                "mimeType": "image/png", "filename": "logo.png",
                "headers": [["name": "Content-Disposition", "value": "inline"]],
                "body": ["attachmentId": "remote-2", "size": 150],
              ],
            ],
          ],
        ],
      ],
    ]
    let mail = try JSONDecoder().decode(
      GmailMessage.self, from: JSONSerialization.data(withJSONObject: fixture)
    ).mail()
    XCTAssertEqual(mail.body, String(decoding: text, as: UTF8.self))
    XCTAssertEqual(
      mail.availableAttachments.map(\.filename), ["Launch résumé.pdf", "checklist.txt", "logo.png"])
    XCTAssertEqual(mail.availableAttachments[0].byteCount, 24576)
    XCTAssertEqual(mail.availableAttachments[0].mimeType, "application/pdf")
    XCTAssertEqual(mail.availableAttachments[0].attachmentID, "remote-1")
    XCTAssertEqual(mail.availableAttachments[1].data, Data("Review mobile layout".utf8).base64URL)
    XCTAssertEqual(Set(mail.availableAttachments.map(\.id)).count, 3)
  }

  func testDownloadsAttachmentWithAuthorizedMessagePathAndBase64URL() async throws {
    let bytes = Data([0xfb, 0xff, 0x00, 0xfa, 0x10])
    let client = GmailClient(
      transport: MockHTTP { request in
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(
          request.url?.absoluteString,
          "https://gmail.googleapis.com/gmail/v1/users/me/messages/message-1/attachments/remote-1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
        return try JSONSerialization.data(withJSONObject: [
          "data": bytes.base64URL, "size": bytes.count,
        ])
      })
    // Gmail can include an empty data field when the bytes are held separately.
    let attachment = MailAttachment(
      id: "one", filename: "preview.bin", mimeType: "application/octet-stream",
      byteCount: bytes.count, attachmentID: "remote-1", data: "")
    let downloaded = try await client.attachmentData(
      messageID: "message-1", attachment: attachment, token: "test-token")
    XCTAssertEqual(downloaded, bytes)
  }

  func testEmbeddedSampleDownloadsWithoutNetworkIncludingZeroByteFile() async throws {
    let client = GmailClient(
      transport: MockHTTP { _ in
        XCTFail("Embedded attachments must not make a network request")
        return Data()
      })
    let sample = try XCTUnwrap(Samples.mail[0].availableAttachments.first)
    let content = try await client.attachmentData(
      messageID: "sample-0", attachment: sample, token: "")
    XCTAssertTrue(String(decoding: content, as: UTF8.self).contains("sign-off by 3 PM"))
    XCTAssertEqual(content.count, sample.byteCount)
    let empty = MailAttachment(
      id: "empty", filename: "empty.txt", mimeType: "text/plain", byteCount: 0, data: "")
    let downloadedEmpty = try await client.attachmentData(
      messageID: "sample-0", attachment: empty, token: "")
    XCTAssertTrue(downloadedEmpty.isEmpty)
  }

  func testOldMailSnapshotsDecodeWithoutAttachmentField() throws {
    var json = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(Samples.mail[0])) as? [String: Any])
    json.removeValue(forKey: "attachments")
    let mail = try JSONDecoder().decode(
      Mail.self, from: JSONSerialization.data(withJSONObject: json))
    XCTAssertNil(mail.attachments)
    XCTAssertTrue(mail.availableAttachments.isEmpty)
    let roundTrip = try JSONDecoder().decode(Mail.self, from: JSONEncoder().encode(Samples.mail[0]))
    XCTAssertEqual(roundTrip.availableAttachments, Samples.mail[0].availableAttachments)
  }

  func testInlineImagesWithoutFilenamesPreserveContentIDsAndBytes() throws {
    let bytes = Data([0x89, 0x50, 0x4E, 0x47])
    let html =
      "<p>Inline images</p><img src=\"cid:logo@example.com\"><img src=\"cid:chart@example.com\">"
    let fixture: [String: Any] = [
      "id": "inline-mail", "threadId": "thread",
      "payload": [
        "mimeType": "multipart/related",
        "parts": [
          [
            "mimeType": "text/html",
            "headers": [["name": "Content-ID", "value": "<body@example.com>"]],
            "body": ["data": Data(html.utf8).base64URL],
          ],
          [
            "mimeType": "image/png",
            "headers": [["name": "content-id", "value": " <logo@example.com> \r\n"]],
            "body": ["data": bytes.base64URL, "size": bytes.count],
          ],
          [
            "mimeType": "image/jpeg", "filename": "",
            "headers": [
              ["name": "Content-Disposition", "value": "inline"],
              ["name": "Content-ID", "value": "chart@example.com"],
            ],
            "body": ["attachmentId": "remote-image", "size": 2048],
          ],
          [
            "mimeType": "image/png",
            "headers": [["name": "Content-ID", "value": "<>"]],
            "body": ["data": bytes.base64URL],
          ],
        ],
      ],
    ]
    let mail = try JSONDecoder().decode(
      GmailMessage.self, from: JSONSerialization.data(withJSONObject: fixture)
    ).mail()
    XCTAssertEqual(mail.htmlBody, html, "The related HTML part is still the main body")
    XCTAssertEqual(mail.body, "Inline images")
    XCTAssertEqual(
      mail.availableAttachments.map(\.contentID), ["logo@example.com", "chart@example.com"])
    XCTAssertEqual(mail.availableAttachments[0].data, bytes.base64URL)
    XCTAssertEqual(mail.availableAttachments[0].filename, "Inline image")
    XCTAssertEqual(mail.availableAttachments[1].attachmentID, "remote-image")
    XCTAssertEqual(mail.availableAttachments[1].byteCount, 2048)
    XCTAssertEqual(try JSONDecoder().decode(Mail.self, from: JSONEncoder().encode(mail)), mail)
  }

  func testAttachmentSnapshotsWithoutContentIDRemainCompatible() throws {
    let attachment = MailAttachment(
      id: "old", filename: "logo.png", mimeType: "image/png", data: "iVBORw==",
      contentID: "logo@example.com")
    var legacy = try XCTUnwrap(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(attachment)) as? [String: Any])
    legacy.removeValue(forKey: "contentID")
    let decoded = try JSONDecoder().decode(
      MailAttachment.self, from: JSONSerialization.data(withJSONObject: legacy))
    XCTAssertNil(decoded.contentID)
    XCTAssertEqual(decoded.data, attachment.data)
    XCTAssertEqual(decoded.filename, attachment.filename)
  }

  func testInvalidMissingAndTruncatedDataFailClearly() async throws {
    let client = GmailClient(transport: MockHTTP { _ in Data("{}".utf8) })
    let fixtures = [
      MailAttachment(
        id: "bad", filename: "bad.bin", mimeType: "application/octet-stream", data: "not-base64?!"),
      MailAttachment(id: "missing", filename: "missing.bin", mimeType: "application/octet-stream"),
      MailAttachment(
        id: "truncated", filename: "short.bin", mimeType: "application/octet-stream", byteCount: 99,
        data: Data([1, 2]).base64URL),
      MailAttachment(
        id: "remote", filename: "remote.bin", mimeType: "application/octet-stream",
        attachmentID: "remote-1"),
    ]
    for attachment in fixtures {
      do {
        _ = try await client.attachmentData(
          messageID: "message-1", attachment: attachment, token: "test-token")
        XCTFail("Expected invalid or missing attachment data to fail")
      } catch {
        XCTAssertTrue(error.localizedDescription.lowercased().contains("attachment"))
        XCTAssertFalse(error.localizedDescription.contains("test-token"))
      }
    }
    let invalidRemote = GmailClient(
      transport: MockHTTP { _ in Data("{\"data\":\"invalid?!\",\"size\":7}".utf8) })
    do {
      _ = try await invalidRemote.attachmentData(
        messageID: "message-1", attachment: fixtures[3], token: "test-token")
      XCTFail("Expected invalid remote base64 to fail")
    } catch {
      XCTAssertTrue(error.localizedDescription.contains("invalid"))
    }
  }
}
