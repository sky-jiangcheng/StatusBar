# StatusBar: macOS Menu Bar Manager

See, launch, quit, and pin every menu bar app running on your Mac. **No permissions requested, no analytics, nothing leaves your device** — distributed as a notarized Developer ID build and on the Mac App Store.

> 🌐 **English** · [简体中文](README.zh-CN.md)

> **Official site** → [sky-jiangcheng.github.io/status-bar](https://sky-jiangcheng.github.io/status-bar/)

[![Release](https://img.shields.io/github/v/release/sky-jiangcheng/status-bar?label=release&color=blue)](https://github.com/sky-jiangcheng/status-bar/releases)
[![Test](https://github.com/sky-jiangcheng/status-bar/actions/workflows/test.yml/badge.svg)](https://github.com/sky-jiangcheng/status-bar/actions/workflows/test.yml)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange?logo=swift&logoColor=white)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-14%2B-black?logo=apple&logoColor=white)](https://www.apple.com/macos/)

---

## Table of Contents

- [Core Features](#core-features)
- [App Types](#app-types)
- [Install](#install)
- [Build from Source](#build-from-source)
- [Release Pipeline (CI/CD)](#release-pipeline-cicd)
- [Known Limitations](#known-limitations)
- [Privacy](#privacy)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Documentation Index](#documentation-index)
- [Changelog](#changelog)
- [License](#license)

---

## Core Features

### 📌 Menu Bar Residency

| Feature | Description |
|---------|-------------|
| **Pin to menu bar** | Pinned app icons live directly in the macOS menu bar — one resident status item per app, always visible, no window or panel needed. Left-click activates the app; right-click offers open / unpin / quit |
| **Aggregation panel** | A manual management panel under the menu bar: add apps with `+`, hover an icon and click `×` to unpin (v1.19.5: the panel no longer auto-pops, so no floating box over your desktop) |
| **Persistence** | Pins and custom order survive relaunch (stored per distribution channel in `UserDefaults`) |

### 🚦 App Management

| Feature | Description |
|---------|-------------|
| **Auto detection** | Classifies running apps as Status Bar (accessory) vs. Dock (regular) via `activationPolicy` |
| **One-click actions** | Open, quit, and force quit (quit/force quit compiled out of the sandboxed Mac App Store build) |
| **Accessory wake-up** | macOS refuses to foreground accessory apps via `NSRunningApplication.activate()`; StatusBar re-launches them with `NSWorkspace.openApplication(at:configuration:)` (`activates = true`) |
| **Live monitoring** | Running-app list refreshes on a 1/2/5 s interval |
| **Search & filter** | By name or bundle ID, in both the main window and the popover |

### 🎨 Interface

| Feature | Description |
|---------|-------------|
| **Main window** | Sidebar (search + type filter + grouped app list with per-section counts) and a detail pane: brand overview with compact stats when nothing is selected, full app details with a pin toggle when an app is |
| **Menu bar popover** | Type-grouped app list with search; panel toggle / main window / settings in the footer; row actions reveal on hover |
| **Aggregation panel** | HUD vibrancy material, 5-column icon grid, hover feedback, auto-dismiss |
| **Themes** | System / light / dark, applied instantly app-wide |
| **Localization** | English, 简体中文, 日本語, Deutsch, Español — follow the system or pick manually |
| **Custom order** | Drag to reorder; unordered apps can be dropped into a specific position |

## App Types

| Type | Description | Activation |
|------|-------------|------------|
| Status Bar | Menu bar icon only, no Dock icon | `openApplication(at:configuration:)` (`activates = true`) |
| Dock | Has a Dock icon | `activate` |

## Install

1. Download `StatusBar-<version>.dmg` from [GitHub Releases](https://github.com/sky-jiangcheng/status-bar/releases/latest)
2. Open the DMG and drag `StatusBar.app` into Applications
3. On first launch, if Gatekeeper asks: System Settings → Privacy & Security → Open Anyway

The Developer ID build (notarized DMG) includes Quit / Force Quit. The Mac App Store build is sandboxed and ships without them. Both can be installed side by side (different bundle IDs, isolated settings).

## Build from Source

```bash
./script/build_and_run.sh   # build, sign (ad-hoc), and launch dist/StatusBar.app
swift build                 # build only
./script/build_and_run.sh run
```

Extra modes: `--debug` (lldb) / `--logs` (log stream) / `--verify` (launch self-check).

Requirements:

- Swift 6.0+, macOS 14+ SDK
- **Full Xcode required**: `xcode-select -p` must point to `Xcode.app` (accept the license with `sudo xcodebuild -license accept`). SwiftUI macro plugins ship with Xcode; with only Command Line Tools the build fails with `plugin for module 'SwiftUIMacros' not found`, and since Swift 6.4 the default `swiftbuild` build system fails outright with `Unknown error parsing property list`
- Workaround when Xcode selection isn't possible:

```bash
swift build --build-system native \
  -Xswiftc -plugin-path \
  -Xswiftc /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins
```

- `swift test` needs full Xcode's `XCTest` and runner; CI (`test.yml`) runs it after selecting Xcode

## Release Pipeline (CI/CD)

Pushing a `v*` tag triggers two pipelines at once:

| Channel | Workflow | Bundle ID | Sandbox | Quit / Force Quit | Artifact |
|---------|----------|-----------|---------|-------------------|----------|
| Mac App Store | `release.yml` | `com.jiangcheng.MacStatusApp` | On (MAS enforced) | Compiled out | `.pkg` → uploaded via altool |
| Developer ID | `notarize.yml` | `com.jiangcheng.EasyBar` | Off (Hardened Runtime) | Fully available | `.dmg` → notarized + stapled → attached to the GitHub Release |

Unit tests run on every push/PR via `test.yml` (macOS runner + full Xcode, `swift test`).

Both pipelines drive `script/release.sh`: compile the SPM product and assemble the `.app`; the MAS channel additionally wraps it into a `.pkg` with `productbuild`.

> The MAS `.pkg` must be signed with a **3rd Party Mac Developer Installer** certificate. `release.yml` also imports the Apple WWDR G3 intermediate certificate. Required secrets live in Repo → Settings → Secrets and variables → Actions (cert `.p12` + passwords, provisioning profile, App Store Connect API key/issuer); optional `BUNDLE_ID` / `BUNDLE_ID_DIRECT` variables override the bundle IDs. Never commit `.p12` / `.cer` / `.provisionprofile` / `.p8` files.

> `xcrun altool --upload-app` is on Apple's deprecation path; if a runner image drops it, switch that step to Transporter or the App Store Connect API.

To cut a release:

```bash
git tag v1.20.1 && git push origin v1.20.1
```

## Known Limitations

- Status Bar (accessory) apps cannot be foregrounded with `NSRunningApplication.activate()` — a macOS security restriction. StatusBar re-launches them via `NSWorkspace.openApplication` (`activates = true`); activation timing differs slightly from the deprecated `launchApplication(withBundleIdentifier:)`, and a few accessory apps (e.g. Macs Fan Control) can't be raised by other apps at all
- App typing is based on `activationPolicy`, so the real owner of a menu bar icon cannot be read
- The aggregation panel does not hide real system menu bar icons (the AX-based hiding was removed in v1.6.0); it is a manual management surface only
- Dark app icon variants (`Assets.xcassets/AppIcon.appiconset/dark/`) only apply via the Xcode asset-catalog (`Assets.car`) flow; `script/release.sh` generates a light-only `.icns` via `iconutil`
- Under MAS sandbox, `NSRunningApplication.terminate()` is blocked with no user-facing toggle, so the MAS build strips Quit / Force Quit at compile time via `-D MAC_APP_STORE`

## Privacy

No permissions requested. The app lists running applications via public APIs, reads the `AXIsProcessTrusted()` state for a read-only indicator, and processes everything locally — **no analytics, no network access, no data collection**. See the [Privacy Policy](https://sky-jiangcheng.github.io/status-bar/privacy/).

## Tech Stack

- **Language**: Swift 6.0
- **Frameworks**: SwiftUI + AppKit
- **Architecture**: `@Observable` (Observation framework)
- **Build**: Swift Package Manager (no `.xcodeproj`; release scripts assemble the `.app`)
- **Background agent**: `LSUIElement` — closing every window keeps the resident menu bar icons alive

## Project Structure

```
status-bar/
├── Package.swift
├── Sources/status-bar/
│   ├── App/                    # Entry point, settings window, status bar controller
│   ├── Managers/               # Monitoring, resident bar, settings, localization, panel
│   ├── Views/                  # Main window / popover / panel / settings / theme components
│   └── Resources/              # entitlements, Assets.xcassets
├── Tests/status-bar-tests/     # Unit tests (swift test, logic only)
├── script/
│   ├── build_and_run.sh        # Local: build + sign + run
│   └── release.sh              # Release: mas / devid channels
├── tools/                      # Icon & screenshot tooling
├── design/leaf-icon/           # App icon design sources
└── docs/                       # GitHub Pages (EN / zh-CN)
```

## Documentation Index

- [docs/AppStoreChecklist.md](docs/AppStoreChecklist.md) — Mac App Store submission checklist (Chinese)
- [CHANGELOG.md](CHANGELOG.md) — version history
- [Official site](https://sky-jiangcheng.github.io/status-bar/) · [Support](https://sky-jiangcheng.github.io/status-bar/support/) · [Privacy Policy](https://sky-jiangcheng.github.io/status-bar/privacy/)

## Changelog

See [CHANGELOG.md](CHANGELOG.md); releases and artifacts are on [GitHub Releases](https://github.com/sky-jiangcheng/status-bar/releases).

## License

[MIT](LICENSE)
