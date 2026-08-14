//
//  LicenseSupport.swift
//  DMGplayer
//
//  多语言许可协议（SLA）。构建时生成经典的 LPic / STR# / RTF 资源，
//  用 `hdiutil udifrez -xml` 注入最终 DMG —— 与 DMG Canvas 的效果一致：
//  挂载映像前 DiskImageMounter 会弹出许可协议窗口。
//

import AppKit
import Foundation
import SwiftUI

// MARK: - 语言表

nonisolated struct LicenseLanguage: Identifiable, Equatable {
    let key: String          // 存储用标识
    let menuName: String     // 菜单显示（跟随 DMG Canvas 的英文菜单，用中文）
    let nativeName: String   // 语言的本地名称（进 STR# 资源）
    let flag: String
    let regionCode: UInt16   // 经典 Mac OS 地区码（Script.h）
    let cfEncoding: UInt32   // STR# 字符串的传统编码（kCFStringEncodingMac…）
    let doubleByte: Bool
    // 默认按钮文案
    let agree: String
    let disagree: String
    let printText: String
    let save: String
    let prompt: String

    var id: String { key }

    var encoding: String.Encoding {
        String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(cfEncoding)))
    }

    /// 资源目录里的旗帜图片名
    var flagImageName: String { "flag-\(key)" }

    /// UI-facing language name in DMGplayer's current interface language.
    /// The stored `menuName` remains for legacy project compatibility only.
    func displayName(in locale: Locale) -> String {
        locale.localizedString(forIdentifier: key) ?? nativeName
    }

    /// 资源分支里的资源名必须是 MacRoman 可编码的 ASCII
    var englishName: String {
        switch key {
        case "zh-Hans": return "Simplified Chinese"
        case "zh-Hant": return "Traditional Chinese"
        case "da": return "Danish"
        case "nl": return "Dutch"
        case "en": return "English"
        case "fi": return "Finnish"
        case "fr": return "French"
        case "de": return "German"
        case "he": return "Hebrew"
        case "it": return "Italian"
        case "ja": return "Japanese"
        case "ko": return "Korean"
        case "no": return "Norwegian"
        case "pt": return "Portuguese"
        case "ru": return "Russian"
        case "es": return "Spanish"
        case "sv": return "Swedish"
        case "en-GB": return "British English"
        case "pt-BR": return "Brazilian Portuguese"
        case "ar": return "Arabic"
        case "tr": return "Turkish"
        case "el": return "Greek"
        case "th": return "Thai"
        case "pl": return "Polish"
        case "cs": return "Czech"
        case "hu": return "Hungarian"
        case "uk": return "Ukrainian"
        default: return "English"
        }
    }

    static let byKey: [String: LicenseLanguage] = Dictionary(uniqueKeysWithValues: all.map { ($0.key, $0) })

    static let all: [LicenseLanguage] = [
        LicenseLanguage(key: "zh-Hans", menuName: "简体中文", nativeName: "简体中文", flag: "🇨🇳",
                        regionCode: 52, cfEncoding: 25, doubleByte: true,
                        agree: "同意", disagree: "不同意", printText: "打印", save: "存储",
                        prompt: "如果您同意本许可协议的条款，请按“同意”来安装此软件。如果您不同意，请按“不同意”。"),
        LicenseLanguage(key: "zh-Hant", menuName: "繁体中文", nativeName: "繁體中文", flag: "🇹🇼",
                        regionCode: 53, cfEncoding: 2, doubleByte: true,
                        agree: "同意", disagree: "不同意", printText: "列印", save: "儲存",
                        prompt: "如果您同意本許可協議的條款，請按「同意」來安裝此軟體。如果您不同意，請按「不同意」。"),
        LicenseLanguage(key: "da", menuName: "丹麦文", nativeName: "Dansk", flag: "🇩🇰",
                        regionCode: 9, cfEncoding: 0, doubleByte: false,
                        agree: "Enig", disagree: "Uenig", printText: "Udskriv", save: "Arkiver",
                        prompt: "Hvis du accepterer betingelserne i licensaftalen, skal du klikke på “Enig” for at installere softwaren. Klik på “Uenig” for at annullere installationen."),
        LicenseLanguage(key: "nl", menuName: "荷兰文", nativeName: "Nederlands", flag: "🇳🇱",
                        regionCode: 5, cfEncoding: 0, doubleByte: false,
                        agree: "Akkoord", disagree: "Niet akkoord", printText: "Print", save: "Bewaar",
                        prompt: "Indien u akkoord gaat met de voorwaarden van deze licentie, kunt u op ‘Akkoord’ klikken om de programmatuur te installeren. Indien u niet akkoord gaat, klikt u op ‘Niet akkoord’."),
        LicenseLanguage(key: "en", menuName: "英文", nativeName: "English", flag: "🇺🇸",
                        regionCode: 0, cfEncoding: 0, doubleByte: false,
                        agree: "Agree", disagree: "Disagree", printText: "Print", save: "Save",
                        prompt: "If you agree with the terms of this license, press \"Agree\" to install the software. If you do not agree, press \"Disagree\"."),
        LicenseLanguage(key: "fi", menuName: "芬兰文", nativeName: "Suomi", flag: "🇫🇮",
                        regionCode: 17, cfEncoding: 0, doubleByte: false,
                        agree: "Hyväksyn", disagree: "En hyväksy", printText: "Tulosta", save: "Tallenna",
                        prompt: "Hyväksy lisenssisopimuksen ehdot osoittamalla “Hyväksy”. Jos et hyväksy sopimuksen ehtoja, osoita “En hyväksy”."),
        LicenseLanguage(key: "fr", menuName: "法文", nativeName: "Français", flag: "🇫🇷",
                        regionCode: 1, cfEncoding: 0, doubleByte: false,
                        agree: "Accepter", disagree: "Refuser", printText: "Imprimer", save: "Enregistrer",
                        prompt: "Si vous acceptez les termes de la présente licence, cliquez sur « Accepter » afin d'installer le logiciel. Si vous n'êtes pas d'accord avec les termes de la licence, cliquez sur « Refuser »."),
        LicenseLanguage(key: "de", menuName: "德文", nativeName: "Deutsch", flag: "🇩🇪",
                        regionCode: 3, cfEncoding: 0, doubleByte: false,
                        agree: "Akzeptieren", disagree: "Ablehnen", printText: "Drucken", save: "Sichern",
                        prompt: "Klicken Sie in „Akzeptieren“, wenn Sie mit den Bestimmungen des Software-Lizenzvertrags einverstanden sind. Falls nicht, bitte „Ablehnen“ anklicken."),
        LicenseLanguage(key: "he", menuName: "希伯来文", nativeName: "עברית", flag: "🇮🇱",
                        regionCode: 13, cfEncoding: 5, doubleByte: false,
                        agree: "מסכים", disagree: "לא מסכים", printText: "הדפס", save: "שמור",
                        prompt: "אם אתה מסכים לתנאי הרישיון, לחץ על \"מסכים\" כדי להתקין את התוכנה. אם אינך מסכים, לחץ על \"לא מסכים\"."),
        LicenseLanguage(key: "it", menuName: "意大利文", nativeName: "Italiano", flag: "🇮🇹",
                        regionCode: 4, cfEncoding: 0, doubleByte: false,
                        agree: "Accetto", disagree: "Rifiuto", printText: "Stampa", save: "Registra",
                        prompt: "Se accetti le condizioni di questa licenza, fai clic su “Accetto” per installare il software. Altrimenti fai clic su “Rifiuto”."),
        LicenseLanguage(key: "ja", menuName: "日文", nativeName: "日本語", flag: "🇯🇵",
                        regionCode: 14, cfEncoding: 1, doubleByte: true,
                        agree: "同意します", disagree: "同意しません", printText: "印刷", save: "保存",
                        prompt: "本ソフトウェアをインストールするには、使用許諾契約の条項に同意して「同意します」を押してください。同意しない場合は「同意しません」を押してください。"),
        LicenseLanguage(key: "ko", menuName: "韩文", nativeName: "한국어", flag: "🇰🇷",
                        regionCode: 51, cfEncoding: 3, doubleByte: true,
                        agree: "동의", disagree: "동의 안 함", printText: "프린트", save: "저장",
                        prompt: "사용 계약의 조건에 동의하면 \"동의\"를 눌러 소프트웨어를 설치하십시오. 동의하지 않는다면 \"동의 안 함\"을 누르십시오."),
        LicenseLanguage(key: "no", menuName: "挪威文", nativeName: "Norsk", flag: "🇳🇴",
                        regionCode: 12, cfEncoding: 0, doubleByte: false,
                        agree: "Enig", disagree: "Ikke enig", printText: "Skriv ut", save: "Arkiver",
                        prompt: "Hvis De er enig i bestemmelsene i denne lisensavtalen, klikker De på “Enig”-knappen for å installere programvaren. Hvis De ikke er enig, klikker De på “Ikke enig”."),
        LicenseLanguage(key: "pt", menuName: "葡萄牙文", nativeName: "Português", flag: "🇵🇹",
                        regionCode: 10, cfEncoding: 0, doubleByte: false,
                        agree: "Concordar", disagree: "Discordar", printText: "Imprimir", save: "Guardar",
                        prompt: "Se está de acordo com os termos desta licença, prima “Concordar” para instalar o software. Se não está de acordo, prima “Discordar”."),
        LicenseLanguage(key: "ru", menuName: "俄文", nativeName: "Русский", flag: "🇷🇺",
                        regionCode: 49, cfEncoding: 7, doubleByte: false,
                        agree: "Согласен", disagree: "Не согласен", printText: "Печать", save: "Сохранить",
                        prompt: "Если вы согласны с условиями данной лицензии, нажмите «Согласен», чтобы установить программное обеспечение. Если вы не согласны, нажмите «Не согласен»."),
        LicenseLanguage(key: "es", menuName: "西班牙文", nativeName: "Español", flag: "🇪🇸",
                        regionCode: 8, cfEncoding: 0, doubleByte: false,
                        agree: "Aceptar", disagree: "No aceptar", printText: "Imprimir", save: "Guardar",
                        prompt: "Si está de acuerdo con los términos de esta licencia, pulse “Aceptar” para instalar el software. En el supuesto de que no esté de acuerdo con los términos de esta licencia, pulse “No aceptar”."),
        LicenseLanguage(key: "sv", menuName: "瑞典文", nativeName: "Svensk", flag: "🇸🇪",
                        regionCode: 7, cfEncoding: 0, doubleByte: false,
                        agree: "Godkänns", disagree: "Avböjs", printText: "Skriv ut", save: "Spara",
                        prompt: "Om Du godkänner licensvillkoren klicka på “Godkänns” för att installera programprodukten. Om Du inte godkänner licensvillkoren, klicka på “Avböjs”."),
        // ——— 以下为超出 DMG Canvas 原版的扩展语言 ———
        LicenseLanguage(key: "en-GB", menuName: "英文（英国）", nativeName: "British English", flag: "🇬🇧",
                        regionCode: 2, cfEncoding: 0, doubleByte: false,
                        agree: "Agree", disagree: "Disagree", printText: "Print", save: "Save",
                        prompt: "If you agree with the terms of this licence, press \"Agree\" to install the software. If you do not agree, press \"Disagree\"."),
        LicenseLanguage(key: "pt-BR", menuName: "葡萄牙文（巴西）", nativeName: "Português (Brasil)", flag: "🇧🇷",
                        regionCode: 71, cfEncoding: 0, doubleByte: false,
                        agree: "Concordar", disagree: "Discordar", printText: "Imprimir", save: "Salvar",
                        prompt: "Se você está de acordo com os termos desta licença, pressione “Concordar” para instalar o software. Se não está de acordo, pressione “Discordar”."),
        LicenseLanguage(key: "ar", menuName: "阿拉伯文", nativeName: "العربية", flag: "🇸🇦",
                        regionCode: 16, cfEncoding: 4, doubleByte: false,
                        agree: "أوافق", disagree: "لا أوافق", printText: "طباعة", save: "حفظ",
                        prompt: "إذا كنت توافق على شروط هذه الرخصة، فاضغط على \"أوافق\" لتثبيت البرنامج. إذا كنت لا توافق، فاضغط على \"لا أوافق\"."),
        LicenseLanguage(key: "tr", menuName: "土耳其文", nativeName: "Türkçe", flag: "🇹🇷",
                        regionCode: 24, cfEncoding: 35, doubleByte: false,
                        agree: "Kabul Ediyorum", disagree: "Kabul Etmiyorum", printText: "Yazdır", save: "Kaydet",
                        prompt: "Bu lisansın koşullarını kabul ediyorsanız, yazılımı yüklemek için “Kabul Ediyorum” düğmesine basın. Kabul etmiyorsanız “Kabul Etmiyorum” düğmesine basın."),
        LicenseLanguage(key: "el", menuName: "希腊文", nativeName: "Ελληνικά", flag: "🇬🇷",
                        regionCode: 20, cfEncoding: 6, doubleByte: false,
                        agree: "Συμφωνώ", disagree: "Διαφωνώ", printText: "Εκτύπωση", save: "Αποθήκευση",
                        prompt: "Εάν συμφωνείτε με τους όρους της παρούσας άδειας, πατήστε «Συμφωνώ» για να εγκαταστήσετε το λογισμικό. Εάν διαφωνείτε, πατήστε «Διαφωνώ»."),
        LicenseLanguage(key: "th", menuName: "泰文", nativeName: "ไทย", flag: "🇹🇭",
                        regionCode: 54, cfEncoding: 21, doubleByte: false,
                        agree: "ยอมรับ", disagree: "ไม่ยอมรับ", printText: "พิมพ์", save: "บันทึก",
                        prompt: "หากคุณยอมรับเงื่อนไขของสัญญาอนุญาตนี้ ให้กด “ยอมรับ” เพื่อติดตั้งซอฟต์แวร์ หากไม่ยอมรับ ให้กด “ไม่ยอมรับ”"),
        LicenseLanguage(key: "pl", menuName: "波兰文", nativeName: "Polski", flag: "🇵🇱",
                        regionCode: 42, cfEncoding: 29, doubleByte: false,
                        agree: "Zgadzam się", disagree: "Nie zgadzam się", printText: "Drukuj", save: "Zachowaj",
                        prompt: "Jeśli zgadzasz się z warunkami tej licencji, naciśnij „Zgadzam się”, aby zainstalować oprogramowanie. Jeśli się nie zgadzasz, naciśnij „Nie zgadzam się”."),
        LicenseLanguage(key: "cs", menuName: "捷克文", nativeName: "Čeština", flag: "🇨🇿",
                        regionCode: 56, cfEncoding: 29, doubleByte: false,
                        agree: "Souhlasím", disagree: "Nesouhlasím", printText: "Tisk", save: "Uložit",
                        prompt: "Pokud souhlasíte s podmínkami této licence, stiskněte „Souhlasím“ a software se nainstaluje. Pokud nesouhlasíte, stiskněte „Nesouhlasím“."),
        LicenseLanguage(key: "hu", menuName: "匈牙利文", nativeName: "Magyar", flag: "🇭🇺",
                        regionCode: 43, cfEncoding: 29, doubleByte: false,
                        agree: "Elfogadom", disagree: "Nem fogadom el", printText: "Nyomtatás", save: "Mentés",
                        prompt: "Ha elfogadja a licenc feltételeit, nyomja meg az „Elfogadom” gombot a szoftver telepítéséhez. Ha nem fogadja el, nyomja meg a „Nem fogadom el” gombot."),
        LicenseLanguage(key: "uk", menuName: "乌克兰文", nativeName: "Українська", flag: "🇺🇦",
                        regionCode: 62, cfEncoding: 7, doubleByte: false,
                        agree: "Погоджуюся", disagree: "Не погоджуюся", printText: "Друк", save: "Зберегти",
                        prompt: "Якщо ви погоджуєтеся з умовами цієї ліцензії, натисніть «Погоджуюся», щоб установити програмне забезпечення. Якщо ні — натисніть «Не погоджуюся»."),
    ]
}

