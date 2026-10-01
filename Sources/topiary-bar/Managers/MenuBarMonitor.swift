import AppKit
import Darwin
import Observation

@Observable
@MainActor
final class MenuBarMonitor {
    var menuBarItems: [MenuBarItem] = []
    var isMonitoring = false

    private var timer: Timer?
    private var refreshObserver: Any?
    private let settingsStore: SettingsStore

    enum AppType: String {
        case statusbarOnly = "Status Bar"
        case dockOnly = "Dock"
    }

    struct MenuBarItem: Identifiable, Hashable {
        let id: String
        let bundleIdentifier: String
        let processName: String
        let icon: NSImage?
        let appType: AppType
        /// Process identifier, for memory-footprint lookups.
        var pid: pid_t = -1
        /// Physical memory footprint in bytes (Activity Monitor's "Memory"
        /// column); nil when unavailable, e.g. in the sandboxed MAS build.
        var memoryFootprint: UInt64? = nil

        // Identity deliberately excludes pid/memoryFootprint: live values
        // change every scan and must not re-identify items (SwiftUI list
        // diffs, pin state, detail-pane selection all key off identity).

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(processName)
            hasher.combine(appType)
        }

        static func == (lhs: MenuBarItem, rhs: MenuBarItem) -> Bool {
            lhs.id == rhs.id
                && lhs.bundleIdentifier == rhs.bundleIdentifier
                && lhs.processName == rhs.processName
                && lhs.appType == rhs.appType
                && lhs.icon === rhs.icon
        }
    }

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        // Initial inventory so the icon list is populated immediately.
        refreshMenuItems()
        startTimer()

        refreshObserver = NotificationCenter.default.addObserver(
            forName: .refreshIntervalChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.restartTimer()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        if let observer = refreshObserver {
            NotificationCenter.default.removeObserver(observer)
            refreshObserver = nil
        }
        isMonitoring = false
    }

    private func startTimer() {
        timer?.invalidate()
        let interval = settingsStore.refreshInterval > 0 ? settingsStore.refreshInterval : 2.0
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshMenuItems()
            }
        }
    }

    private func restartTimer() {
        guard isMonitoring else { return }
        startTimer()
    }

    /// Rebuilds the item list from the running apps. The aggregation panel is
    /// manual-only (summoned by the user), so a changed list only fans out a
    /// layout-changed notice so a visible panel can re-fit its frame.
    func refreshMenuItems() {
        let newItems = getMenuItemsFromRunningApps()
        guard newItems != menuBarItems else { return }
        menuBarItems = newItems
        NotificationCenter.default.post(name: .menuBarItemsChanged, object: nil)
    }

    private func getMenuItemsFromRunningApps() -> [MenuBarItem] {
        var items: [MenuBarItem] = []
        let runningApps = NSWorkspace.shared.runningApplications

        // The app itself is excluded dynamically via Bundle.main above (the
        // bundle ID differs per distribution channel), so only system agents
        // are listed here.
        let skipBundleIDs: Set<String> = [
            "com.apple.Spotlight",
            "com.apple.WindowManager",
            "com.apple.notificationcenterui",
            "com.apple.controlcenter",
            "com.apple.controlcenter.helper",
            "com.apple.dock",
            "com.apple.dock.helper",
            "com.apple.dock.extra",
            "com.apple.Siri",
            "com.apple.loginwindow",
            "com.apple.CoreLocationAgent",
            "com.apple.coreservices.uiagent",
            "com.apple.backgroundtaskmanagement.agent",
            "com.apple.SoftwareUpdateNotificationManager",
            "com.apple.UserNotificationCenter",
            "com.apple.Security.keychain-circle-Notification",
            "com.apple.accessibility.universalAccessAuthWarn",
            "com.apple.LocalAuthentication.UIAgent",
            "com.apple.talagent",
            "com.apple.storeuid",
            "com.apple.TextInputMenuAgent",
            "com.apple.TextInputSwitcher",
            "com.apple.wifi.WiFiAgent",
            "com.apple.AirPlayUIAgent",
            "com.apple.universalcontrol",
            "com.apple.AccessibilityUIServer",
            "com.apple.wallpaper.agent",
            "com.apple.PowerChime",
            "com.apple.WorkflowKit.ShortcutsViewService",
            "com.apple.systemuiserver",
        ]

        for app in runningApps {
            guard !app.isTerminated,
                  let bundleID = app.bundleIdentifier,
                  let name = app.localizedName,
                  !bundleID.isEmpty,
                  !name.isEmpty else {
                continue
            }

            if bundleID == Bundle.main.bundleIdentifier { continue }
            if skipBundleIDs.contains(bundleID) { continue }

            if app.activationPolicy == .regular {
                let item = MenuBarItem(
                    id: bundleID,
                    bundleIdentifier: bundleID,
                    processName: name,
                    icon: app.icon,
                    appType: .dockOnly,
                    pid: app.processIdentifier,
                    memoryFootprint: Self.physFootprint(pid: app.processIdentifier)
                )
                items.append(item)
            } else if app.activationPolicy == .accessory {
                guard !bundleID.hasPrefix("com.apple.WebKit.") else { continue }
                guard !bundleID.hasPrefix("com.apple.") else { continue }

                // Heuristic: treat an accessory process as a helper of a regular app
                // when both share the same first two bundle-ID segments (com.docker.*
                // under com.docker). Segment-aligned equality (not prefix matching)
                // prevents false positives such as com.docker absorbing com.dockerized.app.
                let ownBase = Self.baseBundleID(of: bundleID)
                let dominatedByParent = ownBase != nil && runningApps.contains { other in
                    guard other.bundleIdentifier != bundleID,
                          other.activationPolicy == .regular,
                          let otherBase = Self.baseBundleID(of: other.bundleIdentifier ?? "")
                    else { return false }
                    return otherBase == ownBase
                }
                guard !dominatedByParent else { continue }

                let item = MenuBarItem(
                    id: bundleID,
                    bundleIdentifier: bundleID,
                    processName: name,
                    icon: app.icon,
                    appType: .statusbarOnly,
                    pid: app.processIdentifier,
                    memoryFootprint: Self.physFootprint(pid: app.processIdentifier)
                )
                items.append(item)
            }
        }

        return items.sorted { $0.processName.localizedCaseInsensitiveCompare($1.processName) == .orderedAscending }
    }

    /// First two segments of a bundle identifier ("com.docker" from
    /// "com.docker.helper"); nil when the identifier has fewer than two segments.
    /// `nonisolated` (pure string logic) and internal for unit tests.
    static nonisolated func baseBundleID(of identifier: String) -> String? {
        let parts = identifier.split(separator: ".").map(String.init)
        guard parts.count >= 2 else { return nil }
        return parts.prefix(2).joined(separator: ".")
    }

    /// Physical memory footprint of a process in bytes (Activity Monitor's
    /// "Memory" column reads the same `ri_phys_footprint`). nil when the
    /// lookup fails. Compiled out of the sandboxed MAS build: reading other
    /// processes' rusage is outside the App Store sandbox contract.
    static func physFootprint(pid: pid_t) -> UInt64? {
#if MAC_APP_STORE
        return nil
#else
        var usage = rusage_info_current()
        let result = withUnsafeMutablePointer(to: &usage) { ptr in
            ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { infoPtr in
                proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, infoPtr)
            }
        }
        guard result == 0 else { return nil }
        return usage.ri_phys_footprint
