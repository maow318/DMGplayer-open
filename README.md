<div align="center">
  <img src="DMGplayer/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width="128" height="128" alt="DMGplayer icon">
  <h1>DMGplayer</h1>
  <p>A native visual DMG designer and builder for macOS.<br>原生、可视化的 macOS 磁盘映像设计与构建工具。</p>

  [![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)](https://www.apple.com/macos/)
  [![Swift](https://img.shields.io/badge/Swift-SwiftUI-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
  [![License: PolyForm Noncommercial 1.0.0](https://img.shields.io/badge/License-PolyForm%20Noncommercial%201.0.0-blue.svg)](LICENSE)
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

- macOS 14.0 Sonoma or later
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

## License / 源码许可

DMGplayer is licensed under the
[PolyForm Noncommercial License 1.0.0](LICENSE).

This is a **source-available, noncommercial** license rather than an open-source
license. Personal, educational, research, charitable, and other noncommercial
uses permitted by the license are welcome. Commercial sale, paid distribution,
or offering DMGplayer as part of a commercial product or service requires a
separate written commercial license from the licensor.

The original or modified software may not be sold or offered as a paid listing
through the Apple App Store, Mac App Store, Setapp, or any other third-party
software marketplace without that separate commercial license. Redistributors
must include both [the license](LICENSE) and the [required notice](NOTICE).

本项目采用 PolyForm Noncommercial 1.0.0 源码可见、仅限非商业用途的许可协议，
并非 OSI 定义的开源协议。个人学习、研究、教育、公益等协议允许的非商业用途可以
使用、修改和分发；任何商业销售、付费分发，或将本软件作为商业产品或服务的一部分，
都必须事先取得许可方单独出具的书面商业授权。

未经单独书面商业授权，不得将原版或修改版在 Apple App Store、Mac App Store、
Setapp 或任何其他第三方软件平台上销售或作为付费项目上架。再次分发时必须同时保留
[完整许可证](LICENSE)与[必要声明](NOTICE)。

## Contributing / 参与贡献

Issues and pull requests are welcome. Please include focused changes, keep local
or signing data out of commits, and run the test suite before submitting a PR.

欢迎提交 Issue 与 Pull Request。请保持改动聚焦，不要提交本机路径、签名材料或凭据，
并在提交 PR 前运行测试。
