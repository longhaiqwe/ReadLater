# 稍后阅读

基于 clothesline-ui 的原生 macOS 文件暂存晾台。SwiftUI＋AppKit，macOS 14+。

## 下载

[下载稍后阅读 v0.1.1（Apple Silicon）](https://github.com/longhaiqwe/ReadLater/releases/latest/download/readlater-macos-arm64.zip) · [全部版本](https://github.com/longhaiqwe/ReadLater/releases) · [下载源码](https://github.com/longhaiqwe/ReadLater/archive/refs/tags/v0.1.1.zip)

解压后将「稍后阅读.app」放入「应用程序」并打开。首版支持 macOS 14+，现成安装包仅适用于 Apple Silicon；Intel Mac 可尝试自行构建，尚未实机验证。本版本为 ad-hoc 签名、未做 Apple 公证，macOS 可能要求你在“隐私与安全性”中明确允许打开。请确认下载来自本仓库；不需要关闭系统整体安全保护。

![稍后阅读实机截图](docs/screenshots/07-readlater-live.png)

## 使用

打开应用后常驻菜单栏。首次运行固定在底部，取消固定后可通过屏幕边缘唤出；重新打开应用也会展开并保留 10 秒操作时间。拖入本地文件或点击“添加文件”，应用保存独立副本；拖动文件缩略图可将真实文件复制给 Finder 或接收文件拖放的其他应用。夹子负责排序，绳子／移动手柄负责更换屏幕边缘。

- 支持普通本地文件，不接收文件夹、网页地址或只提供 file promise 的拖放源。
- 文件存放于 `~/Library/Application Support/稍后阅读/Files/`，清单为同目录 `shelf.json`。
- 按内容 SHA-256 去重；同名但内容不同的文件分别保存。
- 支持 Quick Look 预览、默认应用打开、Finder 定位、已读状态持久化。
- 移除只把托管副本放进废纸篓，原始文件保持独立。
- 双向拖放的接收效果取决于目标应用是否支持本地文件 URL；本版本没有云同步或全文阅读器。

## 从源码构建

需要包含 macOS SDK 的 Swift 5.9+ 工具链、Python 3。可通过 Xcode 或 Apple Command Line Tools 安装构建工具。

```sh
git clone https://github.com/longhaiqwe/ReadLater.git
cd ReadLater
```

构建与测试：

```sh
swift test
swift scripts/generate-icon.swift assets
iconutil -c icns assets/AppIcon.iconset -o assets/AppIcon.icns
python3 scripts/build_app.py
```

开发用真实视图渲染（使用隔离数据，不修改正式文件架）：

```sh
swift run ClotheslineApp --render-previews Fixtures/拖入文件 docs/article-assets
```

本机打包为 Apple Silicon、ad-hoc 签名，未公证。验证覆盖与限制见 `docs/VERIFICATION.md`；源代码按当前工具链构建。原有授权见 `THIRD_PARTY_LICENSES.txt`。

## 复用与授权

本产品使用 [clothesline-ui](https://github.com/longhaiqwe/clothesline-ui) 构建，7 个通用组件与 Skill 模板保持一致，详见 [复用记录](docs/REUSE.md)。

代码采用 [MIT](LICENSE)，原有装饰与交互来源的授权保留在 [THIRD_PARTY_LICENSES.txt](THIRD_PARTY_LICENSES.txt)。

[验证记录](docs/VERIFICATION.md) · [更新记录](CHANGELOG.zh.md)
