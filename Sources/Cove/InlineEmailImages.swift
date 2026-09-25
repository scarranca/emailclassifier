import CoveCore
import Foundation

extension AppStore {
  /// Inline MIME images come from the already connected mailbox, not sender-hosted URLs.
  /// Keep decoded data in the reader's lifetime rather than inflating persisted snapshots.
  func inlineEmailImages(for mail: Mail) async -> [String: String] {
    let account = accountEmail
    let sample = isSample
    let images = mail.availableAttachments.filter {
      $0.contentID != nil
        && ["image/png", "image/jpeg", "image/gif", "image/webp"]
          .contains($0.mimeType.lowercased())
        && ($0.byteCount ?? 0) <= 5_000_000
    }
    guard !images.isEmpty else { return [:] }
    var sources: [String: String] = [:]
    var totalBytes = 0
    do {
      let needsToken = !sample && images.contains { $0.data == nil }
      let token = needsToken ? try await auth.token() : ""
      for attachment in images.prefix(20) {
        try Task.checkCancellation()
        guard let contentID = attachment.contentID else { continue }
        do {
          let data = try await GmailClient().attachmentData(
            messageID: mail.id, attachment: attachment, token: token)
          totalBytes += data.count
          guard totalBytes <= 10_000_000 else { break }
          sources[contentID] =
            "data:\(attachment.mimeType.lowercased());base64,\(data.base64EncodedString())"
        } catch {
          if Task.isCancelled { return [:] }
        }
      }
    } catch { return [:] }
    guard !Task.isCancelled, entered, accountEmail == account, isSample == sample else {
      return [:]
    }
    return sources
  }
}
