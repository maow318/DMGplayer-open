//
//  AboutView.swift
//  DMGplayer
//

import AppKit
import SwiftUI

struct AboutView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    private static let sourceCodeURL = URL(
        string: "https://github.com/maow318/DMGplayer-open"
    )!
    private static let commercialLicenseURL = URL(
        string: "https://github.com/maow318/DMGplayer-open/issues/new?template=commercial-license.yml"
    )!

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 28)

            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 82, height: 82)
                .accessibilityHidden(true)

            Text("DMGplayer")
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 9)

            Text("版本 \(version)（\(build)）")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer(minLength: 16)

            VStack(spacing: 5) {
                Text(verbatim: "Copyright © 2026 DMGplayer contributors")
                Text(verbatim: "PolyForm Noncommercial 1.0.0 · No warranty")
                Text(verbatim: "Personal noncommercial use is free")
                Text(verbatim: "Commercial use requires written approval and a license fee")
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    Link(destination: Self.sourceCodeURL) {
                        Label {
                            Text(verbatim: "Source Code")
                        } icon: {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                        }
                    }
                    .accessibilityHint("Opens the public source repository")

                    Link(destination: Self.commercialLicenseURL) {
                        Label {
                            Text(verbatim: "Commercial License")
                        } icon: {
                            Image(systemName: "doc.badge.gearshape")
                        }
                    }
                    .accessibilityHint("Opens a commercial license request on GitHub")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            Spacer(minLength: 16)
            Divider()

            HStack(spacing: 12) {
                Label("语言", systemImage: "globe")
                    .foregroundStyle(.secondary)

                Spacer(minLength: 20)

                Picker("语言", selection: $languageStore.selection) {
                    Text("跟随系统")
                        .tag(AppLanguage.system)

                    Divider()

                    ForEach(AppLanguage.allCases.filter { $0 != .system }) { language in
                        Text(language.nativeName)
                            .tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 156, alignment: .trailing)
                .accessibilityLabel("界面语言")
                .accessibilityValue(languageStore.currentLanguageName)
            }
            .controlSize(.regular)
            .padding(.horizontal, 22)
            .frame(height: 54)
        }
        .frame(width: 360, height: 382)
        .background(Color(nsColor: .windowBackgroundColor))
        .background {
            WindowTitleUpdater(title: languageStore.localized("关于 DMGplayer"))
                .frame(width: 0, height: 0)
        }
    }
}

/// A SwiftUI `Window` keeps its scene title after a runtime locale change.
/// Keep the hidden title bar's accessibility title and Window menu entry in sync.
private struct WindowTitleUpdater: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            view.window?.title = title
        }
    }
}

struct DMGplayerCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var languageStore: AppLanguageStore

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(languageStore.localized("关于 DMGplayer")) {
                openWindow(id: DMGplayerApp.aboutWindowID)
            }
        }
    }
}
