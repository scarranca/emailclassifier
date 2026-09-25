import Foundation

public enum JevAutomation {
  /// A missing legacy cutoff starts now; upgrading must never opt historical mail into processing.
  public static func initialized(_ preferences: Preferences, at date: Date) -> Preferences {
    var preferences = preferences
    if preferences.autoClassify && preferences.autoClassifySince == nil {
      preferences.autoClassifySince = date
    }
    return preferences
  }

  public static func isEligible(_ mail: Mail, accountEmail: String, since cutoff: Date? = nil)
    -> Bool
  {
    guard !mail.id.hasPrefix("local-"), mail.decision == nil,
      mail.labels.isDisjoint(with: ["SENT", "DRAFT", "TRASH", "SPAM"]),
      mail.senderEmail.caseInsensitiveCompare(accountEmail) != .orderedSame
    else { return false }
    return cutoff.map { mail.date >= $0 } ?? true
  }

  public static func candidates(
    in mail: [Mail], accountEmail: String, since cutoff: Date? = nil,
    retryAfter: [String: Date] = [:], now: Date = Date()
  )
    -> [Mail]
  {
    mail.filter {
      isEligible($0, accountEmail: accountEmail, since: cutoff)
        && (retryAfter[$0.id] ?? .distantPast) <= now
    }
    .sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
  }
  public static func shouldStopBatch(after error: Error) -> Bool {
    if error is CancellationError || error is URLError { return true }
    if let failure = error as? HTTPFailure {
      return [401, 402, 403, 429].contains(failure.statusCode) || failure.statusCode >= 500
    }
    return false
  }
}
