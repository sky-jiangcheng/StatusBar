import AppKit
import Observation
import SwiftUI

@MainActor
final class StatusBarManager {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var eventMonitor: Any?
    private var localMonitor: Any?
    private var observers: [NSObjectProtocol] = []

    /// Grace window for the button-click double-toggle: a re-show within this
    /// interval of a monitor-initiated close is treated as the same click
    /// bouncing through the (already closed) popover, and is ignored.
    private static let popoverReshowGrace: TimeInterval = 0.3
    private var popoverCloseDate: Date?

    private let residentBar: ResidentBarManager

    private let menuBarMonitor: MenuBarMonitor
    private let settingsStore: SettingsStore
    private let accessibilityManager: AccessibilityManager
    private let visibilityMonitor: VisibilityMonitor
    private let systemMemoryMonitor: SystemMemoryMonitor

    init(
        menuBarMonitor: MenuBarMonitor,
        settingsStore: SettingsStore,
        accessibilityManager: AccessibilityManager,
        visibilityMonitor: VisibilityMonitor,
        systemMemoryMonitor: SystemMemoryMonitor
    ) {
        self.menuBarMonitor = menuBarMonitor
        self.settingsStore = settingsStore
        self.accessibilityManager = accessibilityManager
        self.visibilityMonitor = visibilityMonitor
        self.systemMemoryMonitor = systemMemoryMonitor
        self.residentBar = ResidentBarManager(
            menuBarMonitor: menuBarMonitor,
            settingsStore: settingsStore
        )

        setupStatusItem()
        setupPopover()
        setupEventMonitor()
        trackStatusBarButton()
    }

    /// Re-registers itself on every change: updates the menu bar icon whenever
    /// the user picks another icon style, and the tooltip whenever the app
    /// language changes.
    private func trackStatusBarButton() {
        withObservationTracking {
            _ = settingsStore.aggregationIcon
            _ = settingsStore.language
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.refreshStatusBarButton()
                self.trackStatusBarButton()
            }
        }
    }

    private func refreshStatusBarButton() {
        statusItem?.button?.image = Self.image(for: settingsStore.aggregationIcon)
        statusItem?.button?.toolTip = "Topiary — \(settingsStore.l10n.menuBarManager)"
    }

    // MARK: - Occlusion monitoring

    /// The app's own menu bar status item, for VisibilityMonitor.
    var visibilityMainItem: NSStatusItem? { statusItem }

    /// The pinned resident status items, for VisibilityMonitor.
    func visibilityPinnedItems() -> [(id: String, item: NSStatusItem)] {
        residentBar.visibilitySnapshot()
    }

    /// Removes the status item, event monitor, and all notification observers.
    /// Must run on the main actor; safe to call multiple times.
    func teardown() {
        popover.close()

        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }

        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()

        residentBar.teardown()

        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Persist the user's ⌘-dragged position across launches. macOS offers
        // no API for the initial placement (fresh items land leftmost, next to
        // the notch), but after one manual drag the system restores the spot
        // on every subsequent launch. Scoped per distribution channel so the
        // MAS and Developer ID builds keep independent positions.
        statusItem?.autosaveName = "statusItem." + (Bundle.main.bundleIdentifier ?? "topiary")

        guard let button = statusItem?.button else { return }

        button.action = #selector(statusBarButtonClicked(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        refreshStatusBarButton()
    }

    /// Menu bar icon reflects the user-selected icon style.
    private static func image(for icon: SettingsStore.AggregationIconType) -> NSImage? {
        let symbol: String
        switch icon {
        case .dots: symbol = "ellipsis"
        case .grid: symbol = "square.grid.2x2"
        case .chevron: symbol = "chevron.down"
        case .square: symbol = "square"
        case .circle: symbol = "circle"
        case .transparent: symbol = "circle.dotted"
        }
        return NSImage(systemSymbolName: symbol, accessibilityDescription: "Topiary")
    }

    private func setupPopover() {
        popover.contentSize = NSSize(width: 360, height: 520)
        popover.behavior = .transient
        popover.animates = true

        let hostingView = NSHostingView(
            rootView: PopoverView(
                onDismiss: { [weak self] in
                    self?.closePopover()
                }
            )
            .environment(menuBarMonitor)
            .environment(settingsStore)
            .environment(accessibilityManager)
            .environment(visibilityMonitor)
            .environment(systemMemoryMonitor)
        )

        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = hostingView
    }

    private func setupEventMonitor() {
        // Global monitors only see events in OTHER apps' windows: they close
        // the popover when the user clicks anywhere outside this app.
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] event in
            guard let self, self.popover.isShown else { return }
            self.closePopover()
        }

        // Local monitors see our own windows: stamping the mouseDown on the
        // status item button is what lets the button's mouseUp action tell a
        // real "close me" apart from the transient popover's own dismissal.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] event in
            guard let self,
                  let window = event.window,
                  window == self.statusItem?.button?.window,
                  self.popover.isShown else { return event }
            self.popoverCloseDate = Date()
            return event
        }
    }

    @objc private func statusBarButtonClicked(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            if popover.isShown {
                popoverCloseDate = Date()
                closePopover()
            } else if let closedAt = popoverCloseDate,
                      Date().timeIntervalSince(closedAt) < Self.popoverReshowGrace {
                // Same click: the transient popover (or the monitor) already
                // closed it — do not bounce straight back open.
                popoverCloseDate = nil
            } else {
                popoverCloseDate = nil
                showPopover()
            }
        }
    }

    private func showContextMenu() {
        let l10n = settingsStore.l10n
        let menu = NSMenu()

        let mainItem = NSMenuItem(
            title: l10n.openMainWindow,
            action: #selector(openMainWindow),
            keyEquivalent: "m"
        )
        // Display-only mirror of the Carbon global hotkey (⌃⌥M): the actual
        // app-wide trigger is registered in GlobalHotKey.
        mainItem.keyEquivalentModifierMask = [.control, .option]
        mainItem.target = self
        menu.addItem(mainItem)

        let settingsItem = NSMenuItem(
            title: l10n.settingsDots,
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: l10n.quitAppTitle,
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func openMainWindow() {
        NotificationCenter.default.post(name: .openMainWindow, object: nil)
    }

    /// Settings now lives inside the main window: summon it and switch to the
    /// settings tab (AppDelegate summons, ContentView switches).
    @objc private func openSettings() {
        NotificationCenter.default.post(name: .openSettingsTab, object: nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        popoverCloseDate = nil
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closePopover() {
        popover.performClose(nil)
    }
}
