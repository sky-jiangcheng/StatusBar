import AppKit
import Observation

/// Renders each app the user pinned directly inside the macOS menu bar as a
/// resident, always-visible status item — a "menu-bar Dock". No popover or
/// floating panel is required to reach them.
///
/// One `NSStatusItem` per pinned app. Left-click activates that app; right-click
/// shows a small menu (open / remove from panel / quit). The set stays in sync
/// with `SettingsStore.pinnedAppIDs` and with live app churn (an app that quits
/// disappears from the bar until it / its pin returns).
@MainActor
final class ResidentBarManager {
    private let fixedLength: CGFloat = 28

    private let menuBarMonitor: MenuBarMonitor
    private let settingsStore: SettingsStore

    /// Bundle ID -> live status item currently shown in the menu bar.
    private var statusItems: [String: NSStatusItem] = [:]
    private var observers: [NSObjectProtocol] = []

    init(menuBarMonitor: MenuBarMonitor, settingsStore: SettingsStore) {
        self.menuBarMonitor = menuBarMonitor
        self.settingsStore = settingsStore
        registerObservers()
        syncStatusItems()
    }

    /// Removes every observer and every status item from the system menu bar.
    /// Must run on the main actor; safe to call multiple times.
    func teardown() {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
        removeAllStatusItems()
    }

    private func registerObservers() {
        let appChange = NotificationCenter.default.addObserver(
            forName: .menuBarItemsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.syncStatusItems()
            }
        }
        observers.append(appChange)

        // Re-register on every pin-list change (add/remove/order) so the bar
        // mirrors the persisted pinned set without an explicit refresh call.
        trackPinnedChanges()
    }

    private func trackPinnedChanges() {
        withObservationTracking {
            _ = settingsStore.pinnedAppIDs
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.syncStatusItems()
                self.trackPinnedChanges()
            }
        }
    }

    private func removeAllStatusItems() {
        for item in statusItems.values {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItems.removeAll()
    }

    /// Reconciles the menu bar against `pinnedAppIDs` intersected with the live
    /// app list: drop items that are unpinned or no longer running, add freshly
    /// pinned ones, and refresh icons/tooltips of the rest.
    private func syncStatusItems() {
        let pinned = Set(settingsStore.pinnedAppIDs)
        let byID = Dictionary(
            menuBarMonitor.menuBarItems.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        // Collect then remove: mutating the dictionary while iterating it in a
        // for-in would trap ("collection was mutated while being enumerated").
        var toRemove: [String] = []
        for (id, item) in statusItems {
            if pinned.contains(id), let menuItem = byID[id] {
                refresh(menuItem, on: item)
            } else {
                toRemove.append(id)
            }
        }
        for id in toRemove {
            if let item = statusItems.removeValue(forKey: id) {
                NSStatusBar.system.removeStatusItem(item)
            }
        }

        for id in settingsStore.pinnedAppIDs {
            guard statusItems[id] == nil,
                  let menuItem = byID[id] else { continue }
            if let item = makeStatusItem(for: menuItem) {
                statusItems[id] = item
            }
        }
    }

    private func refresh(_ menuItem: MenuBarMonitor.MenuBarItem, on item: NSStatusItem) {
        item.button?.image = menuBarImage(for: menuItem)
        item.button?.toolTip = menuItem.processName
    }

    private func makeStatusItem(for menuItem: MenuBarMonitor.MenuBarItem) -> NSStatusItem? {
        let item = NSStatusBar.system.statusItem(withLength: fixedLength)
        guard let button = item.button else {
            NSStatusBar.system.removeStatusItem(item)
            return nil
        }

        item.button?.image = menuBarImage(for: menuItem)
        button.toolTip = menuItem.processName
        button.action = #selector(buttonClicked(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        return item
    }

    /// Downscales an app icon to a comfortably legible menu-bar size so several
    /// of them fit side by side.
    private func menuBarImage(for menuItem: MenuBarMonitor.MenuBarItem) -> NSImage? {
        guard let source = menuItem.icon else { return nil }
        let targetSize = NSSize(width: 18, height: 18)
        if source.size == .zero { return source }

        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: source.size),
            operation: .copy,
            fraction: 1.0
        )
        resized.unlockFocus()
        return resized
    }

    @objc private func buttonClicked(_ sender: AnyObject?) {
        guard let button = sender as? NSStatusBarButton,
              let entry = statusItems.first(where: { $0.value.button === button }),
              let menuItem = menuItem(forBundleID: entry.key) else { return }

        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu(for: menuItem, on: entry.value)
        } else {
            menuBarMonitor.activateApp(menuItem)
        }
    }

    private func menuItem(forBundleID id: String) -> MenuBarMonitor.MenuBarItem? {
        menuBarMonitor.menuBarItems.first { $0.id == id }
    }

    private func showContextMenu(for menuItem: MenuBarMonitor.MenuBarItem, on item: NSStatusItem) {
        let l10n = settingsStore.l10n
        let menu = NSMenu()

        let openItem = NSMenuItem(
            title: l10n.open,
            action: #selector(openApp(_:)),
            keyEquivalent: ""
        )
        openItem.target = self
        openItem.representedObject = menuItem
        menu.addItem(openItem)

        let removeItem = NSMenuItem(
            title: l10n.removeFromPanel,
            action: #selector(removeFromPanel(_:)),
            keyEquivalent: ""
        )
        removeItem.target = self
        removeItem.representedObject = menuItem
        menu.addItem(removeItem)

#if !MAC_APP_STORE
        menu.addItem(.separator())
        let quitItem = NSMenuItem(
            title: l10n.quit,
            action: #selector(quitApp(_:)),
            keyEquivalent: ""
        )
        quitItem.target = self
        quitItem.representedObject = menuItem
        menu.addItem(quitItem)
#endif

        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    @objc private func openApp(_ sender: AnyObject?) {
        guard let menuItem = (sender as? NSMenuItem)?.representedObject as? MenuBarMonitor.MenuBarItem else { return }
        menuBarMonitor.activateApp(menuItem)
    }

    @objc private func removeFromPanel(_ sender: AnyObject?) {
        guard let menuItem = (sender as? NSMenuItem)?.representedObject as? MenuBarMonitor.MenuBarItem else { return }
        settingsStore.togglePin(menuItem.id)
    }

#if !MAC_APP_STORE
    @objc private func quitApp(_ sender: AnyObject?) {
        guard let menuItem = (sender as? NSMenuItem)?.representedObject as? MenuBarMonitor.MenuBarItem else { return }
        menuBarMonitor.quitApp(menuItem)
    }
#endif
}