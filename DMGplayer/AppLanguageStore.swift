//
//  AppLanguageStore.swift
//  DMGplayer
//

import Combine
import Foundation

@MainActor
final class AppLanguageStore: ObservableObject {
    static let shared = AppLanguageStore()
    static let storageKey = "DMGplayer.interfaceLanguage"

    @Published var selection: AppLanguage {
        didSet {
            guard selection != oldValue else { return }
            defaults.set(selection.rawValue, forKey: Self.storageKey)
        }
    }

    var locale: Locale {
        guard let identifier = selection.localeIdentifier else {
            return .autoupdatingCurrent
        }
        return Locale(identifier: identifier)
    }

    var currentLanguageName: String {
        if selection == .system {
            return localized("跟随系统")
        }
        return selection.nativeName
    }

    var defaultVolumeName: String {
        defaultVolumeName(for: selection)
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedValue = defaults.string(forKey: Self.storageKey)
        selection = storedValue.flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    /// Localizes dynamic AppKit strings using the same in-app language as SwiftUI.
    /// `Bundle.main.localizedString` alone cannot honor a language changed at runtime.
    func localized(_ key: String) -> String {
        localized(key, for: selection)
    }

    func localized(_ key: String, for language: AppLanguage) -> String {
        localizationBundle(for: language)
            .localizedString(forKey: key, value: key, table: "Localizable")
    }

    func defaultVolumeName(for language: AppLanguage) -> String {
        localized(DefaultVolumeName.localizationKey, for: language)
    }

    private func localizationBundle(for language: AppLanguage) -> Bundle {
        guard let identifier = language.localeIdentifier,
              let url = Bundle.main.url(forResource: identifier, withExtension: "lproj"),
              let bundle = Bundle(url: url) else {
            return .main
        }
        return bundle
    }
}
