# ClipWiseMac

ClipWise，中文名“截图智读助手”。这是 macOS 原生 Swift/AppKit/SwiftUI 版本。

## 运行

```bash
swift run ClipWiseMac
```

也可以用 Xcode 打开 `Package.swift` 运行。

## 打包测试版

在仓库根目录运行：

```bash
./scripts/package_app.sh
```

产物会生成到：

- `dist/ClipWise.app`
- `dist/ClipWise.zip`

默认使用 ad-hoc 签名，适合发给熟人测试。正式 Developer ID 签名可运行：

```bash
CLIPWISE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/package_app.sh
```

## 图标资源

App 图标和状态栏图标由仓库根目录的脚本生成：

```bash
swift scripts/generate_icons.swift
```

生成内容：

- `SnipConcludeMac/Assets/ClipWise.icns`：打包进 `.app` 的主图标
- `SnipConcludeMac/Assets/ClipWise.iconset/`：符合 macOS iconset 命名和像素尺寸的源 PNG
- `SnipConcludeMac/Assets/ClipWise-AppIcon-1024.png`：主图标预览图
- `SnipConcludeMac/Assets/StatusBarTemplate.png` 和 `@2x`：状态栏 template 图标
- `SnipConcludeMac/Sources/Resources/StatusBarTemplate.png` 和 `@2x`：SwiftPM 运行时资源

主图标采用截图取景框、文字卡片和 AI 星标元素；状态栏图标为单色 template 版本，运行时会被 macOS 自动适配浅色/深色菜单栏。

## 权限

- 截图需要在 macOS “隐私与安全性 / 屏幕录制”中授权运行该程序的终端或 Xcode。
- 全局快捷键监听需要“辅助功能”权限。

## 功能

- 欢迎、通用、控制、模型提供商、关于 Tab
- 全局快捷键唤起截图，默认 `Control + Shift + A`
- 原生 AppKit 选区截图
- OpenAI-compatible 本地视觉模型请求
- 模型列表管理，可添加常用模型并勾选快速切换
- 截图结果窗口，标题栏右侧带翻译/总结/OCR/复制/保存/关闭按钮
