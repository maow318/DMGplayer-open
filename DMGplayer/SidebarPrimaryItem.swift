//
//  SidebarPrimaryItem.swift
//  DMGplayer
//

enum SidebarPrimaryItem: CaseIterable, Identifiable {
    case diskImage
    case preflight

    var id: Self { self }

    var selection: SidebarSelection {
        switch self {
        case .diskImage:
            .diskImage
        case .preflight:
            .preflight
        }
    }
}
