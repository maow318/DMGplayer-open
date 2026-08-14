//
//  DefaultVolumeName.swift
//  DMGplayer
//

import Foundation

/// The built-in volume name is presentation content, not user-authored data.
/// Keep its stable source key here so new and legacy documents can distinguish
/// it from a custom name that must never be overwritten by a language change.
nonisolated enum DefaultVolumeName {
    static let localizationKey = "我的软件 DMG"

    private static let recognizedValues: Set<String> = [
        localizationKey,
        "我的软件DMG",       // Legacy Simplified Chinese default.
        "我的軟體 DMG",
        "My App DMG",
        "マイアプリ DMG",
        "내 앱 DMG",
    ]

    static func isRecognized(_ value: String) -> Bool {
        recognizedValues.contains(value)
    }
}
