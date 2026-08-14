//
//  main.swift
//  DMGplayer
//

import Darwin
import SwiftUI

/// CLI 在 SwiftUI / NSApplication 创建前分流。这样 `build` 和工程路径不会被
/// DocumentGroup 当成待打开文档，同时也避免 CI 需要图形会话。
if DMGCommandLine.isInvocation {
    Darwin.signal(SIGINT, SIG_IGN)
    Darwin.signal(SIGTERM, SIG_IGN)

    let commandTask = Task { @MainActor in
        let code = await DMGCommandLine.run()
        Darwin.exit(code)
    }

    let interruptSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
    interruptSource.setEventHandler { commandTask.cancel() }
    interruptSource.resume()

    let terminationSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    terminationSource.setEventHandler { commandTask.cancel() }
    terminationSource.resume()

    // CLI 不创建 NSApplication；只运行主队列，直到命令完成或收到中断信号。
    dispatchMain()
} else {
    DMGplayerApp.main()
}
