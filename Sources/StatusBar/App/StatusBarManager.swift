import AppKit
import Observation
import SwiftUI

@MainActor
final class StatusBarManager {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var eventMonitor: Any?
    private var localMonitor: Any?
    private var aggregationAutoHideTimer: Timer?
    private var observers: [NSObjectProtocol] = []

    /// Grace window for the button-click double-toggle: a re-show within this
    /// interval of a monitor-initiated close is treated as the same click
    /// bouncing through the (already closed) popover, and is ignored.
    private static let popoverReshowGrace: TimeInterval = 0.3
    private var popoverCloseDate: Date?

    /// Auto-hide countdown bookkeeping: when the timer was armed and how much
    /// of the delay remains, so hovering the panel can pause and resume it.
    private var autoHideStartDate = Date()
    private var remainingAutoHideDelay: TimeInterval = 0

    private let aggregationPanel: AggregationPanel

    private let menuBarMonitor: MenuBarMonitor
    private let settingsStore: SettingsStore
    private let accessibilityManager: AccessibilityManager

    init(menuBarMonitor: MenuBarMonitor, settingsStore: SettingsStore, accessibilityManager: AccessibilityManager) {
        self.menuBarMonitor = menuBarMonitor
        self.settingsStore = settingsStore
        self.accessibilityManager = accessibilityManager
        self.aggregationPanel = AggregationPanel(
            menuBarMonitor: menuBarMonitor,
            settingsStore: settingsStore
        )
        // Hovering the panel pauses the auto-hide countdown (mouseEntered/Exited
        // arrive on the main thread, but hop explicitly to stay actor-correct).
        self.aggregationPanel.onHoverChange = { [weak self] hovering in
            Task { @MainActor in
                guard let self else { return }
                if hovering {
                    self.pauseAggregationAutoHide()
                } else {
                    self.resumeAggregationAutoHide()
                }
            }
        }

        setupStatusItem()
        setupPopover()
        setupEventMonitor()
        setupNotifications()
        trackStatusBarButton()
    }

    /// Re-registers itself on every change: updates the menu bar icon whenever
    /// the user picks another aggregation icon style, and the tooltip whenever
    /// the app language changes.
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
        statusItem?.button?.toolTip = "StatusBar — \(settingsStore.l10n.menuBarManager)"
    }

    /// Removes the status item, event monitor, and all notification observers.
    /// Must run on the main actor; safe to call multiple times.
    func teardown() {
        aggregationAutoHideTimer?.invalidate()
        aggregationAutoHideTimer = nil
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

        aggregationPanel.hide()

        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }

        button.action = #selector(statusBarButtonClicked(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        refreshStatusBarButton()
    }

    /// Menu bar icon reflects the user-selected aggregation icon style.
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
        return NSImage(systemSymbolName: symbol, accessibilityDescription: "StatusBar")
    }

    private func setupPopover() {
        popover.contentSize = NSSize(width: 360, height: 480)
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

    private func setupNotifications() {
        let layoutObserver = NotificationCenter.default.addObserver(
            forName: .menuBarItemsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.aggregationPanel.isShown {
                    self.aggregationPanel.updatePosition()
                }
            }
        }
        observers.append(layoutObserver)

        let toggleObserver = NotificationCenter.default.addObserver(
            forName: .toggleAggregationPanel,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.toggleAggregationPanel()
            }
        }
        observers.append(toggleObserver)
    }

    /// Auto-hide the aggregation panel after the user-configured delay
    /// (Settings → Aggregation → Auto Hide). `nil` delay means "Never".
    /// Hovering the panel pauses the countdown; leaving resumes what is left
    /// of it, so reading the panel does not get it yanked away mid-read.
    private func scheduleAggregationAutoHide() {
        aggregationAutoHideTimer?.invalidate()
        aggregationAutoHideTimer = nil
        guard let delay = settingsStore.autoHideDelay, delay > 0 else { return }
        remainingAutoHideDelay = delay
        armAggregationAutoHideTimer(withTimeInterval: delay)
    }

    /// Pauses (invalidates) the auto-hide countdown while the pointer rests on
    /// the panel; `resumeAggregationAutoHide` restarts the remaining time.
    private func pauseAggregationAutoHide() {
        guard aggregationAutoHideTimer != nil else { return }
        remainingAutoHideDelay = max(remainingAutoHideDelay - Date().timeIntervalSince(autoHideStartDate), 0)
        aggregationAutoHideTimer?.invalidate()
        aggregationAutoHideTimer = nil
    }

    /// Resumes a paused countdown with at least one second left, so a hover
    /// right at the deadline does not hide the panel instantly on mouse-exit.
    private func resumeAggregationAutoHide() {
        guard aggregationAutoHideTimer == nil,
              remainingAutoHideDelay > 0,
              aggregationPanel.isShown,
              settingsStore.aggregationMode.usesAggregationAutoHide else { return }
        armAggregationAutoHideTimer(withTimeInterval: max(remainingAutoHideDelay, 1))
    }

    private func armAggregationAutoHideTimer(withTimeInterval interval: TimeInterval) {
        // Record arm time, not schedule time: pause() subtracts the elapsed
        // span since the last arm, so every resume resets this baseline.
        autoHideStartDate = Date()
        aggregationAutoHideTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) {
            [weak self] _ in
            Task { @MainActor in
                guard let self, self.aggregationPanel.isShown else { return }
                // Only auto-hide in automatic mode; a manual toggle stays until closed.
                guard self.settingsStore.aggregationMode.usesAggregationAutoHide else { return }
                self.aggregationPanel.hide()
                self.remainingAutoHideDelay = 0
            }
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

        let panelItem = NSMenuItem(
            title: aggregationPanel.isShown ? l10n.hideAggregationPanel : l10n.showAggregationPanel,
            action: #selector(toggleAggregationPanel),
            keyEquivalent: ""
        )
        panelItem.target = self
        menu.addItem(panelItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: l10n.settingsDots,
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: l10n.quitStatusBar,
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func toggleAggregationPanel() {
        if aggregationPanel.isShown {
            aggregationAutoHideTimer?.invalidate()
            aggregationAutoHideTimer = nil
            remainingAutoHideDelay = 0
            aggregationPanel.hide()
        } else {
            aggregationPanel.show()
            // The panel no longer auto-opens on new apps (manual-only), so a
            // manual summon must also arm the auto-hide countdown itself;
            // otherwise it would linger until the user dismisses it.
            scheduleAggregationAutoHide()
        }
    }

    @objc private func openSettings() {
        AppSettingsOpener.open()
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
