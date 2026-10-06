import CryptoKit
import Foundation

private struct VerificationError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private enum VerificationMode: String {
    case distribution, signed, published
}

private struct OriginalRelease {
    let root: URL
    var app: URL { root.appendingPathComponent("dist/Release/StretchBreak.app") }
    var manifest: URL { root.appendingPathComponent("dist/SHA256SUMS.txt") }
    var sourcePlist: URL { root.appendingPathComponent("Resources/Info.plist") }
    var sparkleLicense: URL { root.appendingPathComponent(".build/artifacts/sparkle/Sparkle/LICENSE") }
}

private struct ReleaseVerification {
    let mode: VerificationMode
    let version: String
    let original: OriginalRelease
    let assets: URL

    private let files = FileManager.default
    private var appArchive: String { "StretchBreak-\(version)-arm64.zip" }
    private var sourceArchive: String { "StretchBreak-\(version)-source.zip" }
    private var updateArchive: String { "StretchBreak-\(version)-update.zip" }
    private var sourceItems: [String] {
        let required = [
            "Package.swift", "Package.resolved", "README.md", "LICENSE", ".gitignore",
            ".github", "Sources", "Tests", "Scripts", "Resources", "Docs", "Previews"
        ]
        return required + (files.fileExists(atPath: original.root.appendingPathComponent("CONTEXT.md").path) ? ["CONTEXT.md"] : [])
    }

