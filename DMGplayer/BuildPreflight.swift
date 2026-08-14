//
//  BuildPreflight.swift
//  DMGplayer
//
//  GUI 与未来 CLI 共用的构建前检查。纯规则与系统探测集中在这里，
//  不依赖 SwiftUI，也不持有界面状态。
//

import Foundation
import ImageIO

nonisolated enum PreflightSeverity: Int, Codable, CaseIterable, Sendable {
    case error
    case warning
    case passed

    var title: String {
        switch self {
        case .error: "错误"
        case .warning: "警告"
        case .passed: "通过"
        }
    }
}

nonisolated struct PreflightResult: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let severity: PreflightSeverity
    let title: String
    let detail: String
}

nonisolated struct PreflightReport: Equatable, Sendable {
    let results: [PreflightResult]

    static let empty = PreflightReport(results: [])

    var errors: [PreflightResult] { results.filter { $0.severity == .error } }
    var warnings: [PreflightResult] { results.filter { $0.severity == .warning } }
    var passed: [PreflightResult] { results.filter { $0.severity == .passed } }
    var canBuild: Bool { errors.isEmpty }

    var summary: String {
        if !errors.isEmpty { "发现 \(errors.count) 个错误" }
        else if !warnings.isEmpty { "通过，另有 \(warnings.count) 个警告" }
        else if results.isEmpty { "尚未检查" }
        else { "全部检查通过" }
    }

    var summaryResource: LocalizedStringResource {
        if !errors.isEmpty { "发现 \(errors.count) 个错误" }
        else if !warnings.isEmpty { "通过，另有 \(warnings.count) 个警告" }
        else if results.isEmpty { "尚未检查" }
        else { "全部检查通过" }
    }
}

