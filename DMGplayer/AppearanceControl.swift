//
//  AppearanceControl.swift
//  DMGplayer
//

import SwiftUI

struct AppearanceControl: View {
    @Binding var selection: AppAppearance
    @State private var isPresented = false

    var body: some View {
        Button("外观", systemImage: selection.systemImage) {
            isPresented.toggle()
        }
        .labelStyle(.iconOnly)
        .help(Text(selection.localizedTitle))
        .popover(isPresented: $isPresented, arrowEdge: .leading) {
            AppearancePicker(selection: $selection, isPresented: $isPresented)
        }
    }
}
