//
//  AppLanguageTests.swift
//  DMGplayerTests
//

import XCTest

@testable import DMGplayer

@MainActor
final class AppLanguageTests: XCTestCase {
    func testDefaultsToFollowingTheSystem() {
        let defaults = isolatedDefaults()
        let store = AppLanguageStore(defaults: defaults)

        XCTAssertEqual(store.selection, .system)
        XCTAssertEqual(store.locale, .autoupdatingCurrent)
    }

    func testExplicitLanguagePersistsAndRestores() {
        let defaults = isolatedDefaults()
        let store = AppLanguageStore(defaults: defaults)

        store.selection = .japanese

        XCTAssertEqual(defaults.string(forKey: AppLanguageStore.storageKey), "japanese")
        XCTAssertEqual(AppLanguageStore(defaults: defaults).selection, .japanese)
        XCTAssertEqual(store.locale.identifier, "ja")
    }

    func testEverySupportedLanguageHasAStableLocaleIdentifier() {
        XCTAssertNil(AppLanguage.system.localeIdentifier)
        XCTAssertEqual(AppLanguage.simplifiedChinese.localeIdentifier, "zh-Hans")
        XCTAssertEqual(AppLanguage.traditionalChinese.localeIdentifier, "zh-Hant")
        XCTAssertEqual(AppLanguage.english.localeIdentifier, "en")
        XCTAssertEqual(AppLanguage.japanese.localeIdentifier, "ja")
        XCTAssertEqual(AppLanguage.korean.localeIdentifier, "ko")
    }

    func testDefaultVolumeNameUsesTheSelectedLanguage() {
        let defaults = isolatedDefaults()
        let store = AppLanguageStore(defaults: defaults)

        store.selection = .english
        XCTAssertEqual(store.defaultVolumeName, "My App DMG")

        store.selection = .japanese
        XCTAssertEqual(store.defaultVolumeName, "マイアプリ DMG")
    }

    func testDefaultVolumeNameFollowsLanguageUntilTheUserEditsIt() {
        var project = DMGProject()
        project.localizeDefaultVolumeName(to: "My App DMG")
        XCTAssertEqual(project.volumeName, "My App DMG")
        XCTAssertTrue(project.shouldLocalizeDefaultVolumeName)

        project.volumeName = "Acme Installer"
        project.localizeDefaultVolumeName(to: "マイアプリ DMG")
        XCTAssertEqual(project.volumeName, "Acme Installer")
        XCTAssertFalse(project.shouldLocalizeDefaultVolumeName)
    }

    func testLegacyDefaultVolumeNameIsRecognizedAfterDecoding() throws {
        var project = DMGProject()
        project.volumeName = "我的软件DMG"
        project.volumeNameUsesLocalizedDefault = nil

        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(DMGProject.self, from: data)

        XCTAssertTrue(decoded.shouldLocalizeDefaultVolumeName)
    }

    func testProjectStoreTracksLanguageWithoutOverwritingACustomName() {
        let defaults = isolatedDefaults()
        let languageStore = AppLanguageStore(defaults: defaults)
        languageStore.selection = .english

        var legacyProject = DMGProject()
        legacyProject.volumeName = "我的软件DMG"
        legacyProject.volumeNameUsesLocalizedDefault = nil
        let projectStore = ProjectStore(
            project: legacyProject,
            languageStore: languageStore
        )
        XCTAssertEqual(projectStore.project.volumeName, "My App DMG")
        XCTAssertEqual(
            projectStore.displayedVolumeName(localizedDefault: "My App DMG"),
            "My App DMG"
        )

        languageStore.selection = .japanese
        XCTAssertEqual(projectStore.project.volumeName, "マイアプリ DMG")

        projectStore.project.volumeName = "Acme Installer"
        languageStore.selection = .korean
        XCTAssertEqual(projectStore.project.volumeName, "Acme Installer")

        projectStore.project.volumeName = "My App DMG"
        languageStore.selection = .japanese
        XCTAssertEqual(projectStore.project.volumeName, "My App DMG")
    }

    func testLicenseLanguageNamesFollowTheInterfaceLocale() throws {
        let britishEnglish = try XCTUnwrap(LicenseLanguage.byKey["en-GB"])

        XCTAssertEqual(
            britishEnglish.displayName(in: Locale(identifier: "en")),
            "English (United Kingdom)"
        )
        XCTAssertEqual(
            britishEnglish.displayName(in: Locale(identifier: "ja")),
            "英語（イギリス）"
        )
        XCTAssertEqual(
            britishEnglish.displayName(in: Locale(identifier: "ko")),
            "영어(영국)"
        )
        XCTAssertEqual(
            britishEnglish.displayName(in: Locale(identifier: "zh-Hant")),
            "英文（英國）"
        )
    }

    func testBuiltInTemplateNamesAreLocalizedButCustomNamesStayVerbatim() throws {
        let blank = try XCTUnwrap(BuiltInProjectTemplates.all.first { $0.name == "空白" })
        let defaults = isolatedDefaults()
        let languageStore = AppLanguageStore(defaults: defaults)
        languageStore.selection = .english
        XCTAssertEqual(blank.displayName(localize: languageStore.localized), "Blank")
        languageStore.selection = .japanese
        XCTAssertEqual(blank.displayName(localize: languageStore.localized), "空白")

        let custom = ProjectTemplate(
            id: UUID(),
            name: "团队模板",
            project: DMGProject(),
            isBuiltIn: false
        )
        languageStore.selection = .english
        XCTAssertEqual(custom.displayName(localize: languageStore.localized), "团队模板")
    }

    func testApplyingBuiltInTemplateLocalizesItsInstructionText() throws {
        let defaults = isolatedDefaults()
        let languageStore = AppLanguageStore(defaults: defaults)
        languageStore.selection = .english
        let projectStore = ProjectStore(languageStore: languageStore)
        let instructionsTemplate = try XCTUnwrap(
            BuiltInProjectTemplates.all.first { $0.name == "带说明文字" }
        )

        projectStore.apply(template: instructionsTemplate)

        XCTAssertEqual(
            projectStore.project.textObjects.first?.text,
            "Drag the App to the Applications folder"
        )
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "DMGplayerTests.AppLanguage.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
