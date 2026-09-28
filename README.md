# StatusBar

macOS 菜单栏管理工具：自动检测并管理状态栏与 Dock 应用。

- 下载：https://github.com/sky-jiangcheng/StatusBar/releases/latest
- 源码与 Issue：https://github.com/sky-jiangcheng/StatusBar

官网版（Developer ID）含 Quit / Force Quit；Mac App Store 版受沙盒限制，这两项在编译期移除。两版 Bundle ID 不同，可同时安装，设置互不共享。

## 安装

1. 从 [GitHub Releases](https://github.com/sky-jiangcheng/StatusBar/releases/latest) 下载 `StatusBar-<version>.dmg`
2. 打开 DMG，把 `StatusBar.app` 拖到 Applications
3. 首次打开若出现 Gatekeeper 提示：系统设置 → 隐私与安全性 → 仍要打开

## 功能特性

### 核心功能
- **App 类型自动检测**：基于 `activationPolicy` 区分 Status Bar 与 Dock 应用
- **状态栏常驻（后台代理）**：以 `LSUIElement` 后台代理方式运行（无程序坞图标），关闭任何窗口都不会退出应用，因此常驻图标持续保留；退出需从状态栏右键菜单操作
- **操作按钮**：打开、退出、强制退出（官网版）
- **实时监控**：按设置间隔刷新运行中的应用列表
- **搜索过滤**：按名称或 Bundle ID 搜索

### 个性化
- **外观主题**：跟随系统 / 浅色 / 深色，全局即时生效
- **多语言**：简体中文 / English / 日本語 / Deutsch / Español，可跟随系统或手动切换

### 界面
- **主窗口**：HSplitView，左侧 sidebar（搜索 + 类型筛选 + 应用列表） + 右侧详情（概览统计 + 所选应用详情与操作）
- **Stat Cards**：Total / Status Bar / Dock，点击联动过滤
- **Popover**：菜单栏聚合入口（搜索 + 应用列表 + 面板开关 / 主窗口 / 设置）
- **状态栏常驻**：你勾选的应用图标会直接入住 macOS 顶部菜单栏，每个应用一个常驻图标，始终可见、无需弹出任何窗口。左键点击唤起对应应用，右键菜单可打开 / 从常驻栏移除 / 退出。桌面不再浮动黑框（v1.19.0 的聚合面板不再自动弹出）。
- **常驻管理**：点状态栏图标（/ 右键菜单）唤出管理面板，用「+」把应用加入常驻栏、悬停图标「×」移除；常驻图标本身也可右键移除。勾选结果持久保存，重启仍生效。
- **排序页**：拖拽自定义菜单栏图标顺序；「未排序」可插入到指定行之前，顺序内可用删除手势移出

### App 类型

| 类型 | 说明 | 激活方式 |
|------|------|----------|
| Status Bar | 仅有状态栏图标，无 Dock 图标 | `openApplication(at:configuration:)`（`activates = true`） |
| Dock | 有 Dock 图标 | `activate` |

## 技术栈

- **语言**：Swift 6.0
- **框架**：SwiftUI + AppKit
- **架构**：`@Observable`（Observation framework）
- **构建**：Swift Package Manager

## 本地运行

```bash
./script/build_and_run.sh
swift build
./script/build_and_run.sh run
```

`script/build_and_run.sh` 产出 `dist/StatusBar.app`，使用官网 Bundle ID（`com.jiangcheng.EasyBar`）与 Developer ID entitlements（沙盒关闭）。MAS 渠道由 `script/release.sh` 的 `mas` 分支负责。

额外模式：`--debug`（lldb）/ `--logs`（日志流）/ `--verify`（启动自检）。

## 系统要求

- macOS 14.0+
- 不请求任何权限。界面只读展示 `AXIsProcessTrusted()` 的结果，未开启不影响功能

### 构建环境

- Swift 6.0+，macOS 14+ SDK
- 需要完整 Xcode：`xcode-select -p` 必须指向 `Xcode.app`，并已执行 `sudo xcodebuild -license accept`
- 仅装 Command Line Tools 时，SwiftUI 宏插件缺失（`plugin for module 'SwiftUIMacros' not found`）；Swift 6.4 起 `swift build` 默认 `swiftbuild`，CLT-only 会以 `Unknown error parsing property list` 失败
- 临时绕过（未能切换 Xcode 时）：

```bash
swift build --build-system native \
  -Xswiftc -plugin-path \
  -Xswiftc /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins
```

- `swift test` 需要完整 Xcode 的 `XCTest` 与 `xctest` runner；CI（`test.yml`）在切换到 Xcode 后执行

## 项目结构

```
StatusBar/
├── Package.swift
├── Sources/StatusBar/
│   ├── App/                    # 入口、设置窗口、状态栏调度
│   ├── Managers/               # 监控、设置、本地化、聚合面板
│   ├── Views/                  # 主窗口 / Popover / 设置 / 排序
│   └── Resources/              # entitlements、Assets.xcassets
├── Tests/StatusBarTests/       # swift test（纯逻辑）
├── script/
│   ├── build_and_run.sh        # 本地：构建 + 签名 + 运行
│   └── release.sh              # 发布：mas / devid
├── tools/                      # 图标与截图生成
├── design/leaf-icon/           # App 图标设计稿
└── docs/                       # GitHub Pages（中英双语）
```

## 已知限制

- Status Bar 应用无法通过 `NSRunningApplication.activate()` 激活；本应用对 accessory 应用使用 `NSWorkspace.openApplication(at:configuration:)`（`activates = true`）唤起
- 部分 accessory app（如 Macs Fan Control）无法被其他 app 激活
- App 类型基于 `activationPolicy`，无法读取真实的状态栏图标归属
- 聚合面板不再自动弹出；勾选应用改为直接常驻系统菜单栏（v1.19.5 起）。面板仅作为手动「+」添加应用的管理界面保留
- MAS 沙盒拦截 `NSRunningApplication.terminate()`，故 mas 渠道用 `-D MAC_APP_STORE` 编译期剔除退出功能

## CI/CD 发布（双轨）

推送 `v*` 标签会同时触发 App Store 与官网 Developer ID 两条流水线。

| 渠道 | Workflow | Bundle ID | 沙盒 | Quit / Force Quit | 产物 |
|------|----------|-----------|------|-------------------|------|
| Mac App Store | `release.yml` | `com.jiangcheng.MacStatusApp` | 开（MAS 强制） | 编译期移除 | `.pkg` → altool 上传 |
| 官网自分发 | `notarize.yml` | `com.jiangcheng.EasyBar` | 关（Hardened Runtime） | 完整可用 | `.dmg` → 公证 + 装订 → GitHub Release Assets |

单元测试由 `test.yml` 在 push/PR 时运行（macOS runner + 完整 Xcode，`swift test`）。

`release.yml` 中的 `xcrun altool --upload-app` 已列入 Apple 弃用计划。若 runner 镜像移除 altool，改为 Transporter 或 App Store Connect API。

MAS 的 Bundle ID 已在 App Store 注册，不可更改。Developer ID 签名无需 provisioning profile 或预先注册 App ID。设置随 Bundle ID 隔离。

两条流水线都走 `script/release.sh`：编译 SPM 产物再组装 `.app`；MAS 再用 `productbuild` 打成 `.pkg`。

### Secrets

Repo → Settings → Secrets and variables → Actions：

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

MAS 的 `.pkg` 必须用 **3rd Party Mac Developer Installer** 证书签名，用应用签名证书会被 `altool` 以 409 拒绝。`release.yml` 会下载并导入 Apple WWDR G3 中间证书。

不要把 `.p12` / `.cer` / `.provisionprofile` / `.p8` 或 `.uploads/` 提交进仓库。

可选变量（Actions → Variables）：

| Variable | 默认值 | 作用 |
|----------|--------|------|
| `BUNDLE_ID` | `com.jiangcheng.MacStatusApp` | MAS 版 Bundle ID |
| `BUNDLE_ID_DIRECT` | `com.jiangcheng.EasyBar` | 官网版 Bundle ID |

### 发布

```bash
git tag v1.18.0 && git push origin v1.18.0
```

标签推送后，`notarize.yml` 把 `StatusBar-<version>.dmg` 挂到该 GitHub Release；Actions artifact 另留一份备份。

## 版本历史

| 版本 | 内容 |
|------|------|
| v1.19.8 | 移除设置页无实际作用的「聚合/标准/禁用」三种运行模式（历史遗留的空选项），连同弹出页模式徽标一并清理 |
| v1.19.7 | 修复 ResidentBarManager 编译错误与遍历时改字典崩溃 |
| v1.19.6 | 后台代理化：`LSUIElement` 无程序坞图标，关任何窗口不退出，常驻图标持续保留（真正常驻）；菜单栏类应用点击无界面属 macOS 限制 |
| v1.19.5 | 状态栏常驻：勾选应用图标直接入住系统菜单栏（每应用一个常驻图标，左键唤起 / 右键管理），启动不再自动弹出浮动面板，解决桌面黑框干扰 |
| v1.19.4 | 常驻面板管理：+ 添加 / 悬停 × 移除 / 持久化 pinnedAppIDs |
| v1.19.3 | 修复聚合面板自动弹出 / 自动收起逻辑 |
| v1.19.0 | 使用体验修复：启动不再自动弹出聚合面板（仅响应运行期间新出现的菜单栏应用）；面板补标题栏计数与 × 关闭按钮、支持 Esc、固定深色外观、禁止误拖；主窗口补搜索框、行选中与右侧应用详情、操作按钮改为 hover 显隐；popover 底部补主窗口入口与面板开关（带状态） |
| v1.18.0 | 应用图标更换为滑块玻璃面板：按 1024 满幅 + 烘焙圆角重新生成，兼容 macOS 12+ 与 macOS 26/27 新图标网格；补深色外观；`tools/generate_app_icon.py` 可复现生成 |
| v1.17.0 | 发布链路修复：MAS `.pkg` 改用 3rd Party Mac Developer Installer 签名并导入 WWDR G3；描述文件 UUID 改用 grep；停止跟踪证书 / 描述文件等上传产物 |
| v1.16.0 | 品牌统一：StatusBar Pro → StatusBar；仓库与 Pages 从 EasyBar 迁至 StatusBar |
| v1.15.0 | 修复排序页自动写入导致「未排序」失效；区分 Normal/Disabled 模式；完善测试与构建验证 |
| v1.14.0 | 代码 review（P0×3 / P1×7 / P2×3）：聚合面板点击激活、Popover 双 toggle 竞态、hover 暂停自动隐藏、Force Quit 二次确认、`Bundle.main` 自排除、`openApplication` 迁移、Layout 常量收敛、单元测试 + CI；外观主题；多语言 |
| v1.13.0 | Status Bar app 跳转修复 |
| v1.12.0 | App 类型检测 + 移除 hide 功能 |
| v1.11.0 | 移除 hasStatusBar 自动检测 |
| v1.10.0 | accessory app 检测 + eye icon 手势修复 |
| v1.9.0 | HSplitView 布局 + stat card 联动 |
| v1.8.0 | UI 重新设计 + Sidebar 修复 |
| v1.7.0 | Quit/force-quit + App 状态检测 |
| v1.6.0 | 移除 AX 隐藏，纯 UI 聚合方案 |
| v1.5.0 | AX API 兼容性 + debug 工具 |
| v1.4.0 | AggregationPanel 可达 + iconSpacing |
| v1.3.0 | P0/P1 code review 修复 |
| v1.2.0 | Window + status bar 支持 |
| v1.1.0 | Phase 1-5 完整实现 |
