//
//  DMGBuilder.swift
//  DMGplayer
//
//  构建流水线，与 DMG Canvas 的做法一致：
//  staging → hdiutil create (UDRW) → attach → Finder 写入布局(.DS_Store)
//  → detach → hdiutil convert（压缩/加密）→ udifrez 注入许可 → codesign → notarytool + stapler
//

import AppKit
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins
import Darwin
import Foundation
import SwiftUI

struct BuildError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

// MARK: - 子进程执行

enum Shell {
    /// 运行外部命令，返回 (退出码, 合并输出)。不会阻塞主线程。
    nonisolated static func run(_ tool: String, _ args: [String], stdin: Data? = nil) async throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        if let stdin {
            let inPipe = Pipe()
            process.standardInput = inPipe
            let status = try await launch(process, outputPipe: pipe) {
                // write(contentsOf:) 是可抛错版本；hdiutil 秒退时
                // 直接 write(_:) 会抛 ObjC 异常导致无法捕获的崩溃
                try? inPipe.fileHandleForWriting.write(contentsOf: stdin)
                try? inPipe.fileHandleForWriting.close()
            }
            return status
        }
        return try await launch(process, outputPipe: pipe, afterLaunch: nil)
    }

    private nonisolated static func launch(_ process: Process, outputPipe: Pipe,
                                           afterLaunch: (() -> Void)?) async throws -> (Int32, String) {
        try Task.checkCancellation()
        let handle = outputPipe.fileHandleForReading
        // 先启动读取，避免子进程输出超过管道缓冲导致卡死
        let drain = Task.detached { handle.readDataToEndOfFile() }

        // 任务被取消时终止子进程，让"取消"在 convert / 公证等待中也即时生效
        let status: Int32 = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { cont in
                process.terminationHandler = { p in cont.resume(returning: p.terminationStatus) }
                do {
                    try process.run()
                    afterLaunch?()
                } catch {
                    process.terminationHandler = nil
                    outputPipe.fileHandleForWriting.closeFile()
                    cont.resume(throwing: error)
                }
            }
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
        }

        let data = await drain.value
        try Task.checkCancellation()
        return (status, String(data: data, encoding: .utf8) ?? "")
    }

    /// 运行命令，非 0 退出码时抛错
    @discardableResult
    nonisolated static func runOrThrow(_ tool: String, _ args: [String], stdin: Data? = nil) async throws -> String {
        let result = try await run(tool, args, stdin: stdin)
        guard result.status == 0 else {
            let tail = result.output.suffix(600)
            throw BuildError(message: "\((tool as NSString).lastPathComponent) 退出码 \(result.status)：\(tail)")
        }
        return result.output
    }
}

// MARK: - 构建控制器

@MainActor
final class BuildController: ObservableObject {
    struct LogLine: Identifiable {
        let id = UUID()
        let text: String
        let isStep: Bool
    }

    @Published var lines: [LogLine] = []
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var finishedURL: URL?
    @Published var errorMessage: String?

    private var buildTask: Task<Void, Never>?
    private var resumeContinuation: CheckedContinuation<Bool, Never>?
    private var externalLogHandler: ((String) -> Void)?

    var hasVisibleStatus: Bool {
        isRunning || finishedURL != nil || errorMessage != nil
    }

    func start(project: DMGProject, destination: URL, encryptionPassword: String,
               pauseBeforeFinalize: Bool = false) {
        // 防重入：暂停中的旧构建若被新构建覆盖，其 continuation 与挂载卷会永久泄漏
        guard !isRunning else { return }
        lines = []
        errorMessage = nil
        finishedURL = nil
        isRunning = true
        isPaused = false
        let snapshot = project
        buildTask = Task {
            do {
                let localReport = PreflightReport(results: BuildPreflight.validateProject(
                    snapshot,
                    destination: destination,
                    encryptionPassword: encryptionPassword
                ))
                guard localReport.errors.isEmpty else {
                    throw BuildError(message: localReport.errors.map(\.title).joined(separator: "；"))
                }
                for warning in localReport.warnings {
                    self.log("预检警告：\(warning.title) — \(warning.detail)")
                }
                try await self.pipeline(project: snapshot, destination: destination,
                                        encryptionPassword: encryptionPassword,
                                        pauseBeforeFinalize: pauseBeforeFinalize)
                self.finishedURL = destination
                self.log("构建完成 ✅", step: true)
            } catch is CancellationError {
                self.errorMessage = "已取消"
                self.log("已取消", step: true)
            } catch {
                self.errorMessage = error.localizedDescription
                self.log("失败：\(error.localizedDescription)", step: true)
            }
            self.isRunning = false
        }
    }

