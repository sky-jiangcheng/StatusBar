# Topiary App Store 清单

## 当前 App Store 兼容范围

- 仅使用公共 macOS API
- 通过 `NSWorkspace.shared.runningApplications` 列出运行中的应用
- 不请求屏幕录制、输入监控、文件访问、网络访问或自动化权限
- **不请求辅助功能（Accessibility）权限**：仅在界面上只读展示 `AXIsProcessTrusted()` 的结果，未授权不影响任何功能
- 包含最小 App Sandbox 授权文件 `Sources/topiary-bar/Resources/topiary-bar.entitlements`
- App 图标源文件在 `design/leaf-icon`
- 发布流程不依赖 Xcode 工程：`script/release.sh` 直接编译 SPM 产物并组装 `.app`

## 提交前必要步骤

1. 安装完整 Xcode、同意许可并用 `xcode-select` 选择（`xcode-select -p` 必须指向 `Xcode.app`，否则 SwiftUI 宏插件缺失，构建会失败）
2. 本地跑通一次发布构建：`CHANNEL=mas SIGNING_IDENTITY="Apple Distribution: …" bash script/release.sh`
3. 在 Apple Developer 后台确认 / 创建 `com.jiangcheng.MacStatusApp` 的 App ID
4. 创建并下载 Mac App Store 类型的 provisioning profile
5. 确认 App Sandbox 由 `Sources/topiary-bar/Resources/topiary-bar.entitlements` 启用（MAS 渠道的 `-D MAC_APP_STORE` 会编译期移除 Quit / Force Quit）
6. 核对 `script/release.sh` 中内嵌的 `Info.plist`：Bundle ID、版本号（`APP_VERSION` / `BUILD_NUMBER`）、`LSMinimumSystemVersion`、分类
7. 隐私营养标签：**不收集任何数据**
8. 重新截取 App Store 截图。`AppStoreScreenshots/` 里的文件仍是改版前的旧品牌命名（`macstatus-*`），与当前 UI 不符
9. 上传：走 CI（`.github/workflows/release.yml`，推送 `v*` 标签）或手动
   `xcrun altool --upload-app --type macos --file "dist/Topiary.pkg" --apiKey … --apiIssuer …`

## 构建与打包（唯一流程）

| 渠道 | 命令 | Bundle ID | 沙盒 | 产物 |
|------|------|-----------|------|------|
| Mac App Store | `CHANNEL=mas bash script/release.sh` | `com.jiangcheng.MacStatusApp` | 开 | `dist/Topiary.pkg` → altool |
| 官网自分发 | `CHANNEL=devid bash script/release.sh` | `com.jiangcheng.EasyBar` | 关 | `dist/Topiary.app` → DMG → 公证 → GitHub Release Assets |

必需环境变量：`SIGNING_IDENTITY`（mas：`Apple Distribution: …`；devid：`Developer ID Application: …`），其余可选变量见 `script/release.sh` 头部注释。

本地开发用 `script/build_and_run.sh`，它采用 devid 渠道的 Bundle ID 与 entitlements（沙盒关闭）。

## 重要约束

全局快捷键使用 Carbon `RegisterEventHotKey`（`Control + Option + M` 唤起主窗口）：事件由系统直接投递给本进程，无需辅助功能权限，沙盒下可用。菜单栏图标右键菜单提供 `Control + Option + M`（打开主窗口）、`Command ,`（打开设置）和 `Command Q`（退出）；弹窗底栏同样提供 设置 / 打开主窗口 / 退出 三个入口。

## 已知限制

- Status Bar 应用无法通过 `NSRunningApplication.activate()` 激活（macOS 安全限制），本应用对 accessory 应用使用 `NSWorkspace.openApplication(at:configuration:)` 唤起
- 部分 accessory app（如 Macs Fan Control）无法被其他 app 激活
- App 类型检测基于 `activationPolicy`，无法读取真实的状态栏图标归属
- 聚合面板不会隐藏系统菜单栏图标（v1.6.0 起移除 AX 隐藏方案），仅在菜单栏下方浮动显示
- 暗色 App 图标变体（`Assets.xcassets/AppIcon.appiconset/dark/`）只在 Xcode 资产目录（`Assets.car`）流程下生效；`script/release.sh` 用 `iconutil` 生成 `.icns`，该格式只包含浅色图标
- MAS 沙盒下 `NSRunningApplication.terminate()` 被系统拦截，因此 mas 渠道用 `-D MAC_APP_STORE` 编译期剔除退出功能

