import AppKit
import Observation

@Observable
@MainActor
final class MenuBarMonitor {
    var menuBarItems: [MenuBarItem] = []
    var isMonitoring = false

    private var timer: Timer?
    private var refreshObserver: Any?
    private let settingsStore: SettingsStore
    private var showGate = AggregationShowGate()

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

        // The first scan only inventories what is already running.
        // AggregationShowGate seeds its baseline from it, so nothing that
        // was running at launch can count as "a new app appeared" — the
        // panel used to pop up on every launch before the user interacted
        // with anything.
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

    /// Refresh the item list and broadcast the auto-show signal when a *new*
    /// Status Bar app appeared while StatusBar was already running.
    ///
    /// The signal itself is gated by `showGate`: an app must persist across
    /// two consecutive scans (quit-residue helpers usually do not) and must
    /// not belong to an app the user just opened or quit from our own UI.
    /// The first call after `startMonitoring` seeds the gate's baseline, so
    /// icons already running at launch never look "new".
    func refreshMenuItems() {
        let newItems = getMenuItemsFromRunningApps()
        let oldItems = menuBarItems
        menuBarItems = newItems

        let oldStatusApps = Set(oldItems.filter { $0.appType == .statusbarOnly }.map(\.id))
        let newStatusApps = Set(newItems.filter { $0.appType == .statusbarOnly }.map(\.id))
        let membershipChanged = oldStatusApps != newStatusApps
        let presentationChanged = oldItems != newItems
        guard membershipChanged || presentationChanged else { return }

        let appeared = showGate.evaluate(newIDs: newStatusApps)
        if !appeared.isEmpty {
            NotificationCenter.default.post(name: .aggregationShouldShow, object: nil)
        }
        // Lets visible panels re-fit their frame when the app list changes.
        NotificationCenter.default.post(name: .menuBarItemsChanged, object: nil)
    }

    /// Orders items by the user's custom order first; unordered items follow
    /// alphabetically. Used by the aggregation panel and the popover.
    func sortedByCustomOrder(_ items: [MenuBarItem]) -> [MenuBarItem] {
        guard !settingsStore.customOrder.isEmpty else { return items }
        let rank = Dictionary(
            settingsStore.customOrder.enumerated().map { ($1, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return items.sorted { lhs, rhs in
            switch (rank[lhs.id], rank[rhs.id]) {
            case let (left?, right?): return left < right
            case (.some, .none): return true
            case (.none, .some): return false
            default:
                return lhs.processName.localizedCaseInsensitiveCompare(rhs.processName) == .orderedAscending
            }
        }
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
                    appType: .dockOnly
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
                    appType: .statusbarOnly
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

#if !MAC_APP_STORE
    func quitApp(_ item: MenuBarItem) {
        // A deliberately quit app — and any accessory helper that outlives
        // its parent while it winds down — must not pop the aggregation
        // panel as if a surprise icon had appeared.
        showGate.noteUserAction(bundleID: item.bundleIdentifier)
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == item.bundleIdentifier }) else { return }
        app.terminate()
    }

    func forceQuitApp(_ item: MenuBarItem) {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == item.bundleIdentifier }) else { return }
        // SIGKILL is irreversible; guard the small inline button against
        // mis-clicks with a confirmation dialog.
        let l10n = L10n.table(for: settingsStore.language)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(format: l10n.forceQuitConfirmTitle, item.processName)
        alert.informativeText = l10n.forceQuitConfirmBody
        alert.addButton(withTitle: l10n.forceQuit)
        alert.addButton(withTitle: l10n.cancel)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        showGate.noteUserAction(bundleID: item.bundleIdentifier)
        app.forceTerminate()
    }
#endif

    func activateApp(_ item: MenuBarItem) {
        // The user deliberately opened this app from our own UI: neither the
        // app nor the accessory helpers it brings along may trigger the
        // aggregation auto-show. Without this, clicking 打开 in the main
        // window popped the panel seconds later — and again when the app
        // was quit and its helper wound down.
        showGate.noteUserAction(bundleID: item.bundleIdentifier)
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

/// Gate for the "a Status Bar app just appeared" auto-show signal.
///
/// Two rules keep the signal honest:
///
/// 1. **Persistence** — an ID must be present in two consecutive scans
///    before it may fire. Quitting apps routinely leave accessory / XPC
///    helper processes behind for a few seconds (once the parent regular
///    app has exited it no longer "dominates" them, so they surface as new
///    Status Bar items); a one-scan sighting is churn, not a new icon.
/// 2. **User-initiated families** — apps the user opened or quit from our
///    own UI are deliberately caused by the user: neither the app itself
///    nor its accessory-helper family (same base bundle ID) may fire for
///    the rest of the session.
///
/// The first `evaluate` call seeds the baseline with the running set, so
/// icons present at launch never fire. Pure state machine — unit-testable
/// without AppKit.
struct AggregationShowGate {
    private var establishedIDs: Set<String> = []
    private var establishedFamilies: Set<String> = []
    private var previousIDs: Set<String> = []
    private var isPrimed = false

    /// Seeds the baseline with the IDs running at launch; these IDs can
    /// never fire afterwards.
    mutating func establishBaseline(_ ids: Set<String>) {
        establishedIDs.formUnion(ids)
        previousIDs = ids
        isPrimed = true
    }

    /// Records a deliberate user action (open / quit / force quit). The
    /// bundle ID and its helper family stop being eligible for auto-show.
    mutating func noteUserAction(bundleID: String) {
        establishedFamilies.insert(bundleID)
        if let base = MenuBarMonitor.baseBundleID(of: bundleID) {
            establishedFamilies.insert(base)
        }
    }

    /// Feeds one scan snapshot and returns the IDs that may fire the
    /// auto-show signal (empty when only churn or suppressed IDs appeared).
    mutating func evaluate(newIDs: Set<String>) -> Set<String> {
        guard isPrimed else {
            establishBaseline(newIDs)
            return []
        }
        let eligible = newIDs.filter { id in
            !establishedIDs.contains(id)
                && !isFamilyEstablished(id)
                && previousIDs.contains(id)
        }
        establishedIDs.formUnion(eligible)
        previousIDs = newIDs
        return eligible
    }

    private func isFamilyEstablished(_ id: String) -> Bool {
        establishedFamilies.contains(id)
            || establishedFamilies.contains(MenuBarMonitor.baseBundleID(of: id) ?? id)
    }
}

extension Notification.Name {
    static let refreshIntervalChanged = Notification.Name("refreshIntervalChanged")
    static let aggregationShouldShow = Notification.Name("aggregationShouldShow")
    static let menuBarItemsChanged = Notification.Name("menuBarItemsChanged")
    static let toggleAggregationPanel = Notification.Name("toggleAggregationPanel")
}
