//
//  AppearancePicker.swift
//  DMGplayer
//

import SwiftUI

struct AppearancePicker: View {
    @Binding var selection: AppAppearance
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 2) {
            ForEach(AppAppearance.allCases) { appearance in
                Button {
                    selection = appearance
                    isPresented = false
                } label: {
                    HStack(spacing: 10) {
                        Label {
                            Text(appearance.localizedTitle)
                        } icon: {
                            Image(systemName: appearance.systemImage)
                        }
                        Spacer(minLength: 12)
                        Image(systemName: "checkmark")
                            .opacity(selection == appearance ? 1 : 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background {
                    if selection == appearance {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.accentColor.opacity(0.14))
                    }
                }
                .accessibilityAddTraits(selection == appearance ? .isSelected : [])
            }
        }
        .padding(8)
        .frame(width: 176)
    }
}