    func cancel() {
        if isPaused {
            resumeContinuation?.resume(returning: false)
            resumeContinuation = nil
        }
        buildTask?.cancel()
    }

    /// 暂停检查后继续完成构建
    func resumeFinalize() {
        resumeContinuation?.resume(returning: true)
        resumeContinuation = nil
    }

    /// CLI 与 GUI 共用这一条流水线；CLI 只替换日志出口，不复制任何构建步骤。
    func runHeadless(
        project: DMGProject,
        destination: URL,
        encryptionPassword: String,
        onLog: @escaping (String) -> Void
    ) async throws {
        guard !isRunning else { throw BuildError(message: "已有构建正在运行") }
        lines = []
        errorMessage = nil
        finishedURL = nil
        isRunning = true
        externalLogHandler = onLog
        defer {
            externalLogHandler = nil
            isRunning = false
            isPaused = false
        }
        try await pipeline(
            project: project,
            destination: destination,
            encryptionPassword: encryptionPassword,
            pauseBeforeFinalize: false
        )
        finishedURL = destination
        log("构建完成 ✅", step: true)
    }

    private func log(_ text: String, step: Bool = false) {
        lines.append(LogLine(text: text, isStep: step))
        externalLogHandler?(text)
    }

    // MARK: - 流水线

