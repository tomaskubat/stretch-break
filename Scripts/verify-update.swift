import CryptoKit
import Foundation

func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw NSError(domain: "StretchBreak.UpdateVerification", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
}

do {
    try require(CommandLine.arguments.count == 2, "Expected a release version.")
    let version = CommandLine.arguments[1]
    let archiveName = "StretchBreak-\(version)-update.zip"
    let plistData = try Data(contentsOf: URL(fileURLWithPath: "dist/Release/StretchBreak.app/Contents/Info.plist"))
    let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as! [String: Any]
    let sourceData = try Data(contentsOf: URL(fileURLWithPath: "Resources/Info.plist"))
    let source = try PropertyListSerialization.propertyList(from: sourceData, format: nil) as! [String: Any]
    try require(plist["CFBundleVersion"] as? String == version, "The app version does not match the feed.")
    let feedURL = "https://github.com/tomaskubat/stretch-break/releases/latest/download/appcast.xml"
    try require(plist["SUFeedURL"] as? String == feedURL, "Unexpected update feed URL.")
    try require(plist["SUVerifyUpdateBeforeExtraction"] as? Bool == true, "Archive verification must be enabled.")
    guard let encodedKey = plist["SUPublicEDKey"] as? String, let keyData = Data(base64Encoded: encodedKey) else {
        throw NSError(domain: "StretchBreak.UpdateVerification", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing update public key."])
    }
    try require(source["SUPublicEDKey"] as? String == encodedKey, "The packaged public key differs from the source.")
    let key = try Curve25519.Signing.PublicKey(rawRepresentation: keyData)
    let feed = try XMLDocument(contentsOf: URL(fileURLWithPath: "dist/appcast.xml"))
    let items = try feed.nodes(forXPath: "/rss/channel/item")
    try require(items.count == 1, "Expected one current release in the appcast.")
    let item = items[0]
    let feedVersion = try item.nodes(forXPath: "*[local-name()='version']").first?.stringValue
    try require(feedVersion == version, "The feed points to another version.")
    let minimumOS = try item.nodes(forXPath: "*[local-name()='minimumSystemVersion']").first?.stringValue
    try require(minimumOS?.compare("14.0", options: .numeric) == .orderedSame, "Unexpected minimum macOS version.")
    let hardware = try item.nodes(forXPath: "*[local-name()='hardwareRequirements']").first?.stringValue
    try require(hardware == "arm64", "The update must require Apple Silicon.")
    guard let enclosure = try item.nodes(forXPath: "enclosure").first as? XMLElement,
          let signatureString = enclosure.attributes?.first(where: { $0.localName == "edSignature" })?.stringValue,
          let signature = Data(base64Encoded: signatureString) else {
        throw NSError(domain: "StretchBreak.UpdateVerification", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing update signature."])
    }
    let downloadURL = "https://github.com/tomaskubat/stretch-break/releases/download/v\(version)/\(archiveName)"
    try require(enclosure.attribute(forName: "url")?.stringValue == downloadURL, "Unexpected update download URL.")
    let archive = try Data(contentsOf: URL(fileURLWithPath: "dist/\(archiveName)"), options: .mappedIfSafe)
    try require(enclosure.attribute(forName: "length")?.stringValue == String(archive.count), "Incorrect archive length.")
    try require(key.isValidSignature(signature, for: archive), "The update signature does not match the app's public key.")
    print("Verified version, platform, download URL, and Ed25519 signature for \(archiveName).")
} catch {
    fputs("Update verification failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
