//
//  VolumeIconSettingView.swift
//  DMGplayer
//

import SwiftUI

struct VolumeIconSettingView: View {
    let iconData: Data?
    let chooseAction: () -> Void
    let useDefaultAction: () -> Void

    var body: some View {
        LabeledContent("卷图标：") {
            VStack(alignment: .trailing, spacing: 8) {
                HStack(alignment: .center, spacing: 12) {
                    Text("需要 1024×1024 正方形图片\n将完整印满硬盘标签面")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: true, vertical: true)

                    iconPreview
                }

                HStack(spacing: 8) {
                    Button("选择…", action: chooseAction)
                    Button("使用默认", action: useDefaultAction)
                        .disabled(iconData == nil)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var iconPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(.background)
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(.quaternary)

            if let iconData {
                CompositeVolumeIconView(badgeData: iconData)
                    .padding(4)
            } else {
                DriveIconView()
                    .padding(4)
            }
        }
        .frame(width: 64, height: 64)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(iconData == nil ? "默认卷图标预览" : "自定义卷图标预览")
    }
}

#Preview {
    Form {
        VolumeIconSettingView(
            iconData: nil,
            chooseAction: {},
            useDefaultAction: {}
        )
    }
    .formStyle(.grouped)
    .frame(width: 600)
}
