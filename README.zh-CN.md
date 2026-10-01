# Topiary: macOS 菜单栏管理器

看清、唤起、退出、常驻你 Mac 上运行着的每一个菜单栏应用。**不请求任何权限、无任何统计上报、数据不出设备** —— 同时提供公证的 Developer ID 版与 Mac App Store 版。

> 🌐 [English](README.md) · **简体中文**

> **官网** → [sky-jiangcheng.github.io/topiary-bar](https://sky-jiangcheng.github.io/topiary-bar/)

[![Release](https://img.shields.io/github/v/release/sky-jiangcheng/topiary-bar?label=release&color=blue)](https://github.com/sky-jiangcheng/topiary-bar/releases)
[![Test](https://github.com/sky-jiangcheng/topiary-bar/actions/workflows/test.yml/badge.svg)](https://github.com/sky-jiangcheng/topiary-bar/actions/workflows/test.yml)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange?logo=swift&logoColor=white)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-14%2B-black?logo=apple&logoColor=white)](https://www.apple.com/macos/)

---

## 目录

- [核心功能](#核心功能)
- [App 类型](#app-类型)
- [安装](#安装)
- [从源码构建](#从源码构建)
- [发布流水线（CI/CD）](#发布流水线cicd)
- [已知限制](#已知限制)
- [隐私](#隐私)
- [技术栈](#技术栈)
- [项目结构](#项目结构)
- [文档索引](#文档索引)
- [版本历史](#版本历史)
- [许可证](#许可证)

---

## 核心功能

### 📌 状态栏常驻

| 功能 | 说明 |
|------|------|
| **常驻菜单栏** | 勾选的应用图标直接入住 macOS 菜单栏 —— 每个应用一个常驻图标，始终可见，无需弹出任何窗口。左键唤起应用，右键菜单可打开 / 取消常驻 / 退出 |
| **主窗口一键常驻** | 选中应用后在详情页打开「常驻菜单栏」开关，列表中已常驻的应用带图钉标识——不再需要浮动管理面板 |
| **持久化** | 常驻勾选与自定义顺序重启后仍生效（按分发渠道隔离存于 `UserDefaults`） |

### 🚦 应用管理

| 功能 | 说明 |
|------|------|
| **App 类型自动检测** | 基于 `activationPolicy` 区分 Status Bar（accessory）与 Dock（regular）应用 |
| **一键操作** | 打开、退出、强制退出（MAS 沙盒版编译期剔除退出功能） |
| **accessory 唤起** | macOS 禁止 `NSRunningApplication.activate()` 前台化 accessory 应用；本应用改用 `NSWorkspace.openApplication(at:configuration:)`（`activates = true`）重新唤起 |
| **实时监控** | 按 1/2/5 秒间隔刷新运行中的应用列表 |
| **搜索过滤** | 主窗口与弹窗均可按名称或 Bundle ID 搜索 |

### 🎨 界面

| 功能 | 说明 |
|------|------|
| **主窗口** | 双标签一窗口——「应用」与「设置」。应用页：侧栏（搜索 + 类型筛选 + 分组应用列表，小节头带数量）+ 详情区（未选中显示品牌概览与紧凑统计，选中显示结构化应用详情与常驻开关） |
| **菜单栏弹窗** | 按类型分组的应用列表 + 每应用内存 + 系统内存概览卡片；明确关闭按钮；底栏为设置 / 打开主窗口快捷方式 |
| **全局快捷键** | ⌃⌥M 随时唤起主窗口（Carbon 注册，无需辅助功能权限） |
| **外观主题** | 跟随系统 / 浅色 / 深色，全局即时生效 |
| **多语言** | 简体中文 / English / 日本語 / Deutsch / Español，可跟随系统或手动切换 |
| **自定义顺序** | 拖拽调整顺序；未排序应用可插入到指定位置 |

## App 类型

| 类型 | 说明 | 激活方式 |
|------|------|----------|
| Status Bar | 仅有状态栏图标，无 Dock 图标 | `openApplication(at:configuration:)`（`activates = true`） |
| Dock | 有 Dock 图标 | `activate` |

## 安装

1. 从 [GitHub Releases](https://github.com/sky-jiangcheng/topiary-bar/releases/latest) 下载 `Topiary-<version>.dmg`
2. 打开 DMG，把 `Topiary.app` 拖到 Applications
3. 首次打开若出现 Gatekeeper 提示：系统设置 → 隐私与安全性 → 仍要打开

官网版（Developer ID 公证 DMG）含退出 / 强制退出；Mac App Store 版受沙盒限制，这两项在编译期移除。两版 Bundle ID 不同，可同时安装，设置互不共享。

## 从源码构建

```bash
./script/build_and_run.sh   # 构建 + 签名 + 启动 dist/Topiary.app
swift build                 # 仅构建
./script/build_and_run.sh run
```

额外模式：`--debug`（lldb）/ `--logs`（日志流）/ `--verify`（启动自检）。

构建环境要求：

- Swift 6.0+，macOS 14+ SDK
- **需要完整 Xcode**：`xcode-select -p` 必须指向 `Xcode.app`，并已执行 `sudo xcodebuild -license accept`。SwiftUI 宏插件随 Xcode 提供；仅装 Command Line Tools 会报 `plugin for module 'SwiftUIMacros' not found`，且 Swift 6.4 起默认 `swiftbuild` 构建系统在 CLT-only 环境会直接以 `Unknown error parsing property list` 失败
- 未能切换 Xcode 时的临时绕过：

```bash
swift build --build-system native \
  -Xswiftc -plugin-path \
  -Xswiftc /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins
```

- `swift test` 需要完整 Xcode 的 `XCTest` 与 runner；CI（`test.yml`）在切换到 Xcode 后执行

## 发布流水线（CI/CD）

推送 `v*` 标签会同时触发两条流水线：

| 渠道 | Workflow | Bundle ID | 沙盒 | Quit / Force Quit | 产物 |
|------|----------|-----------|------|-------------------|------|
| Mac App Store | `release.yml` | `com.jiangcheng.MacStatusApp` | 开（MAS 强制） | 编译期移除 | `.pkg` → altool 上传 |
| 官网自分发 | `notarize.yml` | `com.jiangcheng.EasyBar` | 关（Hardened Runtime） | 完整可用 | `.dmg` → 公证 + 装订 → 挂到 GitHub Release |

单元测试由 `test.yml` 在每次 push/PR 运行（macOS runner + 完整 Xcode，`swift test`）。

两条流水线都走 `script/release.sh`：编译 SPM 产物再组装 `.app`；MAS 渠道再用 `productbuild` 打成 `.pkg`。

> MAS 的 `.pkg` 必须用 **3rd Party Mac Developer Installer** 证书签名；`release.yml` 会导入 Apple WWDR G3 中间证书。所需 Secrets 位于 Repo → Settings → Secrets and variables → Actions（证书 `.p12` + 密码、描述文件、App Store Connect API key/issuer）；可选变量 `BUNDLE_ID` / `BUNDLE_ID_DIRECT` 覆盖 Bundle ID。切勿提交 `.p12` / `.cer` / `.provisionprofile` / `.p8` 文件。

> `xcrun altool --upload-app` 已列入 Apple 弃用计划；若 runner 镜像移除，请将该步骤切换为 Transporter 或 App Store Connect API。

发布新版本：

```bash
git tag v1.20.1 && git push origin v1.20.1
```

## 已知限制

- Status Bar（accessory）应用无法通过 `NSRunningApplication.activate()` 前台化 —— 属 macOS 安全限制。本应用通过 `NSWorkspace.openApplication`（`activates = true`）重新唤起；激活时序与已弃用的 `launchApplication(withBundleIdentifier:)` 存在差异，个别 accessory 应用（如 Macs Fan Control）本就无法被其他应用唤起
- App 类型基于 `activationPolicy`，无法读取真实的状态栏图标归属
- 菜单栏图标的初始位置由系统控制——新状态项总是落在最左侧（紧贴刘海）。**⌘-拖动一次**到想要的位置即可，系统会跨启动记住该位置；应用自身也会检测图标被遮挡并自动弹出窗口
- 应用不会隐藏真实系统菜单栏图标（AX 隐藏方案已于 v1.6.0 移除）；需要该能力请搭配 Hidden Bar / Ice / Bartender 等专用工具——检测到它们运行时会自动抑制遮挡提醒
- 暗色 App 图标变体（`Assets.xcassets/AppIcon.appiconset/dark/`）只在 Xcode 资产目录（`Assets.car`）流程下生效；`script/release.sh` 用 `iconutil` 生成仅含浅色图标的 `.icns`
- MAS 沙盒拦截 `NSRunningApplication.terminate()` 且用户无对应授权开关，故 MAS 版用 `-D MAC_APP_STORE` 编译期剔除退出功能

## 隐私

不请求任何权限。应用通过公共 API 列出运行中的应用、只读展示 `AXIsProcessTrusted()` 状态，全部在本地处理 —— **无统计、无网络访问、零数据收集**。详见[隐私政策](https://sky-jiangcheng.github.io/topiary-bar/privacy/)。

## 技术栈

- **语言**：Swift 6.0
- **框架**：SwiftUI + AppKit
- **架构**：`@Observable`（Observation framework）
- **构建**：Swift Package Manager（无 `.xcodeproj`，发布脚本组装 `.app`）
- **后台代理**：`LSUIElement` —— 关闭全部窗口后常驻图标持续保留

## 项目结构

```
topiary-bar/
├── Package.swift
├── Sources/topiary-bar/
│   ├── App/                    # 入口、设置窗口、状态栏调度
│   ├── Managers/               # 监控、常驻栏、内存/可见性监控、设置、本地化
│   ├── Views/                  # 主窗口（应用 + 设置双标签）/ 弹窗 / 主题组件
│   └── Resources/              # entitlements、Assets.xcassets
├── Tests/topiary-bar-tests/     # 单元测试（swift test，纯逻辑）
├── script/
│   ├── build_and_run.sh        # 本地：构建 + 签名 + 运行
│   └── release.sh              # 发布：mas / devid 渠道
├── tools/                      # 图标与截图工具
├── design/leaf-icon/           # App 图标设计稿
└── docs/                       # GitHub Pages（中英双语）
```

## 文档索引

- [docs/AppStoreChecklist.md](docs/AppStoreChecklist.md) — Mac App Store 提交清单
- [CHANGELOG.md](CHANGELOG.md) — 版本历史
- [官网](https://sky-jiangcheng.github.io/topiary-bar/) · [技术支持](https://sky-jiangcheng.github.io/topiary-bar/support/) · [隐私政策](https://sky-jiangcheng.github.io/topiary-bar/privacy/)

## 版本历史

见 [CHANGELOG.md](CHANGELOG.md)；各版本产物见 [GitHub Releases](https://github.com/sky-jiangcheng/topiary-bar/releases)。

## 许可证

[MIT](LICENSE)
