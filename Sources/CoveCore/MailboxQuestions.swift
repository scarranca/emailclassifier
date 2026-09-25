import Foundation

public struct MailboxCountQuery: Equatable, Sendable {
  public let labelID: String?
  public let unreadOnly: Bool
  public let location: String

  public func count(in mail: [Mail]) -> Int {
    mail.filter { message in
      (labelID == nil || message.labels.contains(labelID!))
        && (!unreadOnly || message.labels.contains("UNREAD"))
    }.count
  }

  public func sentence(count: Int) -> String {
    "\(count.formatted()) \(unreadOnly ? "unread " : "")\(count == 1 ? "message" : "messages") \(location)."
  }
}

public enum MailboxQuestion: Equatable, Sendable {
  case count(MailboxCountQuery)
  case unsupportedCount

  /// Routes mailbox statistics before source-passage Q&A. Unsupported filters must not be ignored.
  public static func parse(_ question: String) -> MailboxQuestion? {
    let text = question.lowercased().replacingOccurrences(of: "e-mails", with: "emails")
    let counting =
      text.contains("how many") || text.contains("count")
      || text.contains("number of") || text.contains("do i have")
    let mailboxSubject =
      text.contains("unread") || text.contains("inbox")
      || text.contains("drafts") || text.contains("starred")
      || text.range(
        of: #"(?:how many|count(?: of)?|number of)\s+(?:total\s+)?(?:emails?|messages?)\b"#,
        options: .regularExpression) != nil
    guard counting, mailboxSubject else { return nil }
    if text.rangeOfCharacter(from: .decimalDigits) != nil || text.contains(" and ") {
      return .unsupportedCount
    }
    // A count with extra constraints must not quietly become a whole-mailbox total.
    let allowedWords = Set(
      "how many count counts number of do i have can you tell me show give what s is are there the my all total emails email messages message mail gmail mailbox in unread inbox draft drafts sent starred trash spam please currently now and"
        .split(separator: " ").map(String.init))
    let words = text.components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty }
    guard words.allSatisfy(allowedWords.contains) else { return .unsupportedCount }
    let unsupported =
      #"\b(from|since|before|after|today|yesterday|week|month|year|older|newer|about|subject|attachment|attachments|unanswered|read)\b|["“”]"#
    if text.range(of: unsupported, options: .regularExpression) != nil {
      return .unsupportedCount
    }
    let unread = text.contains("unread")
    let scopes = ["inbox", "draft", "sent", "starred", "trash", "spam"].filter { text.contains($0) }
    guard scopes.count <= 1 else { return .unsupportedCount }
    if text.contains("inbox") {
      return .count(
        MailboxCountQuery(labelID: "INBOX", unreadOnly: unread, location: "in your inbox"))
    }
    let folders = [
      ("draft", "DRAFT", "in Gmail Drafts"), ("sent", "SENT", "in Gmail Sent"),
      ("starred", "STARRED", "in Gmail Starred"), ("trash", "TRASH", "in Gmail Trash"),
      ("spam", "SPAM", "in Gmail Spam"),
    ]
    for (word, label, location) in folders where text.contains(word) {
      return .count(MailboxCountQuery(labelID: label, unreadOnly: unread, location: location))
    }
    return .count(
      MailboxCountQuery(
        labelID: unread ? "UNREAD" : nil, unreadOnly: unread,
        location: unread ? "in Gmail’s Unread label" : "in your Gmail mailbox"))
  }
}

public struct MailboxAnswer: Sendable {
  public let text: String
  public let source: String
  public init(text: String, source: String) {
    self.text = text
    self.source = source
  }
}

extension GmailClient {
  /// Counts messages using Gmail's label/profile statistics, independent of downloaded pages.
  public func mailboxCount(_ query: MailboxCountQuery, token: String) async throws -> Int {
    struct Statistics: Decodable {
      let messagesTotal: Int?
      let messagesUnread: Int?
    }
    let statistics = try JSONDecoder().decode(
      Statistics.self,
      from: await request(query.labelID.map { "labels/\($0)" } ?? "profile", token: token))
    let value =
      query.unreadOnly && query.labelID != "UNREAD"
      ? statistics.messagesUnread : statistics.messagesTotal
    guard let value, value >= 0 else {
      throw CoveError.message("Gmail did not return a message count. Please try again.")
    }
    return value
  }
}