    func verify() throws {
        let hasFeed = files.fileExists(atPath: assets.appendingPathComponent("appcast.xml").path)
        try require(mode == .distribution || hasFeed, "This verification requires appcast.xml.")
        try verifyManifest(hasFeed: hasFeed)
        if hasFeed { try verifyUpdate() }

        // No archive is extracted until its bytes and any required update signature are checked.
        print("Authenticated release assets; extracting archives.")
        let temporary = files.temporaryDirectory.appendingPathComponent("StretchBreak-verification-\(UUID().uuidString)")
        try files.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: temporary) }
        try verifyPortableApp(in: temporary.appendingPathComponent("portable"))
        try verifySource(in: temporary.appendingPathComponent("source"))
        try verifyUpdateApp(in: temporary.appendingPathComponent("update"))
        print("Verified \(mode.rawValue) release assets for \(version).")
    }

    private func verifyManifest(hasFeed: Bool) throws {
        let manifest = assets.appendingPathComponent("SHA256SUMS.txt")
        let data = try Data(contentsOf: manifest)
        guard let text = String(data: data, encoding: .utf8) else {
            throw VerificationError(message: "The checksum manifest is not UTF-8.")
        }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let records = lines.last == "" ? lines.dropLast() : lines[...]
        let expected = [appArchive, sourceArchive, updateArchive] + (hasFeed ? ["appcast.xml"] : [])
        var checksums: [(String, String)] = []
        for record in records {
            let fields = record.split(whereSeparator: { $0 == " " || $0 == "\t" })
            try require(fields.count == 2, "Invalid checksum manifest record.")
            let checksum = String(fields[0])
            let name = String(fields[1])
            try require(checksum.count == 64 && checksum.allSatisfy { $0.isASCII && $0.isHexDigit },
                        "Invalid SHA-256 checksum in the manifest.")
            checksums.append((name, checksum.lowercased()))
        }
        try require(checksums.map { $0.0 } == expected, "Unexpected asset inventory in the checksum manifest.")
        if mode == .published {
            try require(data == Data(contentsOf: original.manifest), "The published manifest differs from the original release manifest.")
        }
        for (name, checksum) in checksums {
            let archive = try Data(contentsOf: assets.appendingPathComponent(name), options: .mappedIfSafe)
            let actual = SHA256.hash(data: archive).map { String(format: "%02x", $0) }.joined()
            try require(actual == checksum, "SHA-256 checksum mismatch for \(name).")
        }
    }

    private func verifyUpdate() throws {
        let plist = try readPlist(original.app.appendingPathComponent("Contents/Info.plist"))
        let source = try readPlist(original.sourcePlist)
        try require(plist["CFBundleVersion"] as? String == version, "The app version does not match the feed.")
        let feedURL = "https://github.com/tomaskubat/stretch-break/releases/latest/download/appcast.xml"
        try require(plist["SUFeedURL"] as? String == feedURL, "Unexpected update feed URL.")
        try require(plist["SUVerifyUpdateBeforeExtraction"] as? Bool == true, "Archive verification must be enabled.")
        guard let encodedKey = plist["SUPublicEDKey"] as? String, let keyData = Data(base64Encoded: encodedKey) else {
            throw VerificationError(message: "Missing update public key.")
        }
        try require(source["SUPublicEDKey"] as? String == encodedKey, "The packaged public key differs from the source.")
        let key = try Curve25519.Signing.PublicKey(rawRepresentation: keyData)
        let feed = try XMLDocument(contentsOf: assets.appendingPathComponent("appcast.xml"))
        let items = try feed.nodes(forXPath: "/rss/channel/item")
        try require(items.count == 1, "Expected one current release in the appcast.")
        let item = items[0]
        let feedVersion = try item.nodes(forXPath: "*[local-name()='version']").first?.stringValue
        try require(feedVersion == version, "The feed points to another version.")
        let minimumOS = try item.nodes(forXPath: "*[local-name()='minimumSystemVersion']").first?.stringValue
        try require(minimumOS?.compare("14.0", options: .numeric) == .orderedSame, "Unexpected minimum macOS version.")
        let hardware = try item.nodes(forXPath: "*[local-name()='hardwareRequirements']").first?.stringValue
        try require(hardware == "arm64", "The update must require Apple Silicon.")
        let enclosures = try item.nodes(forXPath: "enclosure")
        guard enclosures.count == 1, let enclosure = enclosures.first as? XMLElement,
              let signatureString = enclosure.attributes?.first(where: { $0.localName == "edSignature" })?.stringValue,
              let signature = Data(base64Encoded: signatureString) else {
            throw VerificationError(message: "Missing update signature.")
        }
        let downloadURL = "https://github.com/tomaskubat/stretch-break/releases/download/v\(version)/\(updateArchive)"
        try require(enclosure.attribute(forName: "url")?.stringValue == downloadURL, "Unexpected update download URL.")
        let archive = try Data(contentsOf: assets.appendingPathComponent(updateArchive), options: .mappedIfSafe)
        try require(enclosure.attribute(forName: "length")?.stringValue == String(archive.count), "Incorrect archive length.")
        try require(key.isValidSignature(signature, for: archive), "The update signature does not match the app's public key.")
    }

    private func verifyPortableApp(in directory: URL) throws {
        let entries = try run("/usr/bin/zipinfo", ["-1", assets.appendingPathComponent(appArchive).path])
        try require(!entries.split(separator: "\n").contains { $0.hasSuffix(".sqlite") }, "The distribution contains a database.")
        try extract(appArchive, to: directory)
        let portable = directory.appendingPathComponent("StretchBreak")
        let app = portable.appendingPathComponent("StretchBreak.app")
        try verifyApp(app)
        let guide = try String(contentsOf: portable.appendingPathComponent("Install.md"), encoding: .utf8)
        try require(guide.split(separator: "\n").first == "# StretchBreak \(version) pro Apple Silicon", "Unexpected installation guide version.")
        try compare(original.root.appendingPathComponent("LICENSE"), portable.appendingPathComponent("LICENSE"))
    }

    private func verifySource(in directory: URL) throws {
        try extract(sourceArchive, to: directory)
        let source = directory.appendingPathComponent("StretchBreak-source")
        try require(Set(files.contentsOfDirectory(atPath: source.path)) == Set(sourceItems), "Unexpected source archive contents.")
        for item in sourceItems {
            try compare(original.root.appendingPathComponent(item), source.appendingPathComponent(item))
        }
    }

    private func verifyUpdateApp(in directory: URL) throws {
        try extract(updateArchive, to: directory)
        try require(files.contentsOfDirectory(atPath: directory.path) == ["StretchBreak.app"], "The update archive must contain only StretchBreak.app.")
        try verifyApp(directory.appendingPathComponent("StretchBreak.app"))
    }

    private func verifyApp(_ app: URL) throws {
        try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
        let executable = app.appendingPathComponent("Contents/MacOS/StretchBreak")
        let architecture = try run("/usr/bin/lipo", ["-archs", executable.path]).trimmingCharacters(in: .whitespacesAndNewlines)
        try require(architecture == "arm64", "The application executable must be arm64.")
        let plistURL = app.appendingPathComponent("Contents/Info.plist")
        let plist = try readPlist(plistURL)
        try require(plist["CFBundleIdentifier"] as? String == "local.stretchbreak.app", "Unexpected application bundle identifier.")
        try require(plist["CFBundleShortVersionString"] as? String == version && plist["CFBundleVersion"] as? String == version,
                    "The application version does not match the release.")
        try require(plist["LSMinimumSystemVersion"] as? String == "14.0", "Unexpected application minimum macOS version.")
        try require(plist["StretchBreakUITestDataDirectory"] == nil, "The distribution contains a UI test configuration.")
        try verifyDependencies(executable)
        try compare(original.sparkleLicense, app.appendingPathComponent("Contents/Resources/Sparkle-LICENSE.txt"))
        try require(files.fileExists(atPath: app.appendingPathComponent("Contents/Frameworks/Sparkle.framework").path),
                    "The application is missing Sparkle.framework.")
        try compare(original.app, app)
    }

    private func verifyDependencies(_ executable: URL) throws {
        let dependencies = try run("/usr/bin/otool", ["-L", executable.path]).split(separator: "\n").dropFirst()
        for dependency in dependencies {
            guard let path = dependency.split(whereSeparator: { $0.isWhitespace }).first else { continue }
            try require(path.hasPrefix("/System/Library/") || path.hasPrefix("/usr/lib/") ||
                        path == "@rpath/Sparkle.framework/Versions/B/Sparkle", "Unexpected dependency: \(path)")
        }
        let commands = try run("/usr/bin/otool", ["-l", executable.path])
        let paths = commands.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.hasPrefix("path ") }
        try require(paths.contains { $0.hasPrefix("path @executable_path/../Frameworks ") }, "Missing bundled-framework search path.")
        try require(!paths.contains { $0.hasPrefix("path /Applications/") || $0.hasPrefix("path /Users/") },
                    "The executable contains a development search path.")
    }

    private func extract(_ name: String, to directory: URL) throws {
        try run("/usr/bin/ditto", ["-x", "-k", assets.appendingPathComponent(name).path, directory.path])
    }

    private func compare(_ expected: URL, _ candidate: URL) throws {
        try run("/usr/bin/diff", ["-qr", expected.path, candidate.path])
    }
}

