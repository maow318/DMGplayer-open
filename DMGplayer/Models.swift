//
//  Models.swift
//  DMGplayer
//

import SwiftUI

// MARK: - 文件系统 / 压缩 / Gatekeeper / 加密

nonisolated enum FileSystemChoice: String, Codable, CaseIterable, Identifiable, Sendable {
    case apfs = "APFS"
    case hfs = "HFS+"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .apfs: return "Apple 文件系统（默认）"
        case .hfs: return "Mac OS 扩展格式"
        }
    }
    var localizedLabel: LocalizedStringResource {
        switch self {
        case .apfs: "Apple 文件系统（默认）"
        case .hfs: "Mac OS 扩展格式"
        }
    }
    var summaryName: String {
        self == .apfs ? "Apple File System" : "Mac OS Extended"
    }
    /// 最低可挂载的 macOS 版本
    var minMacOS: Double { self == .apfs ? 10.13 : 10.4 }
}

nonisolated enum CompressionChoice: String, Codable, CaseIterable, Identifiable, Sendable {
    case lzfse
    case zlib
    case bzip2
    case none

    var id: String { rawValue }
    var label: String {
        switch self {
        case .lzfse: return "LZFSE（默认）"
        case .zlib: return "zlib（兼容性最好）"
        case .bzip2: return "bzip2（体积更小）"
        case .none: return "不压缩（只读）"
        }
    }
    var localizedLabel: LocalizedStringResource {
        switch self {
        case .lzfse: "LZFSE（默认）"
        case .zlib: "zlib（兼容性最好）"
        case .bzip2: "bzip2（体积更小）"
        case .none: "不压缩（只读）"
        }
    }
    /// hdiutil convert -format
    var convertFormat: String {
        switch self {
        case .lzfse: return "ULFO"
        case .zlib: return "UDZO"
        case .bzip2: return "UDBZ"
        case .none: return "UDRO"
        }
    }
    var summaryName: String {
        switch self {
        case .lzfse: return "LZFSE"
        case .zlib: return "zlib"
        case .bzip2: return "bzip2"
        case .none: return "未压缩"
        }
    }
    var minMacOS: Double {
        switch self {
        case .lzfse: return 10.11
        case .zlib: return 10.4
        case .bzip2: return 10.4
        case .none: return 10.4
        }
    }
}

nonisolated enum GatekeeperMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case sign
    case signAndNotarize

    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "不签名也不公证"
        case .sign: return "代码签名"
        case .signAndNotarize: return "代码签名并公证"
        }
    }
    var localizedLabel: LocalizedStringResource {
        switch self {
        case .none: "不签名也不公证"
        case .sign: "代码签名"
        case .signAndNotarize: "代码签名并公证"
        }
    }
}

nonisolated enum EncryptionMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case aes128
    case aes256

    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "无"
        case .aes128: return "128 位 AES 加密"
        case .aes256: return "256 位 AES 加密（更安全，稍慢）"
        }
    }
    var localizedLabel: LocalizedStringResource {
        switch self {
        case .none: "无"
        case .aes128: "128 位 AES 加密"
        case .aes256: "256 位 AES 加密（更安全，稍慢）"
        }
    }
    var hdiutilName: String? {
        switch self {
        case .none: return nil
        case .aes128: return "AES-128"
        case .aes256: return "AES-256"
        }
    }
}

nonisolated enum LabelPosition: String, Codable, CaseIterable, Identifiable, Sendable {
    case bottom
    case right

    var id: String { rawValue }
    var label: String { self == .bottom ? "底部" : "右侧" }
    var localizedLabel: LocalizedStringResource {
        self == .bottom ? "底部" : "右侧"
    }
}

nonisolated enum BackgroundStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case color
    case mesh
    case image

    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "无"
        case .color: return "颜色"
        case .mesh: return "渐变"
        case .image: return "图片"
        }
    }
    var localizedLabel: LocalizedStringResource {
        switch self {
        case .none: "无"
        case .color: "颜色"
        case .mesh: "渐变"
        case .image: "图片"
        }
    }
}

nonisolated struct CodablePoint: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
}

// MARK: - Mesh 渐变预设（3×3 网格，9 色）

