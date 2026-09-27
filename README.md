# StatusBar

macOS 菜单栏管理工具，自动检测并管理状态栏和 Dock 应用。

## 功能特性

### 核心功能
- **App 类型自动检测**：基于 `activationPolicy` 自动区分 Status Bar 和 Dock 应用
- **操作按钮**：一键打开、退出、强制退出应用
- **实时监控**：定时刷新运行中的应用列表
- **搜索过滤**：按名称或 Bundle ID 搜索应用

### 个性化
- **外观主题**：跟随系统 / 浅色 / 深色，全局即时生效（含菜单栏面板与弹窗）
- **多语言界面**：简体中文 / English / 日本語 / Deutsch / Español，可在设置中切换或跟随系统语言

### 界面设计
- **主窗口**：HSplitView 布局，左侧 sidebar + 右侧详情
- **Stat Cards**：Total / Status Bar / Dock 统计卡片，点击联动过滤
- **Popover**：状态栏聚合面板，搜索 + 应用列表
- **操作按钮**：Open (🔵) / Quit (🔴) / Force Quit (🟠)
- **排序页**：拖拽调整自定义顺序；「未排序」区的图标可拖入顺序列表（拖到某行即插入到该行之前），顺序内的图标可用删除手势移出

### App 类型
| 类型 | 说明 | 激活方式 |
|------|------|----------|
| Status Bar | 仅有状态栏图标，无 Dock 图标 | `openApplication(at:configuration:)`（`activates = true`） |
| Dock | 有 Dock 图标 | `activate` |

## 技术栈

- **语言**：Swift 6.0
- **最低系统**：macOS 14+
- **框架**：SwiftUI + AppKit
- **架构**：`@Observable` (Observation framework)
- **构建**：Swift Package Manager

## 项目结构

```
StatusBar/
├── Sources/StatusBar/
│   ├── App/
│   │   ├── MacStatusApp.swift      # App 入口（@main + AppDelegate）
│   │   ├── SettingsOpener.swift    # 打开设置窗口
│   │   └── StatusBarManager.swift  # 状态栏图标 / Popover / 聚合面板调度
│   ├── Managers/
│   │   ├── MenuBarMonitor.swift    # 核心监控逻辑
│   │   ├── SettingsStore.swift     # 设置存储
│   │   ├── Localization.swift      # L10nTable + 5 种语言表
│   │   ├── AccessibilityManager.swift  # 辅助功能状态（只读展示）
│   │   └── AggregationPanel.swift  # 聚合面板窗口
│   ├── Views/
│   │   ├── ContentView.swift       # 主窗口
│   │   ├── PopoverView.swift       # 状态栏面板
│   │   ├── SettingsView.swift      # 设置界面
│   │   ├── AggregationView.swift   # 聚合视图
│   │   ├── AggregationIconSelector.swift  # 聚合图标选择
│   │   └── IconOrderView.swift     # 图标排序
│   └── Resources/                  # entitlements / Assets.xcassets
├── Tests/StatusBarTests/        # 单元测试（swift test，纯逻辑）
├── Package.swift
├── script/
│   ├── build_and_run.sh            # 本地开发：构建 + 签名 + 运行
│   └── release.sh                  # 发布：构建 + 签名 + 打包（mas / devid）
├── design/leaf-icon/               # App 图标设计稿（SVG + 渲染脚本）
└── docs/                  # GitHub Pages（中英双语）
    ├── assets/            # site.css + i18n.js
    ├── index.html
    ├── privacy/
    ├── support/
    └── AppStoreChecklist.md
```

## 本地运行

```bash
# 构建并运行（debug）
./script/build_and_run.sh

# 仅构建
swift build

# 其他模式：--debug（lldb）/ --logs（日志流）/ --verify（启动自检）
./script/build_and_run.sh run
```

`script/build_and_run.sh` 产出的 `dist/StatusBar.app` 使用官网自分发的 Bundle ID（`com.jiangcheng.EasyBar`）与 Developer ID entitlements（沙盒关闭），与 CI 的 devid 渠道保持一致；沙盒开启的 MAS 渠道由 `script/release.sh` 的 `mas` 分支负责。

## 系统要求

- macOS 14.0+
- 不请求任何权限：应用只调用 `AXIsProcessTrusted()` 读取辅助功能开关状态，用于界面上的只读展示（未开启不影响任何功能）

### 构建环境要求

