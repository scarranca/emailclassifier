import Foundation

extension GmailClient {
  /// Retrieves bytes only. Saving or opening the file remains an explicit app action.
  public func attachmentData(messageID: String, attachment: MailAttachment, token: String)
    async throws -> Data
  {
    func decode(_ encoded: String, size: Int?) throws -> Data {
      guard let bytes = Data(base64URL: encoded),
        size == nil || size == bytes.count,
        attachment.byteCount == nil || attachment.byteCount == bytes.count
      else {
        throw CoveError.message(
          "The attachment data is incomplete or invalid. Try syncing this email again.")
      }
      return bytes
    }
    if let embedded = attachment.data,
      !embedded.isEmpty || attachment.attachmentID == nil
    {
      return try decode(embedded, size: attachment.byteCount)
    }
    guard let attachmentID = attachment.attachmentID, !attachmentID.isEmpty,
      !messageID.isEmpty
    else {
      throw CoveError.message(
        "This attachment has no downloadable data. Try syncing this email again.")
    }

    // Treat IDs as opaque path segments, never as a path or query supplied by a MIME part.
    let allowed = CharacterSet(
      charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
    guard let messagePath = messageID.addingPercentEncoding(withAllowedCharacters: allowed),
      let attachmentPath = attachmentID.addingPercentEncoding(withAllowedCharacters: allowed),
      ![".", ".."].contains(messageID), ![".", ".."].contains(attachmentID)
    else {
      throw CoveError.message("The attachment reference is invalid. Try syncing this email again.")
    }

    let response = try await request(
      "messages/\(messagePath)/attachments/\(attachmentPath)", token: token)
    struct AttachmentBody: Decodable {
      var data: String?
      var size: Int?
    }
    let body = try JSONDecoder().decode(AttachmentBody.self, from: response)
    guard let encoded = body.data else {
      throw CoveError.message("Gmail returned no attachment data. Please try again.")
    }
    return try decode(encoded, size: body.size)
  }
}