nonisolated struct MeshPreset: Identifiable, Equatable, Sendable {
    let name: String
    let localizedName: LocalizedStringResource
    let colors: [CodableColor]

    var id: String { name }

    /// 标准 3×3 网格控制点
    static let defaultPoints: [CodablePoint] = [
        .init(x: 0, y: 0), .init(x: 0.5, y: 0), .init(x: 1, y: 0),
        .init(x: 0, y: 0.5), .init(x: 0.5, y: 0.5), .init(x: 1, y: 0.5),
        .init(x: 0, y: 1), .init(x: 0.5, y: 1), .init(x: 1, y: 1),
    ]

    private static func c(_ r: Double, _ g: Double, _ b: Double) -> CodableColor {
        CodableColor(red: r, green: g, blue: b)
    }

    static let presets: [MeshPreset] = [
        MeshPreset(name: "海洋", localizedName: "海洋", colors: [
            c(0.04, 0.10, 0.30), c(0.06, 0.25, 0.50), c(0.10, 0.45, 0.70),
            c(0.05, 0.30, 0.55), c(0.15, 0.55, 0.80), c(0.35, 0.75, 0.90),
            c(0.10, 0.45, 0.70), c(0.40, 0.80, 0.92), c(0.70, 0.93, 0.97),
        ]),
        MeshPreset(name: "落日", localizedName: "落日", colors: [
            c(0.35, 0.10, 0.45), c(0.65, 0.15, 0.45), c(0.90, 0.30, 0.35),
            c(0.55, 0.15, 0.45), c(0.95, 0.45, 0.30), c(1.00, 0.65, 0.30),
            c(0.85, 0.35, 0.35), c(1.00, 0.70, 0.40), c(1.00, 0.88, 0.60),
        ]),
        MeshPreset(name: "极光", localizedName: "极光", colors: [
            c(0.03, 0.08, 0.20), c(0.05, 0.25, 0.35), c(0.05, 0.15, 0.30),
            c(0.05, 0.35, 0.40), c(0.10, 0.65, 0.55), c(0.20, 0.45, 0.60),
            c(0.15, 0.60, 0.45), c(0.45, 0.90, 0.70), c(0.30, 0.70, 0.80),
        ]),
        MeshPreset(name: "薰衣草", localizedName: "薰衣草", colors: [
            c(0.30, 0.20, 0.55), c(0.45, 0.30, 0.70), c(0.60, 0.45, 0.85),
            c(0.45, 0.32, 0.72), c(0.62, 0.48, 0.88), c(0.78, 0.65, 0.95),
            c(0.60, 0.48, 0.85), c(0.80, 0.70, 0.95), c(0.92, 0.88, 0.99),
        ]),
        MeshPreset(name: "蜜桃", localizedName: "蜜桃", colors: [
            c(0.95, 0.55, 0.55), c(1.00, 0.70, 0.60), c(1.00, 0.82, 0.65),
            c(1.00, 0.68, 0.62), c(1.00, 0.80, 0.70), c(1.00, 0.90, 0.75),
            c(1.00, 0.80, 0.72), c(1.00, 0.90, 0.80), c(1.00, 0.96, 0.88),
        ]),
        MeshPreset(name: "石墨", localizedName: "石墨", colors: [
            c(0.08, 0.08, 0.10), c(0.14, 0.14, 0.17), c(0.10, 0.10, 0.13),
            c(0.16, 0.16, 0.20), c(0.24, 0.24, 0.30), c(0.18, 0.18, 0.23),
            c(0.13, 0.13, 0.16), c(0.28, 0.28, 0.34), c(0.20, 0.20, 0.26),
        ]),
    ]

    static func preset(named name: String) -> MeshPreset? {
        presets.first { $0.name == name }
    }
}

nonisolated struct CodableColor: Codable, Equatable, Sendable {
    var red: Double = 1
    var green: Double = 1
    var blue: Double = 1
    var alpha: Double = 1

    var color: Color { Color(red: red, green: green, blue: blue, opacity: alpha) }
    var nsColor: NSColor { NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha) }

    init() {}

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }

    init(color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .white
        red = ns.redComponent
        green = ns.greenComponent
        blue = ns.blueComponent
        alpha = ns.alphaComponent
    }
}

// MARK: - 内容项

nonisolated enum ItemKind: String, Codable, Sendable {
    case file
    case applicationsLink
}

