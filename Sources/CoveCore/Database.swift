import CSQLite
import Darwin
import Foundation

/// A local SQLite store. Each account has a distinct database; secrets never enter it.
public final class Database {
  private var handle: OpaquePointer?
  private var cipher: RecordCipher?
  private static let keyCheck = "__cove_key_check"

  private static func storagePath(_ url: URL) throws -> String {
    // Foundation keeps /var aliases on macOS; SQLite NOFOLLOW needs real parent paths.
    guard let parent = realpath(url.deletingLastPathComponent().path, nil) else {
      throw CoveError.message("Could not resolve local mailbox storage.")
    }
    defer { free(parent) }
    return String(cString: parent) + "/" + url.lastPathComponent
  }

  public static func requiresEncryptionKey(at url: URL) throws -> Bool {
    guard FileManager.default.fileExists(atPath: url.path) else { return false }
    var connection: OpaquePointer?
    guard
      sqlite3_open_v2(
        try Self.storagePath(url), &connection, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOFOLLOW, nil)
        == SQLITE_OK
    else {
      if let connection { sqlite3_close(connection) }
      throw CoveError.message("Could not inspect the existing mailbox. Nothing has been reset.")
    }
    defer { sqlite3_close(connection) }
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(connection, "PRAGMA user_version", -1, &statement, nil) == SQLITE_OK
    else {
      throw CoveError.message("Could not inspect the existing mailbox.")
    }
    defer { sqlite3_finalize(statement) }
    guard sqlite3_step(statement) == SQLITE_ROW else {
      throw CoveError.message("Could not inspect the existing mailbox.")
    }
    return sqlite3_column_int(statement, 0) != 0
  }