    private func pipeline(project: DMGProject, destination: URL, encryptionPassword: String,
                          pauseBeforeFinalize: Bool) async throws {
        let fm = FileManager.default
        let workspace = BuildWorkspace()
        let workDir = workspace.root
        let stagingDir = workspace.staging
        let tempDMG = workspace.readWriteImage
        let mountDirectory = workspace.mountPoint
        let destinationDirectory = destination.deletingLastPathComponent()
        let finalDMG = destinationDirectory.appending(
            path: ".\(destination.lastPathComponent).DMGplayer-\(UUID().uuidString).partial.dmg"
        )
        defer {
            try? fm.removeItem(at: finalDMG)
            try? workspace.cleanup()
        }

        try workspace.prepare()

        // 1. 准备内容
        log("正在拷贝文件…", step: true)
        let backgroundFileName = "background.png"
        let useBackgroundFile = try await stage(project: project, into: stagingDir,
                                                backgroundFileName: backgroundFileName)
        try Task.checkCancellation()

        // 2. 创建可读写映像
        log("正在创建磁盘映像模板…", step: true)
        let sizeMB: Int
        if project.imageSizeAuto {
            sizeMB = try await estimateSizeMB(of: stagingDir)
        } else {
            sizeMB = project.customSizeMB
        }
        log("映像大小：\(sizeMB) MB · 文件系统：\(project.fileSystem.summaryName)")
        try await runHdiutilWithRetry(action: "创建磁盘映像模板", arguments: [
            "create",
            "-srcfolder", stagingDir.path,
            "-volname", project.volumeName,
            "-fs", project.fileSystem == .apfs ? "APFS" : "HFS+",
            "-format", "UDRW",
            "-size", "\(sizeMB)m",
            "-ov", "-quiet",
            tempDMG.path,
        ])
        try Task.checkCancellation()

        // 3. 挂载
        log("正在挂载映像…", step: true)
        let attachOutput = try await runHdiutilWithRetry(action: "挂载磁盘映像", arguments: [
            "attach", tempDMG.path,
            // -noautoopen 只阻止弹出窗口；-nobrowse 同时阻止临时卷出现在
            // Finder 桌面和侧边栏，构建过程因此不会产生“先到桌面再消失”的错觉。
            "-readwrite", "-noverify", "-noautoopen", "-nobrowse",
            "-mountpoint", mountDirectory.path,
            "-plist",
        ])
        guard let mountPoint = Self.parseMountPoint(fromAttachPlist: attachOutput) else {
            // 已挂载但解析不到挂载点：尽力弹出，避免卷残留
            _ = try? await Shell.run("/usr/bin/hdiutil", ["detach", tempDMG.path, "-force"])
            throw BuildError(message: "无法解析挂载点")
        }
        log("挂载于 \(mountPoint)")
        let finderWasVisible = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == "com.apple.finder" })
            .map { !$0.isHidden } ?? true

        // 挂载后的所有步骤放进 do/catch：任何失败都先同步弹出，再让 defer 删临时目录，
        // 保证顺序是 detach → removeItem（异步 defer Task 会颠倒这个顺序）
        do {
            // 4. 卷图标（App 图标合成到硬盘标签上，官方风格）
            if let iconData = project.volumeIconData, let badge = NSImage(data: iconData) {
                log("正在设置卷图标…", step: true)
                NSWorkspace.shared.setIcon(
                    VolumeIcon.composite(badge: badge),
                    forFile: mountPoint, options: [])
            }

            // 5. Finder 布局（窗口大小、背景、图标位置 → .DS_Store）
            log("正在写入窗口布局…", step: true)
            let mountedVolumeName = URL(fileURLWithPath: mountPoint).lastPathComponent
            let script = Self.layoutScript(project: project,
                                           mountedVolumeName: mountedVolumeName,
                                           mountPoint: mountPoint,
                                           backgroundFileName: useBackgroundFile ? backgroundFileName : nil)
            try await Shell.runOrThrow("/usr/bin/osascript", ["-e", script])
            _ = try? await Shell.run("/bin/sync", [])
            try await Task.sleep(for: .seconds(2))
            try Task.checkCancellation()

            // 6. 构建并暂停：把卷交给用户检查（可手动微调，改动会保留进成品）
            if pauseBeforeFinalize {
                try Task.checkCancellation()
                log("已暂停 — 请在访达中检查磁盘映像内容", step: true)
                log("可以直接在访达里微调图标位置，改动会保留到最终映像")
                NSWorkspace.shared.open(URL(fileURLWithPath: mountPoint))
                isPaused = true
                let proceed = await withCheckedContinuation { resumeContinuation = $0 }
                isPaused = false
                guard proceed else { throw CancellationError() }
                log("继续完成构建…", step: true)
                _ = try? await Shell.run("/bin/sync", [])
                try await Task.sleep(for: .seconds(1))
            }

            // 7. 弹出
            log("正在弹出映像…", step: true)
            try await detach(mountPoint: mountPoint)
        } catch {
            // 取消状态会被结构化子任务继承，直接清理会立刻再次取消。
            // 使用不继承取消状态的短生命周期任务，确保失败/取消都能完成卸载。
            await Self.cleanupMountUncancelled(mountPoint)
            await Self.restoreFinderVisibilityUncancelled(wasVisible: finderWasVisible)
            throw error
        }

        // 8. 转换为最终格式（先输出到临时位置；全部后处理成功后才移动到目标位置，
        //    失败时不会留下"看似完整"的半成品，也不会破坏上一次构建的旧成品）
        let format = project.compression.convertFormat
        log("正在生成最终磁盘映像（\(format)）…", step: true)
        var convertArgs = ["convert", tempDMG.path, "-format", format,
                           "-o", finalDMG.path, "-ov", "-quiet"]
        if project.compression == .zlib {
            convertArgs += ["-imagekey", "zlib-level=9"]
        }
        var stdinData: Data?
        if let encryption = project.encryption.hdiutilName {
            log("启用加密：\(encryption)")
            convertArgs += ["-encryption", encryption, "-stdinpass"]
            stdinData = Data(encryptionPassword.utf8)
        }
        try await Shell.runOrThrow("/usr/bin/hdiutil", convertArgs, stdin: stdinData)
        try Task.checkCancellation()

        // 9. 注入许可协议
        if !project.licenses.isEmpty {
            log("正在添加许可协议…", step: true)
            let plistURL = workDir.appendingPathComponent("licenses.plist")
            try LicenseResourceBuilder.plistData(for: project.licenses).write(to: plistURL)
            try await Shell.runOrThrow("/usr/bin/hdiutil", [
                "udifrez", "-xml", plistURL.path, "", finalDMG.path,
            ])
        }

        // 10. 签名 / 公证
        if project.gatekeeper != .none {
            let identity = project.signingIdentity.trimmingCharacters(in: .whitespaces)
            guard !identity.isEmpty else {
                throw BuildError(message: "请先在“磁盘映像”设置里选择签名身份")
            }
            log("正在签名磁盘映像…", step: true)
            try await Shell.runOrThrow("/usr/bin/codesign", [
                "--force", "--sign", identity, "--timestamp", finalDMG.path,
            ])
        }

        if project.gatekeeper == .signAndNotarize {
            let profile = project.notaryProfile.trimmingCharacters(in: .whitespaces)
            guard !profile.isEmpty else {
                throw BuildError(message: "公证需要先在“磁盘映像”设置里配置 Apple ID 凭据")
            }
            log("正在提交公证（可能需要几分钟）…", step: true)
            let output = try await Shell.runOrThrow("/usr/bin/xcrun", [
                "notarytool", "submit", finalDMG.path,
                "--keychain-profile", profile, "--wait",
            ])
            guard output.contains("status: Accepted") else {
                throw BuildError(message: "公证未通过：\(output.suffix(400))")
            }
            log("公证通过，正在装订票据…", step: true)
            try await Shell.runOrThrow("/usr/bin/xcrun", ["stapler", "staple", finalDMG.path])
        }

        // 11. 全部成功，在目标目录内原子替换。旧成品直到 rename 成功前始终保留。
        try AtomicOutputCommitter.commit(finalDMG, to: destination)

        // 构建结果摘要
        let sizeText: String
        if let bytes = try? fm.attributesOfItem(atPath: destination.path)[.size] as? Int64 {
            sizeText = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        } else {
            sizeText = "未知"
        }
        log("")
        log("══════════════════════════════════", step: false)
        log("构建结果：\(project.volumeName)", step: true)
        log(destination.path)
        log("• 大小：\(sizeText)")
        log("• 代码签名：\(project.gatekeeper == .none ? "关" : "开")")
        log("• 公证：\(project.gatekeeper == .signAndNotarize ? "开" : "关")")
        log("• 加密：\(project.encryption == .none ? "关" : "开")")
        log("• 格式：\(project.fileSystem.summaryName)")
        log("• 压缩：\(project.compression.summaryName)")
        if !project.licenses.isEmpty {
            log("• 许可协议：\(project.licenses.count) 种语言")
        }
        log("• \(project.minMacOSText)")
    }

    // MARK: - 步骤实现

    /// 返回是否写入了背景图片文件
    private func stage(project: DMGProject, into stagingDir: URL, backgroundFileName: String) async throws -> Bool {
        let fm = FileManager.default
        for item in project.items {
            try Task.checkCancellation()
            switch item.kind {
            case .applicationsLink:
                log("创建 Applications 替身")
                try fm.createSymbolicLink(
                    atPath: stagingDir.appendingPathComponent(item.name).path,
                    withDestinationPath: "/Applications"
                )
            case .file:
                guard fm.fileExists(atPath: item.sourcePath) else {
                    throw BuildError(message: "找不到源文件：\(item.sourcePath)")
                }
                log("拷贝 \(item.name)")
                let stagedPath = stagingDir.appendingPathComponent(item.name).path
                // ditto 保留资源分支和扩展属性
                try await Shell.runOrThrow("/usr/bin/ditto", [item.sourcePath, stagedPath])

                if let iconData = item.customIconData, let icon = NSImage(data: iconData) {
                    log("设置 \(item.name) 的自定义图标")
                    NSWorkspace.shared.setIcon(icon, forFile: stagedPath, options: [])
                }
                if item.invisible {
                    log("隐藏 \(item.name)")
                    try await Shell.runOrThrow("/usr/bin/chflags", ["hidden", stagedPath])
                }
            }
        }

        if project.needsCompositeBackground {
            guard let png = Self.renderBackground(project: project) else {
                throw BuildError(message: "背景图片渲染失败")
            }
            let bgDir = stagingDir.appendingPathComponent(".background", isDirectory: true)
            try fm.createDirectory(at: bgDir, withIntermediateDirectories: true)
            try png.write(to: bgDir.appendingPathComponent(backgroundFileName))
            return true
        }
        return false
    }

    private func estimateSizeMB(of folder: URL) async throws -> Int {
        // du 可能因个别不可读子项返回非 0 并输出警告行，逐行找 "数字<TAB>" 的结果行
        let result = try await Shell.run("/usr/bin/du", ["-sm", folder.path])
        for line in result.output.split(separator: "\n").reversed() {
            let fields = line.split(separator: "\t", maxSplits: 1)
            if let first = fields.first, let used = Int(first.trimmingCharacters(in: .whitespaces)) {
                // 预留 15% + 12MB 给文件系统、.DS_Store、卷图标等
                return max(used + used / 6 + 12, 16)
            }
        }
        throw BuildError(message: "无法估算内容大小：\(result.output.suffix(200))")
    }

    private func detach(mountPoint: String) async throws {
        // 用户可能在暂停检查期间已手动弹出，此时视为成功
        guard FileManager.default.fileExists(atPath: mountPoint) else {
            log("卷已被手动弹出")
            return
        }
        for attempt in 1...5 {
            let result = try await Shell.run("/usr/bin/hdiutil", ["detach", mountPoint, "-quiet"])
            if result.status == 0 { return }
            log("弹出失败（第 \(attempt) 次），重试…")
            try await Task.sleep(for: .seconds(1))
        }
        try await Shell.runOrThrow("/usr/bin/hdiutil", ["detach", mountPoint, "-force"])
    }

    @discardableResult
    private func runHdiutilWithRetry(
        action: String,
        arguments: [String],
        maximumAttempts: Int = 4
    ) async throws -> String {
        for attempt in 1...maximumAttempts {
            try Task.checkCancellation()
            let result = try await Shell.run("/usr/bin/hdiutil", arguments)
            if result.status == 0 { return result.output }

            let lowercasedOutput = result.output.lowercased()
            let recoverable = lowercasedOutput.contains("resource busy")
                || lowercasedOutput.contains("temporarily unavailable")
                || lowercasedOutput.contains("resource temporarily unavailable")
            guard recoverable, attempt < maximumAttempts else {
                throw BuildError(message: "\(action)失败：\(result.output.suffix(600))")
            }
            log("\(action)遇到资源占用（第 \(attempt) 次），稍后重试…")
            try await Task.sleep(for: .milliseconds(400 * attempt))
        }
        throw BuildError(message: "\(action)失败")
    }

    private nonisolated static func cleanupMountUncancelled(_ mountPoint: String) async {
        await Task.detached(priority: .utility) {
            for attempt in 1...3 {
                guard FileManager.default.fileExists(atPath: mountPoint) else { return }
                let result = try? await Shell.run(
                    "/usr/bin/hdiutil",
                    ["detach", mountPoint, attempt == 3 ? "-force" : "-quiet"]
                )
                if result?.status == 0 { return }
                try? await Task.sleep(for: .milliseconds(350 * attempt))
            }
        }.value
    }

    private nonisolated static func restoreFinderVisibilityUncancelled(wasVisible: Bool) async {
        let script = "tell application \"Finder\" to set visible to \(wasVisible ? "true" : "false")"
        _ = await Task.detached(priority: .utility) {
            try? await Shell.run("/usr/bin/osascript", ["-e", script])
        }.value
    }

    // MARK: - 背景合成（底色/底图/渐变 + 玻璃面板 + 图片对象 + 文本对象 → 2x PNG）

    static func renderBackground(project: DMGProject) -> Data? {
        let pointW = project.windowWidth
        let pointH = project.windowHeight
        let pixelW = Int(pointW * 2)
        let pixelH = Int(pointH * 2)

        // ImageRenderer 会污染当前图形上下文，必须在创建位图上下文之前渲染
        let meshImage: NSImage? = project.background == .mesh ? renderMeshImage(project: project) : nil

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixelW, pixelsHigh: pixelH,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        rep.size = NSSize(width: pointW, height: pointH)  // 144dpi → Finder 按点尺寸显示

        // rep.size 已设为点尺寸，NSGraphicsContext 自带 2x 变换，直接用点坐标绘制
        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        defer {
            ctx.flushGraphics()
            NSGraphicsContext.restoreGraphicsState()
        }

        let bounds = NSRect(x: 0, y: 0, width: pointW, height: pointH)

        // 底层
        switch project.background {
        case .color:
            project.backgroundColor.nsColor.setFill()
            bounds.fill()
        case .mesh:
            NSColor.white.setFill()
            bounds.fill()
            meshImage?.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
        case .image:
            NSColor.white.setFill()
            bounds.fill()
            if let image = project.backgroundImage {
                let drawRect = BackgroundImageLayout.drawRect(
                    canvasSize: bounds.size,
                    imageSize: image.size,
                    zoom: project.backgroundImageZoom
                )
                NSGraphicsContext.current?.saveGraphicsState()
                NSBezierPath(rect: bounds).setClip()
                image.draw(in: drawRect,
                           from: .zero, operation: .sourceOver, fraction: 1)
                NSGraphicsContext.current?.restoreGraphicsState()
            }
        case .none:
            NSColor.white.setFill()
            bounds.fill()
        }

        // 图片对象（模型坐标系为左上原点，绘制坐标系为左下原点）
        for object in project.imageObjects {
            guard let image = object.image else { continue }
            let rect = NSRect(x: object.x - object.width / 2,
                              y: pointH - object.y - object.height / 2,
                              width: object.width, height: object.height)
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        }

        // 文本对象（支持字体、多行对齐、阴影）
        for object in project.textObjects {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = object.alignment.nsAlignment
            let attributes: [NSAttributedString.Key: Any] = [
                .font: object.nsFont,
                .foregroundColor: object.color.nsColor,
                .paragraphStyle: paragraph,
            ]
            let string = NSAttributedString(string: object.text, attributes: attributes)
            let size = string.boundingRect(
                with: NSSize(width: CGFloat.greatestFiniteMagnitude,
                             height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin]
            ).size

            NSGraphicsContext.current?.saveGraphicsState()
            if object.shadowEnabled {
                let shadow = NSShadow()
                shadow.shadowColor = object.shadowColor.nsColor
                    .withAlphaComponent(object.shadowOpacity)
                let vector = object.shadowVector
                // 绘制坐标系 y 向上，屏幕向下的偏移取负
                shadow.shadowOffset = NSSize(width: vector.width, height: -vector.height)
                shadow.shadowBlurRadius = object.shadowBlur
                shadow.set()
            }
            string.draw(in: NSRect(x: object.x - size.width / 2,
                                   y: pointH - object.y - size.height / 2,
                                   width: size.width, height: size.height))
            NSGraphicsContext.current?.restoreGraphicsState()
        }

        return rep.representation(using: .png, properties: [:])
    }

    /// 用 ImageRenderer 把 Mesh 渐变渲染成 2x 位图（与画布预览同一个视图）
    static func renderMeshImage(project: DMGProject) -> NSImage? {
        let view = MeshBackgroundView(colors: project.meshColors, points: project.meshPoints)
            .frame(width: project.windowWidth, height: project.windowHeight)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.nsImage
    }

    // MARK: - 辅助

    nonisolated static func parseMountPoint(fromAttachPlist output: String) -> String? {
        guard let data = output.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dict = plist as? [String: Any],
              let entities = dict["system-entities"] as? [[String: Any]]
        else { return nil }
        for entity in entities {
            if let mountPoint = entity["mount-point"] as? String {
                return mountPoint
            }
        }
        return nil
    }

    /// 生成 Finder 布局 AppleScript —— Finder 会把这些设置写进卷根的 .DS_Store
    nonisolated static func layoutScript(
        project: DMGProject,
        mountedVolumeName: String,
        mountPoint: String,
        backgroundFileName: String?
    ) -> String {
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
        }

        let left = Int(project.windowLeft)
        let top = Int(project.windowTop)
        let right = left + Int(project.windowWidth)
        let bottom = top + Int(project.windowHeight)

        let backgroundDeclaration: String
        if let fileName = backgroundFileName {
            let path = URL(fileURLWithPath: mountPoint)
                .appending(path: ".background/\(fileName)")
                .path
            // 在 `tell icon view options` 内直接写 `file ".background:..."`
            // 会被 Finder 解析成 icon view options 的子项。先在外层创建
            // POSIX alias，再赋给 background picture，可兼容显式 mountpoint。
            backgroundDeclaration = "set backgroundFileAlias to POSIX file \"\(esc(path))\" as alias"
        } else {
            backgroundDeclaration = ""
        }

        var body = """
        \(backgroundDeclaration)
        tell application "Finder"
            set finderWasVisible to visible
            set visible to false
        end tell
        try
        tell application "Finder"
            tell disk "\(esc(mountedVolumeName))"
                open
                -- “open disk” 会把 Finder 自己重新显示出来；立即再次隐藏，并先把
                -- 临时窗口放到屏幕外，避免写 .DS_Store 的窗口在快速打包时闪现。
                set visible of application "Finder" to false
                set the bounds of container window to {-10000, -10000, \(-10000 + Int(project.windowWidth)), \(-10000 + Int(project.windowHeight))}
                set current view of container window to icon view
                delay 0.1
                set toolbar visible of container window to \(project.showSidebar ? "true" : "false")
                \(project.showSidebar ? "set sidebar width of container window to 180" : "")
                set statusbar visible of container window to false
                set the bounds of container window to {\(left), \(top), \(right), \(bottom)}
                tell icon view options of container window
                    set arrangement to not arranged
                    set icon size to \(Int(project.iconSize))
                    set text size to \(Int(project.textSize))
                    set label position to \(project.labelPosition.rawValue)
                    set shows item info to \(project.showItemInfo ? "true" : "false")
                    set shows icon preview to \(project.showIconPreview ? "true" : "false")
        """

        if backgroundFileName != nil {
            body += "\n                set background picture to backgroundFileAlias"
        } else if project.background == .color {
            let c = project.backgroundColor
            let r = Int(c.red * 65535), g = Int(c.green * 65535), b = Int(c.blue * 65535)
            body += "\n                set background color to {\(r), \(g), \(b)}"
        } else {
            body += "\n                set background color to {65535, 65535, 65535}"
        }

        body += "\n            end tell"

        for item in project.items {
            body += "\n        set position of item \"\(esc(item.name))\" of container window to {\(Int(item.x)), \(Int(item.y))}"
        }

        body += """

                update without registering applications
                set visible of application "Finder" to false
                delay 1
                set visible of application "Finder" to false
                close
                delay 0.5
            end tell
        end tell
        on error errMsg number errNum
            -- 错误时必须先关临时窗口，再恢复 Finder，否则错误路径仍会闪窗。
            tell application "Finder"
                try
                    tell disk "\(esc(mountedVolumeName))" to close container window
                end try
                if finderWasVisible then set visible to true
            end tell
            error errMsg number errNum
        end try
        if finderWasVisible then
            tell application "Finder" to set visible to true
        end if
        """
        return body
    }
}
