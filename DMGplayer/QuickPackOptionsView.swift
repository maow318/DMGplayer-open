//
//  QuickPackOptionsView.swift
//  DMGplayer
//

import SwiftUI

struct QuickPackOptionsView: View {
    @ObservedObject var store: QuickPackStore
    @FocusState private var isVolumeNameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("打包设置", systemImage: "slider.horizontal.3")
                .font(.subheadline)
                .bold()

            Divider()

            LabeledContent("卷名称") {
                TextField("磁盘映像名称", text: $store.volumeName)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
                    .frame(width: 200, height: 28)
                    .background {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.primary.opacity(isVolumeNameFocused ? 0.10 : 0.06))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(
                                Color.primary.opacity(isVolumeNameFocused ? 0.30 : 0.12)
                            )
                    }
                    .focused($isVolumeNameFocused)
            }

            Divider()

            ZStack {
                HStack {
                    Text("操作")
                    Spacer()
                }

                HStack(spacing: 8) {
                    if store.buildController.isRunning {
                        Button("取消", role: .cancel, action: store.buildController.cancel)
                    }
                    Button("开始打包", systemImage: "shippingbox.fill", action: store.startBuild)
                        .buttonStyle(.bordered)
                        .tint(Color.primary)
                        .disabled(!store.canStartBuild)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 28)
        }
        .padding(12)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
    }
}