  /// A nil key is reserved for synthetic fixtures. Encrypted stores never open without a key.
  public init(url: URL, encryptionKey: Data? = nil, namespace: String = "fixture") throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700])
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o700], ofItemAtPath: url.deletingLastPathComponent().path)
    for path in [url.path, url.path + "-wal", url.path + "-shm", url.path + "-journal"] {
      if let attributes = try? FileManager.default.attributesOfItem(atPath: path) {
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
          throw CoveError.message("Local mailbox storage must be a regular file.")
        }
        // Legacy sidecars retain their original mode when SQLite reuses them.
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
      }
    }
    guard
      sqlite3_open_v2(
        try Self.storagePath(url), &handle,
        SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_NOFOLLOW,
        nil) == SQLITE_OK
    else {
      if let handle { sqlite3_close(handle) }
      handle = nil
      throw CoveError.message("Could not open the local mailbox.")
    }
    do {
      sqlite3_busy_timeout(handle, 5000)
      try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
      try execute(
        "PRAGMA trusted_schema=OFF; PRAGMA secure_delete=ON; PRAGMA temp_store=MEMORY; PRAGMA synchronous=FULL;"
      )
      let version = try storageVersion()
      guard (0...2).contains(version) else {
        throw CoveError.message("This mailbox needs a newer version of Cove.")
      }
      if version > 0 && encryptionKey == nil {
        throw CoveError.message(
          "The encrypted mailbox requires its Keychain key. Nothing has been reset.")
      }
      try execute(
        "PRAGMA journal_mode=WAL; CREATE TABLE IF NOT EXISTS records (key TEXT PRIMARY KEY, value BLOB NOT NULL);"
      )
      if let encryptionKey {
        cipher = try RecordCipher(key: encryptionKey, namespace: namespace)
        if version == 0 {
          try transaction {
            // Read every old value before changing any. Migration commits all records or none.
            let old = try rawRecords(prefix: "")
            guard !old.contains(where: { $0.0 == Self.keyCheck }) else {
              throw CoveError.message(
                "Invalid mailbox encryption metadata. Nothing has been reset.")
            }
            for (key, data) in old {
              // Refuse corrupt legacy records rather than hiding corruption inside ciphertext.
              _ = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
              try writeRaw(try cipher!.seal(data, record: key), key: key)
            }
            try writeRaw(
              try cipher!.seal(Data("Cove key check v1".utf8), record: Self.keyCheck),
              key: Self.keyCheck)
            try execute("PRAGMA user_version=1")
          }
        }
        guard let check = try readRaw(key: Self.keyCheck),
          try cipher!.open(check, record: Self.keyCheck) == Data("Cove key check v1".utf8)
        else {
          throw CoveError.message("Missing mailbox encryption metadata. Nothing has been reset.")
        }
        if try storageVersion() == 1 {
          // Version 1 is encrypted but cleanup may have been interrupted. Retry on next open.
          try checkpoint()
          try execute("VACUUM")
          try checkpoint()
          try execute("PRAGMA user_version=2")
          try checkpoint()
        }
      }
    } catch {
      sqlite3_close(handle)
      handle = nil
      throw error
    }
  }

  private func storageVersion() throws -> Int32 {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(handle, "PRAGMA user_version", -1, &statement, nil) == SQLITE_OK else {
      throw CoveError.message("Could not inspect local mailbox storage.")
    }
    defer { sqlite3_finalize(statement) }
    guard sqlite3_step(statement) == SQLITE_ROW else {
      throw CoveError.message("Could not inspect local mailbox storage.")
    }
    return sqlite3_column_int(statement, 0)
  }

  private func checkpoint() throws {
    guard sqlite3_wal_checkpoint_v2(handle, nil, SQLITE_CHECKPOINT_TRUNCATE, nil, nil) == SQLITE_OK
    else {
      throw CoveError.message(
        "Close other Cove instances and reopen to finish protecting the mailbox.")
    }
  }

  /// Explicit user-requested reset. Retains only the key verifier, never user records.
  public func eraseContents() throws {
    try transaction {
      try execute("DELETE FROM records WHERE key != '__cove_key_check'")
    }
    try checkpoint()
    try execute("VACUUM")
    try checkpoint()
  }
  deinit { sqlite3_close(handle) }
  private func execute(_ sql: String) throws {
    guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else {
      throw CoveError.message("Local storage failed (\(sqlite3_errcode(handle))).")
    }
  }
  /// Groups related records into one durable change. A thrown error preserves the previous state.
  public func transaction<T>(_ operation: () throws -> T) throws -> T {
    try execute("BEGIN IMMEDIATE")
    do {
      let result = try operation()
      try execute("COMMIT")
      return result
    } catch {
      try? execute("ROLLBACK")
      throw error
    }
  }

  func loadRecords<T: Decodable>(_ type: T.Type, prefix: String) throws -> [T] {
    try rawRecords(prefix: prefix).filter { $0.0 != Self.keyCheck }.map { key, data in
      try JSONDecoder().decode(type, from: cipher?.open(data, record: key) ?? data)
    }
  }

  private func rawRecords(prefix: String) throws -> [(String, Data)] {
    var statement: OpaquePointer?
    guard
      sqlite3_prepare_v2(
        handle,
        "SELECT key,value FROM records WHERE substr(key,1,length(?))=? ORDER BY key", -1,
        &statement, nil) == SQLITE_OK
    else {
      throw CoveError.message("Could not read local storage.")
    }
    defer { sqlite3_finalize(statement) }
    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    sqlite3_bind_text(statement, 1, prefix, -1, transient)
    sqlite3_bind_text(statement, 2, prefix, -1, transient)
    var values: [(String, Data)] = []
    while true {
      let result = sqlite3_step(statement)
      if result == SQLITE_DONE { return values }
      guard result == SQLITE_ROW, let key = sqlite3_column_text(statement, 0),
        let bytes = sqlite3_column_blob(statement, 1)
      else {
        throw CoveError.message("Could not read the local mailbox.")
      }
      values.append(
        (String(cString: key), Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 1)))))
    }
  }

  func deleteRecords(prefix: String) throws {
    var statement: OpaquePointer?
    guard
      sqlite3_prepare_v2(
        handle, "DELETE FROM records WHERE substr(key,1,length(?))=?", -1, &statement, nil)
        == SQLITE_OK
    else { throw CoveError.message("Could not prepare local deletion.") }
    defer { sqlite3_finalize(statement) }
    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    sqlite3_bind_text(statement, 1, prefix, -1, transient)
    sqlite3_bind_text(statement, 2, prefix, -1, transient)
    guard sqlite3_step(statement) == SQLITE_DONE else {
      throw CoveError.message("Could not update the local mailbox.")
    }
  }
  public func save<T: Encodable>(_ value: T, key: String) throws {
    guard key != Self.keyCheck else { throw CoveError.message("Reserved mailbox record.") }
    let plain = try JSONEncoder().encode(value)
    let data = try cipher?.seal(plain, record: key) ?? plain
    try writeRaw(data, key: key)
  }

  private func writeRaw(_ data: Data, key: String) throws {
    var statement: OpaquePointer?
    guard
      sqlite3_prepare_v2(
        handle, "INSERT OR REPLACE INTO records(key,value) VALUES(?,?)", -1, &statement, nil)
        == SQLITE_OK
    else { throw CoveError.message("Could not prepare local save.") }
    defer { sqlite3_finalize(statement) }
    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    sqlite3_bind_text(statement, 1, key, -1, transient)
    _ = data.withUnsafeBytes {
      sqlite3_bind_blob(statement, 2, $0.baseAddress, Int32(data.count), transient)
    }
    guard sqlite3_step(statement) == SQLITE_DONE else {
      throw CoveError.message("Could not save the local mailbox.")
    }
  }
  public func load<T: Decodable>(_ type: T.Type, key: String) throws -> T? {
    guard key != Self.keyCheck else { throw CoveError.message("Reserved mailbox record.") }
    guard let data = try readRaw(key: key) else { return nil }
    return try JSONDecoder().decode(type, from: cipher?.open(data, record: key) ?? data)
  }

  private func readRaw(key: String) throws -> Data? {
    var statement: OpaquePointer?
    guard
      sqlite3_prepare_v2(handle, "SELECT value FROM records WHERE key=?", -1, &statement, nil)
        == SQLITE_OK
    else { throw CoveError.message("Could not read local storage.") }
    defer { sqlite3_finalize(statement) }
    sqlite3_bind_text(statement, 1, key, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    let result = sqlite3_step(statement)
    if result == SQLITE_DONE { return nil }
    guard result == SQLITE_ROW, let bytes = sqlite3_column_blob(statement, 0) else {
      throw CoveError.message("Could not read the local mailbox.")
    }
    return Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 0)))
  }
}
