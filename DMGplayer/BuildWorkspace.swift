//
//  BuildWorkspace.swift
//  DMGplayer
//

import Darwin
import Foundation

nonisolated struct BuildWorkspace: Sendable {
    static let directoryPrefix = "DMGplayer-"

    let root: URL
    let staging: URL
    let readWriteImage: URL
    let mountPoint: URL

    init(baseDirectory: URL = FileManager.default.temporaryDirectory, id: UUID = UUID()) {
        root = baseDirectory.appending(
            path: Self.directoryPrefix + id.uuidString,
            directoryHint: .isDirectory
        )
        staging = root.appending(path: "staging", directoryHint: .isDirectory)
        readWriteImage = root.appending(path: "rw.dmg")
        mountPoint = root.appending(path: "mount", directoryHint: .isDirectory)
    }

    func prepare() throws {
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)
    }

    func cleanup() throws {
        guard FileManager.default.fileExists(atPath: root.path) else { return }
        try FileManager.default.removeItem(at: root)
    }
}

nonisolated enum AtomicOutputCommitter {
    /// 同一目录内 POSIX rename 是原子的；目标存在时也只在成功瞬间被替换。
    static func commit(_ source: URL, to destination: URL) throws {
        let result = source.withUnsafeFileSystemRepresentation { sourcePath in
            destination.withUnsafeFileSystemRepresentation { destinationPath in
                guard let sourcePath, let destinationPath else { return EINVAL }
                return Darwin.rename(sourcePath, destinationPath) == 0 ? 0 : errno
            }
        }
        guard result == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: result) ?? .EIO)
        }
    }
}