#endif
    }

#if !MAC_APP_STORE
    /// Quits the app with a single button: graceful `terminate()` first, then
    /// automatic escalation to `forceTerminate()` if it is still alive after a
    /// short grace period. Replaces the old quit/force-quit pair, which read
    /// as two identical outcomes to the user.
    func quitApp(_ item: MenuBarMonitor.MenuBarItem) {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == item.bundleIdentifier }) else { return }
        app.terminate()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !app.isTerminated else { return }
            app.forceTerminate()
        }
    }
#endif

    /// Whether "Open" can actually bring this app forward. Dock apps respond
    /// to `activate()` unconditionally; accessory apps need a bundle URL for
    /// the `openApplication` re-launch path, otherwise the button would be a
    /// no-op and should not be shown at all.
    func canOpen(_ item: MenuBarMonitor.MenuBarItem) -> Bool {
        guard NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == item.bundleIdentifier }) else {
            return false
        }
        if item.appType == .dockOnly { return true }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleIdentifier) != nil
    }

    /// Whether "Quit" is meaningful. Finder ignores terminate (it relaunches),
    /// so the button would be dead weight there.
    func canQuit(_ item: MenuBarMonitor.MenuBarItem) -> Bool {
        item.bundleIdentifier != "com.apple.Finder"
    }

    func activateApp(_ item: MenuBarItem) {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == item.bundleIdentifier }) else { return }
        app.unhide()
        if item.appType == .statusbarOnly {
            // NSRunningApplication.activate() cannot foreground accessory apps
            // (macOS security restriction). Re-opening the bundle activates a
            // running app (or launches it if it quit in the meantime), which
            // replaces the deprecated launchApplication(withBundleIdentifier:).
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            guard let url = app.bundleURL ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleIdentifier) else {
                // Some accessory processes have no bundle URL. `activate()` is
                // best-effort for those, but better than silently doing nothing.
                app.activate()
                return
            }
            Task {
                _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: config)
            }
        } else {
            app.activate()
        }
    }
}

extension Notification.Name {
    static let refreshIntervalChanged = Notification.Name("refreshIntervalChanged")
    static let menuBarItemsChanged = Notification.Name("menuBarItemsChanged")
    /// Summon the main window (AppDelegate handles the actual window work).
    static let openMainWindow = Notification.Name("openMainWindow")
    /// Summon the main window and switch it to the settings tab.
    static let openSettingsTab = Notification.Name("openSettingsTab")
    /// Switch the (already visible) main window to the settings tab.
    static let selectSettingsTab = Notification.Name("selectSettingsTab")
}