- Swift 6.0+，macOS 14+ SDK
- **需要完整 Xcode**：`xcode-select -p` 必须指向 `Xcode.app`，且已同意许可（`sudo xcodebuild -license accept`）。SwiftUI 的宏插件（`@State`、`@Bindable` 等）随 Xcode 提供，只装 Command Line Tools 会报
  `plugin for module 'SwiftUIMacros' not found`；而 Swift 6.4 起 `swift build` 默认改用 `swiftbuild` 构建系统，在 CLT-only 环境下会直接以 `Unknown error parsing property list` 失败。
- 临时绕过（未能切换 Xcode 时，可显式指定插件路径）：
  ```bash
  swift build --build-system native \
    -Xswiftc -plugin-path \
    -Xswiftc /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins
  ```
- 单元测试（`swift test`）需要完整 Xcode 提供 `XCTest` 模块与 `xctest` runner，仅装 Command Line Tools 无法本地运行；CI（`test.yml`）在 `xcode-select` 指向 Xcode 后执行。

## 已知限制

- Status Bar 应用无法通过 `NSRunningApplication.activate()` 激活（macOS 安全限制），本应用对 accessory 应用通过 `NSWorkspace.openApplication`（`activates = true`）重新唤起
- 部分 accessory app（如 Macs Fan Control）无法被其他 app 激活
- App 类型检测基于 `activationPolicy`，无法读取真实的状态栏图标归属
- 聚合面板不会隐藏系统菜单栏图标（v1.6.0 起移除 AX 隐藏方案），仅在菜单栏下方浮动显示
- Status Bar 应用唤起已从弃用的 `launchApplication(withBundleIdentifier:)` 迁移至 `NSWorkspace.openApplication(at:configuration:)`；激活时序与旧 API 存在差异，若个别 accessory 应用唤起异常请反馈

## 版本历史

| 版本 | 内容 |
|------|------|
| v1.1.0 | Phase 1-5 完整实现 |
| v1.2.0 | Window + status bar 支持 |
| v1.3.0 | P0/P1 code review 修复 |
| v1.4.0 | AggregationPanel 可达 + iconSpacing |
| v1.5.0 | AX API 兼容性 + debug 工具 |
| v1.6.0 | 移除 AX 隐藏，纯 UI 聚合方案 |
| v1.7.0 | Quit/force-quit + App 状态检测 |
| v1.14.0 | Code Review 修复：聚合面板点击激活、Popover 双 toggle 竞态、hover 暂停自动隐藏、Force Quit 二次确认、`Bundle.main` 自排除、`openApplication` 迁移、Layout 常量收敛、单元测试 + CI |
| v1.8.0 | UI 重新设计 + Sidebar 修复 |
| v1.9.0 | HSplitView 布局 + stat card 联动 |
| v1.10.0 | accessory app 检测 + eye icon 手势修复 |
| v1.11.0 | 移除 hasStatusBar 自动检测 |
| v1.12.0 | App 类型检测 + 移除 hide 功能 |
| v1.13.0 | **里程碑：Status Bar app 跳转修复** |
| v1.14.0 | 代码 review 修复（P0×3/P1×7/P2×3 + 回归 9 项）；外观主题；多语言（中/日/英/德/西） |
| v1.17.0 | 发布链路修复与安全整理：MAS `.pkg` 改用 3rd Party Mac Developer Installer 证书签名并导入 WWDR G3 中间证书；描述文件 UUID 提取改用 grep；停止跟踪证书 / 描述文件等上传产物并清理历史；官网与 README 更新 |
| v1.18.0 | 应用图标更换为滑块玻璃面板：按 1024 满幅 + 烘焙圆角重新生成，同一套资源兼容 macOS 12+ 与 macOS 26/27 新图标网格；补深色外观（黑白反相）；`tools/generate_app_icon.py` 提供可复现的生成链路 |
| v1.16.0 | 品牌统一：产品名 StatusBar Pro → StatusBar（SPM/产物/显示名/本地化/CI/docs）；GitHub 仓库与 Pages 从 EasyBar 迁至 StatusBar；发布链路梳理 |
| v1.15.0 | 修复排序页自动写入自定义顺序导致「未排序」失效；区分 Normal/Disabled 模式策略；保留菜单项名称、类型与图标更新；修正聚合面板可见性状态；完善测试与构建验证 |

## CI/CD 发布（双轨）

