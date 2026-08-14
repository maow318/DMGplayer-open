<div align="center">
  <img src="DMGplayer/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width="128" height="128" alt="DMGplayer icon">
  <h1>DMGplayer</h1>
  <p>A native visual DMG designer and builder for macOS.<br>原生、可视化的 macOS 磁盘映像设计与构建工具。</p>

  [![macOS 26.5+](https://img.shields.io/badge/macOS-26.5%2B-black?logo=apple)](https://www.apple.com/macos/)
  [![Swift](https://img.shields.io/badge/Swift-SwiftUI-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
  [![License: AGPL v3+](https://img.shields.io/badge/License-AGPL--3.0--or--later-blue.svg)](LICENSE)
</div>

DMGplayer turns a folder or application into a polished macOS disk image without
requiring a hand-written shell script. Design the Finder window visually, run a
preflight check, then build the final DMG with Apple's system tools.

DMGplayer 可以把 App、文件或文件夹制作成带有完整 Finder 布局的 macOS 磁盘映像。
你可以直接在画布中设计窗口、执行构建前检查，并使用系统工具生成最终 DMG。

## Highlights / 功能

- Visual Finder-window canvas with drag, selection, alignment guides, snapping,
  equal-spacing hints, and precise positioning.
- Add applications, files, folders, an `/Applications` shortcut, text, and images.
- Solid color, image, or 3×3 mesh-gradient backgrounds with reusable presets.
- Quick Pack panel for turning an App into a DMG with minimal setup.
- APFS and HFS+ output; LZFSE, zlib, bzip2, or uncompressed images.
- Optional AES-128 and AES-256 disk-image encryption.
- Multi-language SLA/license resources and localized application UI.
- Build preflight for source files, bundle structure, layout, free space, mounted
  volumes, signing state, credentials, and output destination.
- Optional app signing and Apple notarization when users supply their own
  credentials. No credentials are included in this repository.
- Portable project packages plus compatibility with legacy JSON project files.
- Command-line entry points for automated validation and builds.

## Requirements / 系统要求

- macOS 26.5 or later
- Xcode 26 or later for building from source
- Apple Silicon or Intel Mac; the downloadable build is Universal

The app relies on macOS tools including `hdiutil`, `codesign`, `notarytool`, and
Finder automation. It is intended to run on macOS rather than inside a sandboxed
cross-platform environment.

## Install / 安装

Download the latest DMG from the
[Releases page](https://github.com/maow318/DMGplayer-open/releases/latest), open
it, and drag DMGplayer into Applications.

下载最新版 DMG，打开后将 DMGplayer 拖入“应用程序”文件夹即可。

### About signing / 关于签名

Public builds are **ad-hoc signed** and are not notarized. They contain no Apple
Developer certificate and no Developer Team identifier. macOS may therefore ask
you to confirm the first launch. Use Finder's **Open** command from the context
menu, or approve the app in **System Settings → Privacy & Security**.

公开构建仅使用本地 ad-hoc 签名，没有开发者证书、Developer Team ID，也没有经过
Apple 公证。因此首次打开时 macOS 可能要求确认；请在 Finder 中右键选择“打开”，
或前往“系统设置 → 隐私与安全性”批准运行。

## Build from source / 从源码构建

Open `DMGplayer.xcodeproj` in Xcode, or run:

```sh
xcodebuild \
  -project DMGplayer.xcodeproj \
  -scheme DMGplayer \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

The project is configured with manual ad-hoc signing:

```text
CODE_SIGN_IDENTITY = -
CODE_SIGN_STYLE = Manual
DEVELOPMENT_TEAM = ""
```

To distribute a signed and notarized fork, configure your own Apple Developer
Team and credentials. Never commit certificates, provisioning profiles, API
keys, app-specific passwords, or notarization profiles.

## Tests / 测试

```sh
xcodebuild \
  -project DMGplayer.xcodeproj \
  -scheme DMGplayer \
  -configuration Debug \
  -destination 'platform=macOS' \
  test
```

The test suite covers project encoding, build recovery, preflight rules,
selection, snapping, background layout, sidebar navigation, and localization.

## Privacy / 隐私

DMGplayer has no analytics or telemetry. Project editing and DMG creation happen
locally. Network access is only expected when you explicitly choose Apple
notarization, in which case Apple's `notarytool` communicates with Apple using a
credential profile stored in your Keychain.

DMGplayer 不包含统计或遥测功能。工程编辑与 DMG 构建均在本机完成；仅当你主动选择
Apple 公证时，系统 `notarytool` 才会使用钥匙串中的凭据连接 Apple 服务。

## Repository layout / 仓库结构

```text
DMGplayer/             Application source and assets
DMGplayerTests/        Unit and integration tests
DMGplayer.xcodeproj/   Xcode project
Info.plist             Document and exported-type declarations
```

Generated builds, DerivedData, Xcode user state, local agent settings, signing
material, and release packages are intentionally excluded from version control.

## License / 开源协议

DMGplayer is licensed under the
[GNU Affero General Public License v3.0 or later](LICENSE).

This is a strong copyleft license. If you distribute a modified version, you
must provide the corresponding source under the same license. If a modified
version is used to provide functionality to users over a network, those users
must also be offered the corresponding source as required by AGPL section 13.

本项目采用 GNU AGPL v3.0-or-later 强传染性开源协议。分发修改版时必须同时提供对应
源码并继续使用兼容的同类许可证；如果修改版通过网络向用户提供服务，也必须依照
AGPL 第 13 条向这些用户提供对应源码。

## Contributing / 参与贡献

Issues and pull requests are welcome. Please include focused changes, keep local
or signing data out of commits, and run the test suite before submitting a PR.

欢迎提交 Issue 与 Pull Request。请保持改动聚焦，不要提交本机路径、签名材料或凭据，
并在提交 PR 前运行测试。
