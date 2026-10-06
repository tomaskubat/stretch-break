import CryptoKit
import Foundation

// Disposable fixture keys stay in the test workspace and never use the Keychain.
let arguments = CommandLine.arguments
switch arguments.dropFirst().first {
case "key" where arguments.count == 4:
    let key = Curve25519.Signing.PrivateKey()
    try key.rawRepresentation.write(to: URL(fileURLWithPath: arguments[2]))
    try key.publicKey.rawRepresentation.base64EncodedString().write(toFile: arguments[3], atomically: true, encoding: .utf8)
case "sign" where arguments.count == 5:
    let key = try Curve25519.Signing.PrivateKey(rawRepresentation: Data(contentsOf: URL(fileURLWithPath: arguments[2])))
    let archive = try Data(contentsOf: URL(fileURLWithPath: arguments[3]), options: .mappedIfSafe)
    try key.signature(for: archive).base64EncodedString().write(toFile: arguments[4], atomically: true, encoding: .utf8)
default:
    FileHandle.standardError.write(Data("Expected key PRIVATE PUBLIC, or sign PRIVATE ARCHIVE SIGNATURE.\n".utf8))
    exit(1)
}
