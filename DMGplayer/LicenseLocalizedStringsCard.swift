//
//  LicenseLocalizedStringsCard.swift
//  DMGplayer
//
//  明暗模式共用的许可协议本地化文案卡片。
//

import SwiftUI

struct LicenseLocalizedStringsCard: View {
    @Environment(\.locale) private var locale
    @Binding var license: DiskLicense
    let language: LicenseLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("本地化字符串")
                    .font(.headline)
                Text("留空时使用\(language.displayName(in: locale))默认值")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    fieldLabel("同意")
                    TextField(language.agree, text: $license.agree)
                        .modifier(LicenseTextInputStyle())
                        .accessibilityLabel("同意按钮文字")
                    fieldLabel("打印")
                    TextField(language.printText, text: $license.printText)
                        .modifier(LicenseTextInputStyle())
                        .accessibilityLabel("打印按钮文字")
                }

                GridRow {
                    fieldLabel("不同意")
                    TextField(language.disagree, text: $license.disagree)
                        .modifier(LicenseTextInputStyle())
                        .accessibilityLabel("不同意按钮文字")
                    fieldLabel("存储")
                    TextField(language.save, text: $license.save)
                        .modifier(LicenseTextInputStyle())
                        .accessibilityLabel("存储按钮文字")
                }

                GridRow(alignment: .top) {
                    fieldLabel("提示语")
                        .padding(.top, 4)
                    TextField(language.prompt, text: $license.prompt, axis: .vertical)
                        .lineLimit(2...3)
                        .modifier(LicenseTextInputStyle())
                        .accessibilityLabel("许可协议提示语")
                        .gridCellColumns(3)
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.7))
        }
        .shadow(color: .black.opacity(0.045), radius: 7, y: 2)
    }

    private func fieldLabel(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(minWidth: 44, alignment: .trailing)
    }
}