nonisolated enum BuildPreflight {
    static func run(
        project: DMGProject,
        destination: URL?,
        encryptionPassword: String
    ) async -> PreflightReport {
        var results = validateProject(
            project,
            destination: destination,
            encryptionPassword: encryptionPassword
        )

        let appURLs = project.items.compactMap { item -> URL? in
            guard item.kind == .file,
                  item.name.lowercased().hasSuffix(".app"),
                  FileManager.default.fileExists(atPath: item.sourcePath)
            else { return nil }
            return URL(fileURLWithPath: item.sourcePath)
        }

        async let signingResults = inspectSigning(project: project, applications: appURLs)
        async let mountedVolumeResults = inspectMountedVolumes(volumeName: project.volumeName)
        async let storageResults = inspectStorage(project: project, destination: destination)

        results += await signingResults
        results += await mountedVolumeResults
        results += await storageResults
        return PreflightReport(results: results)
    }

    static func validateProject(
        _ project: DMGProject,
        destination: URL?,
        encryptionPassword: String
    ) -> [PreflightResult] {
        var results: [PreflightResult] = []
        validateVolumeName(project.volumeName, into: &results)
        validateContents(project, into: &results)
        validateLayout(project, into: &results)
        validateBackground(project, into: &results)
        validateLicenses(project.licenses, into: &results)
        validateCredentials(project, encryptionPassword: encryptionPassword, into: &results)
        validateDestination(destination, into: &results)
        return results
    }

    private static func validateVolumeName(
        _ rawName: String,
        into results: inout [PreflightResult]
    ) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            results.append(error("volume.empty", "卷名称为空", "请输入磁盘映像挂载后显示的名称。"))
            return
        }

        let illegal = CharacterSet(charactersIn: "/:\0").union(.controlCharacters)
        if name.rangeOfCharacter(from: illegal) != nil {
            results.append(error("volume.illegal", "卷名称包含非法字符", "不能包含斜杠、冒号、空字符或控制字符。"))
        } else {
            results.append(pass("volume.characters", "卷名称字符有效", name))
        }

        if name.utf16.count > 27 {
            results.append(error(
                "volume.length",
                "卷名称过长",
                "当前为 \(name.utf16.count) 个 UTF-16 字符；为保证 Finder 与旧系统兼容，请控制在 27 个以内。"
            ))
        } else {
            results.append(pass("volume.length", "卷名称长度有效", "\(name.utf16.count) / 27"))
        }
    }

    private static func validateContents(
        _ project: DMGProject,
        into results: inout [PreflightResult]
    ) {
        guard !project.items.isEmpty else {
            results.append(error("contents.empty", "磁盘映像没有内容", "请先添加 App、文件或文件夹。"))
            return
        }

        let applicationsLinks = project.items.filter { $0.kind == .applicationsLink }
        if applicationsLinks.count > 1 {
            results.append(error(
                "contents.applications-duplicate",
                "Applications 链接重复",
                "只保留一个指向 /Applications 的链接。"
            ))
        } else if applicationsLinks.count == 1 {
            results.append(pass("contents.applications", "Applications 链接有效", "/Applications"))
        } else {
            results.append(warning(
                "contents.applications-missing",
                "没有 Applications 链接",
                "如果这是拖放安装器，建议加入 Applications 链接。"
            ))
        }

        let groups = Dictionary(grouping: project.items) { normalizedFileName($0.name) }
        let duplicateNames = groups.values.filter { $0.count > 1 }.compactMap(\.first?.name)
        if duplicateNames.isEmpty {
            results.append(pass("contents.names", "目标文件名没有冲突", "共 \(project.items.count) 项"))
        } else {
            results.append(error(
                "contents.names",
                "目标文件名冲突",
                duplicateNames.sorted().joined(separator: "、")
            ))
        }

        for item in project.items where item.kind == .file {
            let key = "source.\(item.id.uuidString)"
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: item.sourcePath, isDirectory: &isDirectory) else {
                results.append(error(key, "找不到源文件", item.sourcePath))
                continue
            }
            guard !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                results.append(error("\(key).name", "目标文件名为空", item.sourcePath))
                continue
            }
            results.append(pass(key, "源文件可访问", item.name))

            let sourceURL = URL(fileURLWithPath: item.sourcePath)
            if sourceURL.pathExtension.lowercased() == "app" {
                validateApplication(at: sourceURL, key: key, into: &results)
            }
        }
    }

    private static func validateApplication(
        at applicationURL: URL,
        key: String,
        into results: inout [PreflightResult]
    ) {
        let contentsURL = applicationURL.appending(path: "Contents", directoryHint: .isDirectory)
        let infoURL = contentsURL.appending(path: "Info.plist")
        guard let data = try? Data(contentsOf: infoURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dictionary = plist as? [String: Any]
        else {
            results.append(error("\(key).bundle", "App 包结构不完整", "缺少或无法读取 Contents/Info.plist。"))
            return
        }

        guard let executable = dictionary["CFBundleExecutable"] as? String,
              !executable.isEmpty
        else {
            results.append(error("\(key).executable-name", "App 未声明可执行文件", "Info.plist 缺少 CFBundleExecutable。"))
            return
        }

        let executableURL = contentsURL
            .appending(path: "MacOS", directoryHint: .isDirectory)
            .appending(path: executable)
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            results.append(error("\(key).executable", "App 可执行文件缺失", executableURL.path))
            return
        }
        results.append(pass("\(key).bundle", "App 包结构完整", executable))
    }

    private static func validateLayout(
        _ project: DMGProject,
        into results: inout [PreflightResult]
    ) {
        let halfIcon = project.iconSize / 2
        let outsideItems = project.items.filter {
            $0.x < halfIcon || $0.y < halfIcon
                || $0.x > project.windowWidth - halfIcon
                || $0.y > project.windowHeight - halfIcon
        }
        if outsideItems.isEmpty {
            results.append(pass("layout.items", "图标坐标位于窗口内", "\(project.items.count) 个图标"))
        } else {
            results.append(error(
                "layout.items",
                "图标坐标超出 Finder 窗口",
                outsideItems.map(\.name).joined(separator: "、")
            ))
        }

        let outsideTextCount = project.textObjects.count {
            $0.x < 0 || $0.y < 0 || $0.x > project.windowWidth || $0.y > project.windowHeight
        }
        let outsideImageCount = project.imageObjects.count {
            $0.x - $0.width / 2 < 0 || $0.y - $0.height / 2 < 0
                || $0.x + $0.width / 2 > project.windowWidth
                || $0.y + $0.height / 2 > project.windowHeight
        }
        if outsideTextCount + outsideImageCount > 0 {
            results.append(warning(
                "layout.background-objects",
                "部分背景对象超出画布",
                "文本 \(outsideTextCount) 个，图片 \(outsideImageCount) 个。超出部分会被裁切。"
            ))
        } else if !project.textObjects.isEmpty || !project.imageObjects.isEmpty {
            results.append(pass("layout.background-objects", "背景对象位于画布内", "不会被边缘裁切"))
        }
    }

    private static func validateBackground(
        _ project: DMGProject,
        into results: inout [PreflightResult]
    ) {
        guard project.background == .image else {
            results.append(pass("background.mode", "背景设置有效", project.background.label))
            return
        }
        guard let data = project.backgroundImageData, !data.isEmpty else {
            results.append(error("background.image", "背景图片缺失", "重新选择背景图片，或切换到其他背景类型。"))
            return
        }
        guard CGImageSourceCreateWithData(data as CFData, nil) != nil else {
            results.append(error("background.image", "背景图片无效", "图片数据无法被系统解码。"))
            return
        }
        let percent = Int((project.backgroundImageZoom * 100).rounded())
        results.append(pass("background.image", "背景图片有效", "图片大小 \(percent)%"))
    }

    private static func validateLicenses(
        _ licenses: [DiskLicense],
        into results: inout [PreflightResult]
    ) {
        guard !licenses.isEmpty else {
            results.append(pass("licenses.none", "未配置许可协议", "构建时不会显示 EULA"))
            return
        }
        let duplicateKeys = Dictionary(grouping: licenses, by: \.languageKey)
            .filter { $0.value.count > 1 }
            .map(\.key)
            .sorted()
        if !duplicateKeys.isEmpty {
            results.append(error("licenses.duplicates", "许可协议语言重复", duplicateKeys.joined(separator: "、")))
        }

        let missing = licenses.filter { $0.rtfData.isEmpty }.map { $0.language.menuName }
        if !missing.isEmpty {
            results.append(error("licenses.content", "许可协议缺少正文", missing.joined(separator: "、")))
        } else {
            results.append(pass("licenses.content", "许可协议正文完整", "\(licenses.count) 种语言"))
        }
    }

    private static func validateCredentials(
        _ project: DMGProject,
        encryptionPassword: String,
        into results: inout [PreflightResult]
    ) {
        if project.encryption != .none && encryptionPassword.isEmpty {
            results.append(error("encryption.password", "加密缺少口令", "口令只保存在本次运行的内存中。"))
        } else if project.encryption != .none {
            results.append(pass("encryption.password", "加密口令已设置", "不会写入工程或日志"))
        }

        if project.gatekeeper != .none
            && project.signingIdentity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            results.append(error("signing.identity", "未选择签名身份", "请在磁盘映像设置中选择证书。"))
        }
        if project.gatekeeper == .signAndNotarize
            && project.notaryProfile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            results.append(error("notary.profile", "未配置公证凭据", "请先把 Apple ID 凭据保存到钥匙串。"))
        }
    }

    private static func validateDestination(
        _ destination: URL?,
        into results: inout [PreflightResult]
    ) {
        guard let destination else { return }
        let parent = destination.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parent.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            results.append(error("destination.parent", "目标文件夹不存在", parent.path))
            return
        }
        if FileManager.default.isWritableFile(atPath: parent.path) {
            results.append(pass("destination.writable", "目标文件夹可写", parent.path))
        } else {
            results.append(error("destination.writable", "目标文件夹不可写", parent.path))
        }
        if FileManager.default.fileExists(atPath: destination.path) {
            results.append(warning("destination.exists", "目标文件已存在", "成功后会以原子方式替换旧文件。"))
        }
    }

    private static func inspectSigning(
        project: DMGProject,
        applications: [URL]
    ) async -> [PreflightResult] {
        var results: [PreflightResult] = []

        if project.gatekeeper != .none {
            let identity = project.signingIdentity.trimmingCharacters(in: .whitespacesAndNewlines)
            if !identity.isEmpty {
                do {
                    let identities = try await Shell.run(
                        "/usr/bin/security",
                        ["find-identity", "-v", "-p", "codesigning"]
                    )
                    if identities.status == 0 && identities.output.contains("\"\(identity)\"") {
                        results.append(pass("signing.available", "签名身份可用", identity))
                    } else {
                        results.append(error("signing.available", "找不到签名身份", identity))
                    }
                } catch let caughtError {
                    results.append(error("signing.available", "无法读取签名身份", caughtError.localizedDescription))
                }
            }
        }

        if project.gatekeeper == .signAndNotarize {
            let profile = project.notaryProfile.trimmingCharacters(in: .whitespacesAndNewlines)
            if !profile.isEmpty {
                do {
                    let keychain = try await Shell.run(
                        "/usr/bin/security",
                        ["find-generic-password", "-a", profile]
                    )
                    if keychain.status == 0 {
                        results.append(pass("notary.available", "公证凭据存在", profile))
                    } else {
                        results.append(error("notary.available", "钥匙串中找不到公证凭据", profile))
                    }
                } catch let caughtError {
                    results.append(error("notary.available", "无法检查公证凭据", caughtError.localizedDescription))
                }
            }
        }

        for application in applications {
            let key = "signature.\(application.path.hashValue)"
            do {
                let verification = try await Shell.run(
                    "/usr/bin/codesign",
                    ["--verify", "--deep", "--strict", application.path]
                )
                if verification.status == 0 {
                    results.append(pass(key, "App 当前签名有效", application.lastPathComponent))
                } else {
                    results.append(warning(
                        key,
                        "App 当前签名无效或未签名",
                        conciseOutput(verification.output, fallback: application.lastPathComponent)
                    ))
                }

                let details = try await Shell.run(
                    "/usr/bin/codesign",
                    ["-d", "--verbose=4", "--entitlements", ":-", application.path]
                )
                let output = details.output
                if let teamLine = output.split(separator: "\n").first(where: { $0.hasPrefix("TeamIdentifier=") }),
                   String(teamLine.dropFirst("TeamIdentifier=".count)) != "not set" {
                    results.append(pass("\(key).team", "已读取 Team ID", String(teamLine.dropFirst("TeamIdentifier=".count))))
                } else {
                    results.append(warning("\(key).team", "App 没有 Team ID", application.lastPathComponent))
                }
                if output.localizedCaseInsensitiveContains("runtime") {
                    results.append(pass("\(key).runtime", "Hardened Runtime 已启用", application.lastPathComponent))
                } else {
                    results.append(warning("\(key).runtime", "Hardened Runtime 未启用", application.lastPathComponent))
                }
                if output.contains("com.apple.security.get-task-allow")
                    && output.localizedCaseInsensitiveContains("<true/>") {
                    results.append(warning(
                        "\(key).entitlements",
                        "App 含调试 entitlement",
                        "检测到 get-task-allow；发布版本通常应关闭。"
                    ))
                }
            } catch {
                results.append(warning(key, "无法检查 App 签名", error.localizedDescription))
            }
        }
        return results
    }

    private static func inspectMountedVolumes(volumeName: String) async -> [PreflightResult] {
        do {
            let result = try await Shell.run("/usr/bin/hdiutil", ["info", "-plist"])
            guard result.status == 0,
                  let data = result.output.data(using: .utf8),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
                  let root = plist as? [String: Any],
                  let images = root["images"] as? [[String: Any]]
            else {
                return [warning("mounts.inspect", "无法读取当前挂载卷", conciseOutput(result.output, fallback: "hdiutil info 失败"))]
            }

            let mountedNames = images.flatMap { image -> [String] in
                guard let entities = image["system-entities"] as? [[String: Any]] else { return [] }
                return entities.compactMap { entity in
                    if let name = entity["volume-name"] as? String { return name }
                    if let mountPoint = entity["mount-point"] as? String {
                        return URL(fileURLWithPath: mountPoint).lastPathComponent
                    }
                    return nil
                }
            }
            return [mountedVolumeResult(volumeName: volumeName, mountedNames: mountedNames)]
        } catch {
            return [warning("mounts.inspect", "无法读取当前挂载卷", error.localizedDescription)]
        }
    }

    private static func inspectStorage(
        project: DMGProject,
        destination: URL?
    ) async -> [PreflightResult] {
        guard let destination else { return [] }
        let parent = destination.deletingLastPathComponent()
        do {
            var sourceBytes: Int64 = 0
            for item in project.items where item.kind == .file {
                let result = try await Shell.run("/usr/bin/du", ["-sk", item.sourcePath])
                guard result.status == 0,
                      let kilobytesText = result.output.split(whereSeparator: \Character.isWhitespace).first,
                      let kilobytes = Int64(kilobytesText)
                else { continue }
                sourceBytes += kilobytes * 1_024
            }
            let required = max(sourceBytes + sourceBytes / 2 + 32 * 1_024 * 1_024, 64 * 1_024 * 1_024)
            let values = try parent.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            let resourceCapacity = values.volumeAvailableCapacityForImportantUsage
            let fileSystemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: parent.path)
            let attributeCapacity = (fileSystemAttributes?[.systemFreeSize] as? NSNumber)?.int64Value
            guard let available = [resourceCapacity, attributeCapacity]
                .compactMap({ $0 })
                .first(where: { $0 > 0 }) else {
                return [warning("storage.capacity", "无法读取剩余磁盘空间", parent.path)]
            }
            return [storageCapacityResult(requiredBytes: required, availableBytes: available)]
        } catch {
            return [warning("storage.capacity", "无法估算磁盘空间", error.localizedDescription)]
        }
    }

    private static func normalizedFileName(_ name: String) -> String {
        name.precomposedStringWithCanonicalMapping.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    private static func conciseOutput(_ output: String, fallback: String) -> String {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : String(trimmed.suffix(500))
    }

    private static func error(_ id: String, _ title: String, _ detail: String) -> PreflightResult {
        PreflightResult(id: id, severity: .error, title: title, detail: detail)
    }

    private static func warning(_ id: String, _ title: String, _ detail: String) -> PreflightResult {
        PreflightResult(id: id, severity: .warning, title: title, detail: detail)
    }

    private static func pass(_ id: String, _ title: String, _ detail: String) -> PreflightResult {
        PreflightResult(id: id, severity: .passed, title: title, detail: detail)
    }

    static func mountedVolumeResult(volumeName: String, mountedNames: [String]) -> PreflightResult {
        let normalizedName = normalizedFileName(volumeName)
        if mountedNames.contains(where: { normalizedFileName($0) == normalizedName }) {
            return warning(
                "mounts.conflict",
                "已有同名卷挂载",
                "后台构建会使用独立挂载点，但建议先弹出同名卷以免混淆。"
            )
        }
        return pass("mounts.conflict", "没有同名挂载卷", volumeName)
    }

    static func storageCapacityResult(requiredBytes: Int64, availableBytes: Int64) -> PreflightResult {
        if availableBytes < requiredBytes {
            return error(
                "storage.capacity",
                "剩余磁盘空间不足",
                "预计至少需要 \(ByteCountFormatter.string(fromByteCount: requiredBytes, countStyle: .file))，当前可用 \(ByteCountFormatter.string(fromByteCount: availableBytes, countStyle: .file))。"
            )
        }
        return pass(
            "storage.capacity",
            "剩余磁盘空间充足",
            "可用 \(ByteCountFormatter.string(fromByteCount: availableBytes, countStyle: .file))"
        )
    }
}
