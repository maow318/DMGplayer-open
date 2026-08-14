//
//  AppBundleMetadata.swift
//  DMGplayer
//

import Foundation

nonisolated struct AppBundleMetadata: Equatable, Sendable {
    var displayName: String
    var bundleIdentifier: String?
    var version: String?
    var minimumMacOS: String?
    var signatureValid: Bool?
    var teamIdentifier: String?
    var hardenedRuntime: Bool?

    static func plistMetadata(at applicationURL: URL) -> AppBundleMetadata {
        let plistURL = applicationURL.appending(path: "Contents/Info.plist")
        let dictionary = NSDictionary(contentsOf: plistURL) as? [String: Any] ?? [:]
        let displayName = (dictionary["CFBundleDisplayName"] as? String)
            ?? (dictionary["CFBundleName"] as? String)
            ?? applicationURL.deletingPathExtension().lastPathComponent
        let shortVersion = dictionary["CFBundleShortVersionString"] as? String
        let buildVersion = dictionary["CFBundleVersion"] as? String
        let version: String?
        if let shortVersion, let buildVersion, shortVersion != buildVersion {
            version = "\(shortVersion) (\(buildVersion))"
        } else {
            version = shortVersion ?? buildVersion
        }
        return AppBundleMetadata(
            displayName: displayName,
            bundleIdentifier: dictionary["CFBundleIdentifier"] as? String,
            version: version,
            minimumMacOS: dictionary["LSMinimumSystemVersion"] as? String,
            signatureValid: nil,
            teamIdentifier: nil,
            hardenedRuntime: nil
        )
    }

    static func inspect(at applicationURL: URL) async -> AppBundleMetadata {
        var metadata = plistMetadata(at: applicationURL)
        do {
            let verification = try await Shell.run(
                "/usr/bin/codesign",
                ["--verify", "--deep", "--strict", "--verbose=2", applicationURL.path]
            )
            metadata.signatureValid = verification.status == 0
            let details = try await Shell.run(
                "/usr/bin/codesign",
                ["-d", "--verbose=4", applicationURL.path]
            )
            let lines = details.output.split(separator: "\n").map(String.init)
            metadata.teamIdentifier = value(after: "TeamIdentifier=", in: lines)
            if metadata.teamIdentifier == "not set" { metadata.teamIdentifier = nil }
            let flags = value(after: "flags=", in: lines)?.lowercased() ?? ""
            metadata.hardenedRuntime = flags.contains("runtime")
        } catch {
            metadata.signatureValid = false
        }
        return metadata
    }

    private static func value(after prefix: String, in lines: [String]) -> String? {
        guard let line = lines.first(where: { $0.hasPrefix(prefix) }) else { return nil }
        return String(line.dropFirst(prefix.count))
    }
}
