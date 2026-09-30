# Changelog

> 🌐 [English](README.md) · [简体中文](README.zh-CN.md)

所有 notable 变更记录于此；各版本产物见 [GitHub Releases](https://github.com/sky-jiangcheng/status-bar/releases)。

| 版本 | 内容 |
|------|------|
| v1.20.0 | UI 重设计 + 品牌命名分层：新增设计系统组件（AppIconView / AppTypeBadge / RowActionButton / StatChip）；主窗口分组列表 + 概览页 + 应用详情页（新增常驻开关与唤起提示）；弹窗按类型分组、行按钮悬停显现；聚合面板改 HUD 毛玻璃材质、图标块升级；紫/绿类型配色改为中性徽章；仓库 / 包 / 目录迁移 kebab-case（`status-bar`），App 显示名保持 StatusBar |
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