private func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw VerificationError(message: message) }
}

private func readPlist(_ url: URL) throws -> [String: Any] {
    let data = try Data(contentsOf: url)
    guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
        throw VerificationError(message: "Expected a property-list dictionary at \(url.path).")
    }
    return plist
}

@discardableResult
private func run(_ executable: String, _ arguments: [String]) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    let output = Pipe()
    process.standardOutput = output
    process.standardError = output
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    let text = String(decoding: data, as: UTF8.self)
    try require(process.terminationStatus == 0, "\(URL(fileURLWithPath: executable).lastPathComponent) failed: \(text.trimmingCharacters(in: .whitespacesAndNewlines))")
    return text
}

do {
    let arguments = CommandLine.arguments
    try require(arguments.count == 5, "Expected mode, version, original release root, and candidate asset directory.")
    guard let mode = VerificationMode(rawValue: arguments[1]) else {
        throw VerificationError(message: "Expected distribution, signed, or published verification mode.")
    }
    let version = arguments[2]
    try require(version.range(of: "^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$", options: .regularExpression) != nil,
                "Expected an X.Y.Z release version.")
    try ReleaseVerification(mode: mode, version: version,
                            original: OriginalRelease(root: URL(fileURLWithPath: arguments[3], isDirectory: true)),
                            assets: URL(fileURLWithPath: arguments[4], isDirectory: true)).verify()
} catch {
    FileHandle.standardError.write(Data("Release verification failed: \(error.localizedDescription)\n".utf8))
    exit(1)
}
