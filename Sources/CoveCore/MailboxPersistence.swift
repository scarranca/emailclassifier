import Foundation

extension Database {
  /// Reads the original snapshot format, then applies small edits saved since the last sync.
  public func loadMail() throws -> [Mail] {
    var mails = try load([Mail].self, key: "mail") ?? []
    var positions: [String: Int] = [:]
    for (index, mail) in mails.enumerated() { positions[mail.id] = index }
    for mail in try loadRecords(Mail.self, prefix: "mailOverride:") {
      if let index = positions[mail.id] {
        mails[index] = mail
      } else {
        positions[mail.id] = mails.count
        mails.append(mail)
      }
    }
    return mails
  }

  /// Avoids serializing the entire mailbox for an individual draft, label, or AI decision edit.
  public func saveMessage(_ mail: Mail) throws {
    try save(mail, key: "mailOverride:" + mail.id)
  }

  /// Consolidates edits and advances synchronization state atomically.
  public func saveMailSnapshot(
    _ mails: [Mail], historyID: String? = nil,
    nextPage: String? = nil, updatesPagination: Bool = false, decodingVersion: Int? = nil
  ) throws {
    try transaction {
      try save(mails, key: "mail")
      try deleteRecords(prefix: "mailOverride:")
      if let historyID { try save(historyID, key: "gmailHistoryID") }
      if updatesPagination { try save(nextPage ?? "", key: "gmailNextPage") }
      if let decodingVersion { try save(decodingVersion, key: "mailDecodingVersion") }
    }
  }
}
