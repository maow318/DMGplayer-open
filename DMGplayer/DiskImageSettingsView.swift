//
//  DiskImageSettingsView.swift
//  DMGplayer
//
//  “磁盘映像”设置页：卷名称、卷图标、Gatekeeper、格式、压缩、映像大小、加密，
//  右侧为构建摘要栏 —— 对应 DMG Canvas 的 Disk Image 页面。
//

import SwiftUI
import UniformTypeIdentifiers

struct DiskImageSettingsView: View {
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject private var languageStore: AppLanguageStore
    @State private var showAppleIDSheet = false

    private var appleIDBinding: Binding<String> {
        Binding(
            get: { store.project.notaryProfile },
            set: { newValue in
                if newValue == "__add__" {
                    showAppleIDSheet = true
                } else {
                    store.updateProject(actionName: "修改公证设置") {
                        $0.notaryProfile = newValue
                    }
                }
            }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            Form {
                TextField(
                    "卷名称：",
                    text: store.volumeNameBinding(
                        localizedDefault: languageStore.defaultVolumeName
                    )
                )

                VolumeIconSettingView(
                    iconData: store.project.volumeIconData,
                    chooseAction: chooseVolumeIcon,
                    useDefaultAction: useDefaultVolumeIcon
                )

                Picker(
                    "Gatekeeper：",
                    selection: store.undoableBinding(\.gatekeeper, actionName: "修改 Gatekeeper 设置")
                ) {
                    ForEach(GatekeeperMode.allCases) { mode in
                        Text(mode.localizedLabel).tag(mode)
                    }
                }

                if store.project.gatekeeper != .none {
                    LabeledContent("签名证书：") {
                        HStack {
                            Picker(
                                "",
                                selection: store.undoableBinding(\.signingIdentity, actionName: "修改签名身份")
                            ) {
                                Text("未选择").tag("")
                                ForEach(store.signingIdentities, id: \.self) { identity in
                                    Text(identity).tag(identity)
                                }
                            }
                            .labelsHidden()
                            if store.project.signingIdentity.isEmpty {
                                Text("必填")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                if store.project.gatekeeper == .signAndNotarize {
                    LabeledContent("Apple ID：") {
                        HStack {
                            Picker("", selection: appleIDBinding) {
                                Text("未选择").tag("")
                                ForEach(store.notaryAppleIDs, id: \.self) { appleID in
                                    Text(appleID).tag(ProjectStore.notaryProfileName(for: appleID))
                                }
                                Divider()
                                Text("输入 Apple ID 凭据…").tag("__add__")
                            }
                            .labelsHidden()
                            if store.project.notaryProfile.isEmpty {
                                Text("必填")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                Picker(
                    "格式：",
                    selection: store.undoableBinding(\.fileSystem, actionName: "修改文件系统")
                ) {
                    ForEach(FileSystemChoice.allCases) { fs in
                        Text(fs.localizedLabel).tag(fs)
                    }
                }

                Picker(
                    "压缩：",
                    selection: store.undoableBinding(\.compression, actionName: "修改压缩格式")
                ) {
                    ForEach(CompressionChoice.allCases) { compression in
                        Text(compression.localizedLabel).tag(compression)
                    }
                }

                Picker(
                    "映像大小：",
                    selection: store.undoableBinding(\.imageSizeAuto, actionName: "修改映像大小")
                ) {
                    Text("自动").tag(true)
                    Text("自定…").tag(false)
                }
                if !store.project.imageSizeAuto {
                    LabeledContent("大小 (MB)：") {
                        TextField(
                            "",
                            value: store.undoableBinding(\.customSizeMB, actionName: "修改映像大小"),
                            format: .number
                        )
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                    }
                }

                Picker(
                    "加密：",
                    selection: store.undoableBinding(\.encryption, actionName: "修改加密设置")
                ) {
                    ForEach(EncryptionMode.allCases) { mode in
                        Text(mode.localizedLabel).tag(mode)
                    }
                }
                if store.project.encryption != .none {
                    SecureField("口令：", text: $store.encryptionPassword,
                                prompt: Text("仅保存在内存中，不写入工程文件"))
                }
            }
            .formStyle(.grouped).scrollContentBackground(.hidden)
            .frame(maxWidth: .infinity)

            Divider()

            SummaryPanel()
                .frame(width: 230)
        }
        .onAppear {
            store.loadSigningIdentities()
            store.loadNotaryAppleIDs()
        }
        .sheet(isPresented: $showAppleIDSheet) {
            AppleIDSetupSheet(isPresented: $showAppleIDSheet)
        }
    }

    private func chooseVolumeIcon() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.icns, .png, .jpeg, .tiff]
        panel.allowsMultipleSelection = false
        panel.message = String(
            localized: "选择一张 1024×1024 的正方形图片，它会被完整印满硬盘标签面",
            locale: AppLanguageStore.shared.locale
        )
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url) else { return }

        guard let image = NSImage(data: data) else { return }
        if let problem = VolumeIcon.validateBadge(image) {
            let alert = NSAlert()
            alert.messageText = String(
                localized: "这张图片不符合卷图标要求",
                locale: AppLanguageStore.shared.locale
            )
            alert.informativeText = problem
            alert.alertStyle = .warning
            alert.runModal()
            return
        }
        store.updateProject(actionName: "修改卷图标") { $0.volumeIconData = data }
    }

    private func useDefaultVolumeIcon() {
        store.updateProject(actionName: "修改卷图标") { $0.volumeIconData = nil }
    }
}

// MARK: - 公证 Apple ID 设置面板（对应 DMG Canvas 的 Setup Apple ID for Notarization）

private struct AppleIDSetupSheet: View {
    @EnvironmentObject var store: ProjectStore
    @Binding var isPresented: Bool

    @State private var appleID = ""
    @State private var teamID = ""
    @State private var password = ""
    @State private var isValidating = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        !appleID.trimmingCharacters(in: .whitespaces).isEmpty
            && !teamID.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.trimmingCharacters(in: .whitespaces).isEmpty
            && !isValidating
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.blue)
                Text("为公证设置 Apple ID")
                    .font(.headline)
            }
            .padding(.top, 4)

            Text("要对磁盘映像及其内容进行公证，DMGplayer 需要你的 Apple ID、Team ID 和一个“App 专用密码”来与 Apple 服务通信。凭据会安全地保存在钥匙串中。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Grid(alignment: .trailing, horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    Text("Apple ID：")
                    TextField("", text: $appleID, prompt: Text("必填"))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 260)
                }
                GridRow {
                    Text("开发者 Team ID：")
                    TextField("", text: $teamID, prompt: Text("XXXXXXXXXX"))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 260)
                }
                GridRow {
                    Text("App 专用密码：")
                    SecureField("", text: $password, prompt: Text("必填"))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 260)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Team ID 是一个 10 位字符的标识，可以在 Apple 开发者账户的会员详情中找到。")
                Text("如何生成 App 专用密码").fontWeight(.semibold)
                Text("1. 登录 account.apple.com\n2. 在“登录与安全”中选择“App 专用密码”\n3. 点按“添加”按钮，然后按屏幕上的步骤操作")
            }
            .font(.system(size: 11.5))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("取消") { isPresented = false }
                Button {
                    submit()
                } label: {
                    if isValidating {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("验证中…")
                        }
                    } else {
                        Text("添加 Apple ID")
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func submit() {
        isValidating = true
        errorMessage = nil
        let id = appleID.trimmingCharacters(in: .whitespaces)
        let team = teamID.trimmingCharacters(in: .whitespaces)
        let pass = password.trimmingCharacters(in: .whitespaces)
        Task {
            do {
                try await store.addNotaryCredential(appleID: id, teamID: team, password: pass)
                isPresented = false
            } catch {
                errorMessage = "验证失败：\(error.localizedDescription)"
            }
            isValidating = false
        }
    }
}

// MARK: - 右侧摘要栏

private struct SummaryPanel: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject private var languageStore: AppLanguageStore

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                if let data = store.project.volumeIconData {
                    CompositeVolumeIconView(badgeData: data)
                        .frame(width: 120, height: 120)
                } else {
                    DriveIconView()
                        .frame(width: 120, height: 120)
                }
                let volumeName = store.displayedVolumeName(
                    localizedDefault: languageStore.defaultVolumeName
                )
                Text(volumeName.isEmpty ? "未命名" : volumeName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(volumeName.isEmpty ? .secondary : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            VStack(alignment: .leading, spacing: 10) {
                summaryRow(
                    symbol: store.project.gatekeeper == .none ? "shield.slash.fill" : "checkmark.shield.fill",
                    color: store.project.gatekeeper == .none ? .orange : .green,
                    text: "代码签名 \(store.project.gatekeeper == .none ? "关" : "开")"
                )
                summaryRow(
                    symbol: store.project.gatekeeper == .signAndNotarize ? "checkmark.seal.fill" : "seal",
                    color: store.project.gatekeeper == .signAndNotarize ? .green : .orange,
                    text: "公证 \(store.project.gatekeeper == .signAndNotarize ? "开" : "关")"
                )
                summaryRow(symbol: "internaldrive.fill", color: .blue,
                           text: store.project.fileSystem.summaryName)
                summaryRow(symbol: "doc.zipper", color: .cyan,
                           text: "压缩：\(store.project.compression.summaryName)")
                if store.project.encryption != .none {
                    summaryRow(symbol: "lock.fill", color: .purple,
                               text: store.project.encryption == .aes128 ? "AES-128 加密" : "AES-256 加密")
                }
                if !store.project.licenses.isEmpty {
                    summaryRow(symbol: "doc.text.fill", color: .indigo,
                               text: "许可协议 ×\(store.project.licenses.count)")
                }
                summaryRow(symbol: "apple.logo", color: .primary,
                           text: store.project.minMacOSText)
            }
            .font(.system(size: 12))

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background {
            if colorScheme == .light {
                Color(nsColor: .controlBackgroundColor)
            } else {
                Rectangle().fill(.thinMaterial)
            }
        }
    }

    private func summaryRow(symbol: String, color: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 18)
            Text(text)
        }
    }
}