// MARK: - 旗帜视图（图片旗帜，缺图时回退 emoji）

struct FlagView: View {
    let language: LicenseLanguage

    var body: some View {
        if NSImage(named: language.flagImageName) != nil {
            Image(language.flagImageName)
        } else {
            Text(language.flag)
        }
    }
}

// MARK: - 资源生成（LPic / STR# / RTF → udifrez XML plist）

enum LicenseResourceBuilder {
    /// 新版 macOS 的协议语言菜单按语言合并地区变体（简/繁都显示为"中文"），
    /// 这几组同时存在时把更通用的变体排到前面，保证系统匹配/回退命中它
    static let mergedVariantPairs: [(primary: String, secondary: String, label: String)] = [
        ("zh-Hans", "zh-Hant", "简体中文 / 繁体中文"),
        ("en", "en-GB", "英文 / 英文（英国）"),
        ("pt", "pt-BR", "葡萄牙文 / 葡萄牙文（巴西）"),
    ]

    static func normalized(_ licenses: [DiskLicense]) -> [DiskLicense] {
        var result = licenses
        for pair in mergedVariantPairs {
            if let pi = result.firstIndex(where: { $0.languageKey == pair.primary }),
               let si = result.firstIndex(where: { $0.languageKey == pair.secondary }),
               si < pi {
                result.swapAt(pi, si)
            }
        }
        return result
    }

