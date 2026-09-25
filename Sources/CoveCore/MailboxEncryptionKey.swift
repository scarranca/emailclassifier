import CryptoKit
import Foundation

/// Key lifecycle separated from Keychain so failure paths can be tested without credentials.
public enum MailboxEncryptionKey {
  public static func load(
    existingEncryptedStore: Bool, read: () throws -> String?, write: (String) throws -> Void
  ) throws -> Data {
    if let saved = try read() {
      guard let data = Data(base64Encoded: saved), data.count == 32 else {
        throw CoveError.message("The mailbox encryption key is invalid. Nothing has been reset.")
      }
      return data
    }
    guard !existingEncryptedStore else {
      throw CoveError.message(
        "The mailbox encryption key is missing from Keychain. Restore its key before opening this mailbox. Nothing has been reset."
      )
    }
    let key = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
    try write(key.base64EncodedString())
    // The Keychain writer is insert-only. Another app instance may have won the race.
    guard let persisted = try read(), let stored = Data(base64Encoded: persisted),
      stored.count == 32
    else {
      throw CoveError.message(
        "The mailbox key could not be verified in Keychain. Nothing has been reset.")
    }
    return stored
  }
}