推送 `v*` 标签会**同时**触发两条流水线：App Store 版和官网 Developer ID 版。

| 渠道 | Workflow | Bundle ID | 沙盒 | Quit / Force Quit | 产物 |
|------|----------|-----------|------|-------------------|------|
| Mac App Store | `release.yml` | `com.jiangcheng.MacStatusApp` | 开（MAS 强制） | 编译期移除 | `.pkg` → altool 上传 |
| 官网自分发 | `notarize.yml` | `com.jiangcheng.EasyBar` | 关（Hardened Runtime） | 完整可用 | `.dmg` → 公证 + 装订 → GitHub Release Assets |

单元测试由独立的 `test.yml` 在 push/PR 时运行（macOS runner + 完整 Xcode，`swift test`）。

> **维护提示**：`release.yml` 中的 `xcrun altool --upload-app` 已被 Apple 列入弃用计划（公证类功能已由 `notarytool` 取代）。若新版 Xcode runner 镜像移除 altool,把该步骤切换为 Transporter 或 App Store Connect API。

两版 Bundle ID 不同，可共存于同一台机器。MAS 的 ID 已在 App Store 注册，不可更改；官网版独立使用 `com.jiangcheng.EasyBar`。Developer ID 签名无需 provisioning profile 或预先注册 App ID，有 Developer ID Application 证书即可。

两版设置不互通（`UserDefaults.standard` 随 Bundle ID 隔离）。

两条流水线都不依赖 Xcode 工程：`script/release.sh` 直接编译 SPM 产物再组装 `.app`（仓库内已不再保留 `.xcodeproj`），MAS 版再用 `productbuild` 打成 `.pkg` 上传。

沙盒下 `NSRunningApplication.terminate()` 被 macOS 拦截，且用户在「隐私与安全性」无对应开关可授权，故 MAS 版用 `-D MAC_APP_STORE` 编译期剔除该功能。

### 所需 Secrets（Repo → Settings → Secrets and variables → Actions）

| Secret | 用途 |
|--------|------|
| `APPLE_DISTRIBUTION_CERT_P12` | Apple Distribution 证书 `.p12`（base64）— MAS 应用签名 |
| `APPLE_DISTRIBUTION_CERT_PASSWORD` | 该证书密码 |
| `APPLE_INSTALLER_CERT_P12` | 3rd Party Mac Developer Installer 证书 `.p12`（base64）— MAS `.pkg` 签名 |
| `APPLE_INSTALLER_CERT_PASSWORD` | 该证书密码 |
| `APPLE_PROVISIONING_PROFILE` | Mac App Store `.mobileprovision`（base64） |
| `DEVELOPER_ID_CERT_P12` | Developer ID Application 证书 `.p12`（base64）— 官网版 |
| `DEVELOPER_ID_CERT_PASSWORD` | 该证书密码 |
| `APP_STORE_CONNECT_API_KEY_ID` | API Key ID（两条流水线共用） |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID |
| `APP_STORE_CONNECT_API_KEY` | `.p8` 私钥内容（base64） |

> MAS 的 `.pkg` 必须用 **3rd Party Mac Developer Installer**（Mac Installer Distribution）证书签名，用应用签名证书会被 `altool` 以 409 拒绝。该证书需连同 Apple WWDR G3 中间证书一起导入，`release.yml` 会自动下载并导入中间证书。

> 切勿把 `.p12` / `.cer` / `.provisionprofile` / `.p8` 或 `.uploads/` 下的上传产物提交进仓库——仓库为公开仓库，私钥一旦入库即视为泄露。

可选变量（Repo → Settings → Secrets and variables → Actions → Variables）：

| Variable | 默认值 | 作用 |
|----------|--------|------|
| `BUNDLE_ID` | `com.jiangcheng.MacStatusApp` | MAS 版 Bundle ID |
| `BUNDLE_ID_DIRECT` | `com.jiangcheng.EasyBar` | 官网版 Bundle ID |

### 发布

```bash
git tag v1.15.0 && git push origin v1.15.0
```

推送 `v*` 标签后，`notarize.yml` 会把公证并装订后的 `StatusBar-<version>.dmg` 挂到对应 GitHub Release 的 Assets。Actions artifact 仍会保留一份备份。公证后用户首次打开仍会看到 Gatekeeper 提示，指引「系统设置 → 隐私与安全性 → 仍要打开」即可。

## License

MIT
