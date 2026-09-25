import CryptoKit
import Foundation

/// Versioned authenticated records. Context prevents moving ciphertext between records/accounts.
struct RecordCipher {
  private let key: SymmetricKey
  private let namespace: String
  private static let prefix = Data("COVE-AESGCM-1\0".utf8)

  init(key: Data, namespace: String) throws {
    guard key.count == 32, !namespace.isEmpty else {
      throw CoveError.message("Invalid local mailbox encryption key.")
    }
    self.key = SymmetricKey(data: key)
    self.namespace = namespace
  }

  private func context(_ record: String) throws -> Data {
    try JSONEncoder().encode(["Cove record v1", namespace, record])
  }

  func seal(_ data: Data, record: String) throws -> Data {
    let box = try AES.GCM.seal(data, using: key, authenticating: context(record))
    guard let combined = box.combined else {
      throw CoveError.message("Could not encrypt the local mailbox.")
    }
    return Self.prefix + combined
  }

  func open(_ data: Data, record: String) throws -> Data {
    do {
      guard data.starts(with: Self.prefix) else { throw CryptoKitError.authenticationFailure }
      let box = try AES.GCM.SealedBox(combined: data.dropFirst(Self.prefix.count))
      return try AES.GCM.open(box, using: key, authenticating: context(record))
    } catch {
      throw CoveError.message(
        "The local mailbox could not be decrypted. Its key may be unavailable or its data damaged. Nothing has been reset."
      )
    }
  }
}
