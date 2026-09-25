import Foundation

/// Local mailbox evidence for Home. These counts never claim to cover unsynced Gmail.
public struct MailTide: Sendable {
  public struct Day: Identifiable, Sendable {
    public let date: Date
    public let count: Int
    public var id: Date { date }
  }
  public let days: [Day]
  public let received: [Mail]
  public var total: Int { received.count }

  public init(mails: [Mail], now: Date, calendar: Calendar = .current) {
    let today = calendar.startOfDay(for: now)
    let dates = (-6...0).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    let start = dates.first ?? today
    var seen = Set<String>()
    received = mails.filter {
      $0.date >= start && $0.date <= now
        && $0.labels.isDisjoint(with: ["SENT", "DRAFT", "SPAM", "TRASH"])
        && seen.insert($0.id).inserted
    }
    let counts = Dictionary(grouping: received) { calendar.startOfDay(for: $0.date) }
    days = dates.map { Day(date: $0, count: counts[$0]?.count ?? 0) }
  }
}

public enum HomeBriefing {
  /// A sent thread with no later received message is a possible follow-up, not an inferred promise.
  public static func awaitingReplies(mails: [Mail], accountEmail: String, now: Date) -> [Mail] {
    let own = ContactDirectory.normalizedEmail(accountEmail)
    let valid = mails.filter {
      !$0.threadID.isEmpty && $0.date <= now
        && $0.labels.isDisjoint(with: ["TRASH", "SPAM", "DRAFT"])
    }
    return Dictionary(grouping: valid, by: \.threadID).values.compactMap { thread in
      guard let latest = thread.max(by: { $0.date < $1.date }),
            latest.labels.contains("SENT"), latest.date <= now.addingTimeInterval(-86400),
            now.timeIntervalSince(latest.date) <= 30 * 86400,
            ContactDirectory.addresses(latest.to).contains(where: { $0.email != own })
      else { return nil }
      return latest
    }.sorted { $0.date < $1.date }
  }

  public static func recipientNames(_ mail: Mail) -> String {
    ContactDirectory.addresses(mail.to).map { $0.name.isEmpty ? $0.email : $0.name }.joined(separator: ", ")
  }
}