    /// 生成传给 `hdiutil udifrez -xml` 的 plist 数据
    static func plistData(for rawLicenses: [DiskLicense]) throws -> Data {
        let licenses = normalized(rawLicenses)
        guard !licenses.isEmpty else { throw BuildError(message: "没有许可协议") }

        var lpic = Data()
        appendU16(&lpic, licenses[0].language.regionCode)  // 默认语言
        appendU16(&lpic, UInt16(licenses.count))

        var strResources: [[String: Any]] = []
        var rtfResources: [[String: Any]] = []

        for (index, license) in licenses.enumerated() {
            let lang = license.language
            let resourceID = 5000 + index

            appendU16(&lpic, lang.regionCode)
            appendU16(&lpic, UInt16(index))          // 资源 ID 偏移（5000 + offset）
            appendU16(&lpic, lang.doubleByte ? 1 : 0)

            // STR#：6 个 pascal string —— 语言名、同意、不同意、打印、存储、提示语
            var str = Data()
            appendU16(&str, 6)
            let strings = [
                lang.nativeName,
                license.agree.isEmpty ? lang.agree : license.agree,
                license.disagree.isEmpty ? lang.disagree : license.disagree,
                license.printText.isEmpty ? lang.printText : license.printText,
                license.save.isEmpty ? lang.save : license.save,
                license.prompt.isEmpty ? lang.prompt : license.prompt,
            ]
            for s in strings {
                appendPascalString(&str, s, encoding: lang.encoding)
            }
            strResources.append([
                "Attributes": "0x0000",
                "Data": str,
                "ID": "\(resourceID)",
                "Name": lang.englishName,
            ])

            var rtf = license.rtfData
            if rtf.isEmpty {
                rtf = NSAttributedString(string: " ")
                    .rtf(from: NSRange(location: 0, length: 1)) ?? Data()
            }
            rtfResources.append([
                "Attributes": "0x0000",
                "Data": rtf,
                "ID": "\(resourceID)",
                "Name": "\(lang.englishName) SLA",
            ])
        }

        let root: [String: Any] = [
            "LPic": [[
                "Attributes": "0x0000",
                "Data": lpic,
                "ID": "5000",
                "Name": "",
            ]],
            "STR#": strResources,
            "RTF ": rtfResources,
        ]
        return try PropertyListSerialization.data(fromPropertyList: root, format: .xml, options: 0)
    }

    private static func appendU16(_ data: inout Data, _ value: UInt16) {
        var be = value.bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
    }

    private static func appendPascalString(_ data: inout Data, _ string: String, encoding: String.Encoding) {
        var bytes = string.data(using: encoding, allowLossyConversion: true) ?? Data()
        if bytes.count > 255 { bytes = bytes.prefix(255) }
        data.append(UInt8(bytes.count))
        data.append(bytes)
    }
}
