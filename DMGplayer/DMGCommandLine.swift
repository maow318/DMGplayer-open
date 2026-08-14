//
//  DMGCommandLine.swift
//  DMGplayer
//

import Darwin
import Foundation

@MainActor
enum DMGCommandLine {
    nonisolated static let commands: Set<String> = ["build", "validate", "init", "help", "--help", "-h"]
    nonisolated static let invocationArguments = Array(CommandLine.arguments.dropFirst())

    nonisolated static var isInvocation: Bool {
        invocationArguments.first.map(commands.contains) ?? false
    }

    static func run(arguments suppliedArguments: [String]? = nil) async -> Int32 {
        let arguments = suppliedArguments ?? invocationArguments
        guard let command = arguments.first else { return 64 }
        do {
            switch command {
            case "build":
                return try await build(Array(arguments.dropFirst()))
            case "validate":
                return try await validate(Array(arguments.dropFirst()))
            case "init":
                return try initialize(Array(arguments.dropFirst()))
            case "help", "--help", "-h":
                Console.stdout(usage)
                return 0
            default:
                throw CLIError("未知命令：\(command)")
            }
        } catch is CancellationError {
            Console.stderr("已取消；正在确认临时映像已卸载。")
            return 130
        } catch {
            let cocoaError = error as NSError
            let reason = cocoaError.localizedFailureReason.map { "（\($0)）" } ?? ""
            Console.stderr("错误：\(error.localizedDescription)\(reason) [\(cocoaError.domain) \(cocoaError.code)]")
            return 1
        }
    }

    private static func build(_ arguments: [String]) async throws -> Int32 {
        guard let projectPath = arguments.first else { throw CLIError("build 缺少工程路径") }
        guard let outputPath = option("--output", in: arguments) else {
            throw CLIError("build 必须提供 --output <结果.dmg>")
        }

        let projectURL = URL(fileURLWithPath: projectPath).standardizedFileURL
        let outputURL = URL(fileURLWithPath: outputPath).standardizedFileURL
        let project = try loadProject(at: projectURL)
        let password = ProcessInfo.processInfo.environment["DMGPLAYER_ENCRYPTION_PASSWORD"] ?? ""
        let report = await BuildPreflight.run(
            project: project,
            destination: outputURL,
            encryptionPassword: password
        )
        print(report: report)
        guard report.errors.isEmpty else { return 2 }

        let controller = BuildController()
        try await controller.runHeadless(
            project: project,
            destination: outputURL,
            encryptionPassword: password,
            onLog: Console.stdout
        )
        Console.stdout("输出：\(outputURL.path)")
        return 0
    }

    private static func validate(_ arguments: [String]) async throws -> Int32 {
        guard let projectPath = arguments.first else { throw CLIError("validate 缺少工程路径") }
        let projectURL = URL(fileURLWithPath: projectPath).standardizedFileURL
        let destination = option("--output", in: arguments).map {
            URL(fileURLWithPath: $0).standardizedFileURL
        }
        let project = try loadProject(at: projectURL)
        let password = ProcessInfo.processInfo.environment["DMGPLAYER_ENCRYPTION_PASSWORD"] ?? ""
        let report = await BuildPreflight.run(
            project: project,
            destination: destination,
            encryptionPassword: password
        )
        print(report: report)
        return report.errors.isEmpty ? 0 : 2
    }

    private static func initialize(_ arguments: [String]) throws -> Int32 {
        guard let appPath = option("--app", in: arguments),
              let outputPath = option("--output", in: arguments) else {
            throw CLIError("init 需要 --app <MyApp.app> --output <工程.dmgproject>")
        }
        let appURL = URL(fileURLWithPath: appPath).standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: appURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue,
              appURL.pathExtension.localizedCaseInsensitiveCompare("app") == .orderedSame else {
            throw CLIError("--app 必须指向现有的 .app 包")
        }
        let outputURL = URL(fileURLWithPath: outputPath).standardizedFileURL
        var project = DefaultProjectFactory.project(for: appURL)
        for index in project.items.indices where project.items[index].kind == .file {
            project.items[index].relativeSourcePath = ProjectPathResolver.relativePath(
                from: appURL,
                to: outputURL.deletingLastPathComponent()
            )
        }
        try ProjectDocumentCodec.writePackage(project, to: outputURL)
        Console.stdout("已创建工程：\(outputURL.path)")
        return 0
    }

    private static func loadProject(at url: URL) throws -> DMGProject {
        let project = try ProjectDocumentCodec.read(at: url)
        return ProjectPathResolver.materialized(project, documentURL: url)
    }

    private static func option(_ name: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    private static func print(report: PreflightReport) {
        for result in report.results {
            let marker = switch result.severity {
            case .error: "ERROR"
            case .warning: "WARN"
            case .passed: "PASS"
            }
            let write = result.severity == .error ? Console.stderr : Console.stdout
            write("[\(marker)] \(result.title)：\(result.detail)")
        }
        Console.stdout("预检：\(report.summary)")
    }

    private static let usage = """
    DMGplayer 命令行

      DMGplayer build <工程.dmgproject> --output <结果.dmg>
      DMGplayer validate <工程.dmgproject> [--output <结果.dmg>]
      DMGplayer init --app <MyApp.app> --output <工程.dmgproject>

    加密工程请通过 DMGPLAYER_ENCRYPTION_PASSWORD 环境变量提供口令；口令不会写入日志。
    """
}

nonisolated private struct CLIError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

nonisolated private enum Console {
    static func stdout(_ line: String) { write(line, to: .standardOutput) }
    static func stderr(_ line: String) { write(line, to: .standardError) }

    private static func write(_ line: String, to handle: FileHandle) {
        guard let data = (line + "\n").data(using: .utf8) else { return }
        try? handle.write(contentsOf: data)
    }
}
