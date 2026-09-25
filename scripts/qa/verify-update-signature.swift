// Independent Ed25519 verification with the public key; never reads Keychain.
import Foundation
import CryptoKit
let args = CommandLine.arguments
precondition(args.count == 4, "Usage: verify-update-signature FILE SIGNATURE PUBLIC_KEY")
let data = try Data(contentsOf: URL(fileURLWithPath: args[1]))
let signature = Data(base64Encoded: args[2])!
let key = try Curve25519.Signing.PublicKey(rawRepresentation: Data(base64Encoded: args[3])!)
guard key.isValidSignature(signature, for: data) else { print("Invalid signature"); exit(1) }
var corrupted = data
corrupted[corrupted.count / 2] ^= 1
precondition(!key.isValidSignature(signature, for: corrupted), "Tampered archive must be rejected")
print("Archive signature verified with bundled public key; tampering rejected.")