nonisolated struct ContentItem: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var kind: ItemKind = .file
    var sourcePath: String = ""
    /// 工程目录相对路径。运行时优先使用仍有效的绝对路径；绝对路径失效时
    /// 可用此字段从工程包所在目录重新解析，便于工程随同素材一起移动。
    var relativeSourcePath: String?
    var name: String = ""
    var x: Double = 0
    var y: Double = 0

    // 新增字段用可选存储，保证旧文档可解码
    private var invisibleStorage: Bool?
    private var identifierStorage: String?
    /// 自定义文件图标（构建时套用到拷贝的文件上）
    var customIconData: Data?

    /// 构建时把该文件设为隐藏（chflags hidden）
    var invisible: Bool {
        get { invisibleStorage ?? false }
        set { invisibleStorage = newValue }
    }

    /// 对象标识符（供脚本 / 后期扩展引用）
    var identifier: String {
        get { identifierStorage ?? "" }
        set { identifierStorage = newValue }
    }

    var position: CGPoint {
        get { CGPoint(x: x, y: y) }
        set { x = newValue.x; y = newValue.y }
    }
}

/// 文本水平对齐
nonisolated enum TextAlign: String, Codable, CaseIterable, Sendable {
    case left, center, right

    var nsAlignment: NSTextAlignment {
        switch self {
        case .left: return .left
        case .center: return .center
        case .right: return .right
        }
    }
}

// MARK: - 背景画布对象（构建时合成进背景图片）

nonisolated struct TextObject: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var text: String = "文本"
    var fontSize: Double = 24
    var color = CodableColor(red: 0, green: 0, blue: 0)
    var x: Double = 0
    var y: Double = 0

    // 新增字段用可选存储，保证旧文档可解码
    /// 自定义字体名；nil = 系统字体
    var fontName: String?
    private var alignmentStorage: TextAlign?
    private var shadowEnabledStorage: Bool?
    private var shadowColorStorage: CodableColor?
    private var shadowAngleStorage: Double?
    private var shadowOffsetStorage: Double?
    private var shadowBlurStorage: Double?
    private var shadowOpacityStorage: Double?

    var alignment: TextAlign {
        get { alignmentStorage ?? .center }
        set { alignmentStorage = newValue }
    }
    var shadowEnabled: Bool {
        get { shadowEnabledStorage ?? false }
        set { shadowEnabledStorage = newValue }
    }
    var shadowColor: CodableColor {
        get { shadowColorStorage ?? CodableColor(red: 0, green: 0, blue: 0) }
        set { shadowColorStorage = newValue }
    }
    /// 阴影方向（度，0 = 正右，顺时针即屏幕向下）
    var shadowAngle: Double {
        get { shadowAngleStorage ?? 45 }
        set { shadowAngleStorage = newValue }
    }
    var shadowOffset: Double {
        get { shadowOffsetStorage ?? 2 }
        set { shadowOffsetStorage = newValue }
    }
    var shadowBlur: Double {
        get { shadowBlurStorage ?? 3 }
        set { shadowBlurStorage = newValue }
    }
    /// 0~1
    var shadowOpacity: Double {
        get { shadowOpacityStorage ?? 0.5 }
        set { shadowOpacityStorage = newValue }
    }

    var nsFont: NSFont {
        if let fontName, let font = NSFont(name: fontName, size: fontSize) {
            return font
        }
        return .systemFont(ofSize: fontSize, weight: .medium)
    }

    /// 阴影在屏幕坐标系（y 向下为正）的偏移量
    var shadowVector: CGSize {
        let radians = shadowAngle * .pi / 180
        return CGSize(width: cos(radians) * shadowOffset,
                      height: sin(radians) * shadowOffset)
    }
}

nonisolated struct ImageObject: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var imageData = Data()
    var width: Double = 100
    var height: Double = 100
    var x: Double = 0
    var y: Double = 0

    var image: NSImage? { NSImage(data: imageData) }
}

// MARK: - 许可协议

nonisolated struct DiskLicense: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    /// LicenseLanguage.key，如 "en"、"zh-Hans"
    var languageKey: String = "en"
    var rtfData = Data()
    // 本地化按钮文案；留空则用该语言的默认值
    var agree = ""
    var disagree = ""
    var printText = ""
    var save = ""
    var prompt = ""

    var language: LicenseLanguage {
        LicenseLanguage.byKey[languageKey] ?? LicenseLanguage.all[4]  // fallback English
    }
}

