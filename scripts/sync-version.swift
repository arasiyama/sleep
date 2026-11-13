import Foundation

// Stamps a version into an Info.plist.
// Usage: swift scripts/sync-version.swift [--source-only] [version] <plist>
//   <plist>          Info.plist to stamp (use a copy for builds; the repo's
//                    Resources/Info.plist keeps the __QSNIP_VERSION__ placeholder)
//   [version]        explicit semver; when omitted, parse Sources/Version.swift
//   --source-only    with [version]: also rewrite Sources/Version.swift (release flow)

let args = Array(CommandLine.arguments.dropFirst())
let scriptPath = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let root = scriptPath.deletingLastPathComponent().deletingLastPathComponent()
let versionFile = root.appendingPathComponent("Sources/Version.swift")

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("sync-version: \(message)\n".utf8))
    exit(1)
}

func read(_ url: URL) -> String {
    guard let text = try? String(contentsOf: url, encoding: .utf8) else {
        fail("cannot read \(url.path)")
    }
    return text
}

func write(_ url: URL, _ text: String) {
    do {
        try text.write(to: url, atomically: true, encoding: .utf8)
    } catch {
        fail("cannot write \(url.path): \(error)")
    }
}

func sourceVersion() -> String {
    let pattern = #/static let current = "([^"]+)"/#
    guard let match = read(versionFile).firstMatch(of: pattern) else {
        fail("version not found in \(versionFile.path)")
    }
    return String(match.1)
}

var sourceOnly = false
var positional: [String] = []
for arg in args {
    if arg == "--source-only" { sourceOnly = true } else { positional.append(arg) }
}

guard let plistArg = positional.last else {
    fail("usage: swift scripts/sync-version.swift [--source-only] [version] <plist>")
}
let plistFile = URL(fileURLWithPath: plistArg)
let explicitVersion = positional.count > 1 ? positional[0] : nil

let semver = #/^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$/#
let version: String
if let explicit = explicitVersion {
    guard explicit.wholeMatch(of: semver) != nil else {
        fail("'\(explicit)' is not a valid semver")
    }
    version = explicit
    if sourceOnly {
        let updated = read(versionFile).replacing(
            #/static let current = "[^"]+"/#,
            with: "static let current = \"\(version)\""
        )
        write(versionFile, updated)
    }
} else {
    version = sourceVersion()
}

write(plistFile, read(plistFile).replacingOccurrences(of: "__QSNIP_VERSION__", with: version))
print("sync-version: stamped \(version) into \(plistFile.lastPathComponent)")

