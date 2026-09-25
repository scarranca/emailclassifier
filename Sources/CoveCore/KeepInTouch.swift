import Foundation

/// Conservative suggestions for personal follow-up, separate from the full contact directory.
public enum KeepInTouch {
  public static func hasBulkOrAutomatedHeaders(
    listID: String, listUnsubscribe: String, autoSubmitted: String, precedence: String
  ) -> Bool {
    func normalized(_ value: String) -> String {
      value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    let auto = normalized(autoSubmitted).split(separator: ";").first.map(String.init) ?? ""
    let priority = normalized(precedence).split(separator: ";").first.map(String.init) ?? ""
    return !normalized(listID).isEmpty || !normalized(listUnsubscribe).isEmpty
      || (!auto.isEmpty && auto.trimmingCharacters(in: .whitespaces) != "no")
      || ["bulk", "list", "junk", "auto_reply"].contains(
        priority.trimmingCharacters(in: .whitespaces))
  }

  public static func isPersonalCorrespondence(_ mail: Mail) -> Bool {
    guard ContactDirectory.isValidEmail(mail.senderEmail),
      mail.isBulkOrAutomated == false,
      mail.labels.isDisjoint(with: [
        "TRASH", "SPAM", "DRAFT", "SENT", "CATEGORY_PROMOTIONS", "CATEGORY_UPDATES",
        "CATEGORY_SOCIAL", "CATEGORY_FORUMS",
      ]),
      let decision = mail.decision,
      [.people, .work].contains(decision.category),
      (0.7...1).contains(decision.confidence)
    else { return false }

    let local =
      ContactDirectory.normalizedEmail(mail.senderEmail).split(separator: "@").first
      .map(String.init) ?? ""
    let words = local.split { !$0.isLetter && !$0.isNumber }.map(String.init)
    let automatedNames: Set<String> = [
      "noreply", "donotreply", "notification", "notifications", "newsletter", "newsletters",
      "marketing", "updates", "automated", "mailerdaemon", "postmaster",
    ]
    let compact = words.joined()
    return !words.contains(where: automatedNames.contains)
      && !["noreply", "donotreply", "mailerdaemon"].contains(where: compact.hasPrefix)
  }

  public static func candidates(mails: [Mail], accountEmail: String, now: Date, ignored: Set<String> = []) -> [Mail] {
    let excluded = Set(ignored.map(ContactDirectory.normalizedEmail))
    let own = ContactDirectory.normalizedEmail(accountEmail)
    var latest: [String: Mail] = [:]
    for mail in mails
    where mail.date <= now
      && mail.labels.isDisjoint(with: ["TRASH", "SPAM", "DRAFT", "SENT"])
    {
      let email = ContactDirectory.normalizedEmail(mail.senderEmail)
      guard email != own, !excluded.contains(email), ContactDirectory.isValidEmail(email) else { continue }
      if latest[email] == nil || latest[email]!.date < mail.date { latest[email] = mail }
    }
    return latest.values.filter(isPersonalCorrespondence).sorted {
      if $0.date == $1.date { return $0.senderEmail < $1.senderEmail }
      return $0.date < $1.date
    }
  }
}