// MARK: - 工程文档

nonisolated struct DMGProject: Codable, Equatable, Sendable {
    var volumeName: String = DefaultVolumeName.localizationKey {
        didSet {
            if volumeName != oldValue {
                volumeNameUsesLocalizedDefault = false
            }
        }
    }
    /// Optional for backward compatibility with projects saved before the
    /// localized default-name marker was introduced.
    var volumeNameUsesLocalizedDefault: Bool? = true

    var shouldLocalizeDefaultVolumeName: Bool {
        volumeNameUsesLocalizedDefault ?? DefaultVolumeName.isRecognized(volumeName)
    }

    mutating func localizeDefaultVolumeName(to localizedName: String) {
        guard shouldLocalizeDefaultVolumeName else { return }
        volumeName = localizedName
        volumeNameUsesLocalizedDefault = true
    }

    // 磁盘映像设置
    var fileSystem: FileSystemChoice = .apfs
    var compression: CompressionChoice = .lzfse
    var gatekeeper: GatekeeperMode = .none
    var signingIdentity: String = ""
    var notaryProfile: String = ""
    var imageSizeAuto: Bool = true
    var customSizeMB: Int = 100
    var encryption: EncryptionMode = .none
    var volumeIconData: Data?

    // 窗口
    var windowLeft: Double = 200
    var windowTop: Double = 120
    var windowWidth: Double = 600
    var windowHeight: Double = 360
    var iconSize: Double = 96
    var textSize: Double = 12
    var labelPosition: LabelPosition = .bottom
    var showSidebar = false
    var showIconPreview = false
    var showItemInfo = false

    // 背景
    var background: BackgroundStyle = .none
    var backgroundColor = CodableColor()
    var backgroundImageData: Data?
    /// 旧工程兼容字段。早期 UI 的 1x/2x 只影响“适配背景图片”，不再参与显示。
    var backgroundScale: Int = 1
    private var backgroundImageZoomStorage: Double?

    /// 以 aspect-fill 为 100% 的背景图片连续缩放比例。
    var backgroundImageZoom: Double {
        get { BackgroundImageLayout.clampedZoom(backgroundImageZoomStorage ?? 1) }
        set { backgroundImageZoomStorage = BackgroundImageLayout.clampedZoom(newValue) }
    }

    // Mesh 渐变 / 玻璃面板（用可选存储保证旧文档可解码）
    private var meshPresetNameStorage: String?
    private var meshColorsStorage: [CodableColor]?
    private var meshPointsStorage: [CodablePoint]?

    var meshPresetName: String {
        get { meshPresetNameStorage ?? MeshPreset.presets[0].name }
        set { meshPresetNameStorage = newValue }
    }
    var meshColors: [CodableColor] {
        get { meshColorsStorage ?? MeshPreset.presets[0].colors }
        set { meshColorsStorage = newValue }
    }
    var meshPoints: [CodablePoint] {
        get { meshPointsStorage ?? MeshPreset.defaultPoints }
        set { meshPointsStorage = newValue }
    }

    // 内容与画布对象
    var items: [ContentItem] = []
    var textObjects: [TextObject] = []
    var imageObjects: [ImageObject] = []

    // 许可协议
    var licenses: [DiskLicense] = []

    var windowSize: CGSize { CGSize(width: windowWidth, height: windowHeight) }

    var backgroundImage: NSImage? {
        guard let data = backgroundImageData else { return nil }
        return NSImage(data: data)
    }

    /// 有文本/图片对象或渐变背景时，构建需要合成一张背景 PNG
    var needsCompositeBackground: Bool {
        if !textObjects.isEmpty || !imageObjects.isEmpty { return true }
        if background == .mesh || background == .color { return true }
        return background == .image && backgroundImageData != nil
    }

    /// 摘要：最低 macOS 版本
    var minMacOSText: String {
        let v = max(fileSystem.minMacOS, compression.minMacOS)
        let names: [Double: String] = [10.4: "10.4", 10.11: "10.11", 10.13: "10.13"]
        return "macOS \(names[v] ?? String(v))+"
    }
}
