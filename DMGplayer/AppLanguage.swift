//
//  AppLanguage.swift
//  DMGplayer
//

import Foundation

/// The language used by DMGplayer's interface.
///
/// `system` deliberately stores no locale identifier. This keeps the default
/// aligned with the user's macOS language instead of taking a one-time snapshot.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case simplifiedChinese
    case traditionalChinese
    case english
    case japanese
    case korean

    var id: String { rawValue }

    var localeIdentifier: String? {
        switch self {
        case .system: nil
        case .simplifiedChinese: "zh-Hans"
        case .traditionalChinese: "zh-Hant"
        case .english: "en"
        case .japanese: "ja"
        case .korean: "ko"
        }
    }

    /// Language names stay in their own language so the menu remains usable
    /// even when the current interface language is unfamiliar.
    var nativeName: String {
        switch self {
        case .system: ""
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .english: "English"
        case .japanese: "日本語"
        case .korean: "한국어"
        }
    }
}
