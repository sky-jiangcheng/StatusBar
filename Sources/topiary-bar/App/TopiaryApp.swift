import AppKit
import SwiftUI

@main
struct TopiaryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Topiary", id: "main") {
            ContentView()
                .environment(appDelegate.settingsStore)
                .environment(appDelegate.menuBarMonitor)
                .environment(appDelegate.visibilityMonitor)
                .environment(appDelegate.systemMemoryMonitor)
        }
        .defaultSize(width: 760, height: 520)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var statusBarController: StatusBarManager?

    let settingsStore = SettingsStore()
    let systemMemoryMonitor = SystemMemoryMonitor()

    private(set) lazy var menuBarMonitor = MenuBarMonitor(
        settingsStore: settingsStore
    )

    /// Tracks occlusion of our own menu bar icons (notch / overcrowded bar).
    /// Providers resolve lazily, so creating this before the status controllers
    /// exist is safe.
    private(set) lazy var visibilityMonitor = VisibilityMonitor(
        mainItemProvider: { [weak self] in self?.statusBarController?.visibilityMainItem },
        pinnedItemsProvider: { [weak self] in self?.statusBarController?.visibilityPinnedItems() ?? [] },
        isHiderRunning: { [weak self] in
            // Hidden Bar & co. intentionally park icons behind the notch; while
            // one runs, occlusion is the user's own choice, not a problem.
            self?.menuBarMonitor.menuBarItems.contains { StatusBarVisibility.isKnownHider($0) } ?? false
        }
    )

    /// Fallback manager window for summoning when the SwiftUI `Window` scene
    /// has been closed and `openWindow` is unavailable (no view context).
    private var fallbackMainWindow: NSWindow?
    private var notificationObservers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        settingsStore.applyAppearance()
        settingsStore.applyLaunchAtLogin()
        updateDockPolicy()

        statusBarController = StatusBarManager(
            menuBarMonitor: menuBarMonitor,
            settingsStore: settingsStore,
            visibilityMonitor: visibilityMonitor,
            systemMemoryMonitor: systemMemoryMonitor
        )

        menuBarMonitor.startMonitoring()

        // systemMemoryMonitor is started/stopped by StatusBarManager's popover
        // delegate — the numbers are only rendered inside the popover.
        //
        // A conflict here (another app grabbed the shortcut while Topiary was
        // closed) leaves the hotkey unregistered; the user finds out on the
        // next keypress, and the settings pane re-registers when they pick a
        // new combination.
        _ = GlobalHotKey.apply(settingsStore.mainWindowHotKey)

        // Main window / settings entry points coming from the status item's
        // context menu and the popover: the AppDelegate owns the actual
        // summoning, then re-broadcasts the tab selection to the window.
        notificationObservers.append(NotificationCenter.default.addObserver(
            forName: .openMainWindow, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.summonMainWindow() }
        })
        notificationObservers.append(NotificationCenter.default.addObserver(
            forName: .openSettingsTab, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.summonMainWindow()
                NotificationCenter.default.post(name: .selectSettingsTab, object: nil)
            }
        })

        // The Dock icon follows the main window's visibility: re-evaluate on
        // every window close and whenever a window reports it is about to
        // appear. A delayed pass covers the SwiftUI scene window that appears
        // shortly after launch.
        notificationObservers.append(NotificationCenter.default.addObserver(
            forName: .mainWindowVisibilityChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateDockPolicy() }
        })
        notificationObservers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: nil, queue: .main
        ) { [weak self] note in
            // Extract a Sendable identity here; the NSWindow itself must not
            // cross into the Task (Swift 6 sending rules).
            let closingWindowID = (note.object as? NSWindow).map(ObjectIdentifier.init)
            Task { @MainActor [weak self] in
                guard let closingWindowID else { return }
                self?.updateDockPolicy(excluding: closingWindowID)
            }
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.updateDockPolicy()
        }

        // When the main menu bar icon is swallowed by the notch, the app would
        // be unreachable — surface the manager window right away.
        visibilityMonitor.start { [weak self] in
            self?.summonMainWindow()
        }
    }

    /// Dock icon follows the main window: visible while a content window is
    /// on screen (and the user hasn't disabled it), hidden when the window
    /// closes — the app stays alive in the menu bar either way.
    func updateDockPolicy(excluding closingWindowID: ObjectIdentifier? = nil) {
        let windowVisible = NSApp.windows.contains {
            $0.isVisible
                && $0.styleMask.contains(.titled)
                && ObjectIdentifier($0) != closingWindowID
        }
        NSApp.setActivationPolicy(
            settingsStore.showDockIcon && windowVisible ? .regular : .accessory
        )
    }

    /// Background agent (LSUIElement): closing the last window must never quit
    /// the app, or the resident status-bar icons would vanish with it.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Branded Dock menu: the Dock icon is a brand surface, so it carries the
    /// same entry points as the status item's context menu.
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let l10n = settingsStore.l10n
        let menu = NSMenu()

        let mainItem = NSMenuItem(title: l10n.openMainWindow, action: #selector(openMainWindowFromDock), keyEquivalent: "")
        mainItem.target = self
        menu.addItem(mainItem)

        let settingsItem = NSMenuItem(title: l10n.settingsDots, action: #selector(openSettingsFromDock), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: l10n.quitAppTitle, action: #selector(quitFromDock), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func openMainWindowFromDock() {
        NotificationCenter.default.post(name: .openMainWindow, object: nil)
    }

    @objc private func openSettingsFromDock() {
        NotificationCenter.default.post(name: .openSettingsTab, object: nil)
    }

    @objc private func quitFromDock() {
        NSApp.terminate(nil)
    }

    /// Finder re-launch (or `open -na Topiary`) while already running:
    /// surface the manager window. Critical when the menu bar icon is
    /// occluded by the notch and the popover is unreachable.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        summonMainWindow()
        return true
    }

    /// Brings the manager window to the front. SwiftUI's `openWindow` action
    /// only exists inside views and a closed `Window` scene cannot be
    /// re-opened from AppKit, so when no content window is visible we host
    /// ContentView in our own fallback NSWindow.
    func summonMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        // Bring the Dock icon back before the window appears (when enabled).
        if settingsStore.showDockIcon {
            NSApp.setActivationPolicy(.regular)
        }
        // Only *titled* windows count as reachable UI. The transient popover
        // (~360pt) and the status-item windows are borderless and would
        // otherwise pass a width heuristic, making the gear button a no-op.
        if NSApp.windows.contains(where: { $0.isVisible && $0.styleMask.contains(.titled) }) {
            updateDockPolicy()
            return
        }
        if let fallback = fallbackMainWindow {
            fallback.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Topiary"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: ContentView()
                .environment(settingsStore)
                .environment(menuBarMonitor)
                .environment(visibilityMonitor)
                .environment(systemMemoryMonitor)
        )
        fallbackMainWindow = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        updateDockPolicy()
    }

    func applicationWillTerminate(_ notification: Notification) {
        visibilityMonitor.stop()
        systemMemoryMonitor.stop()
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()

        // Release menu bar resources in a deterministic order before teardown.
        menuBarMonitor.stopMonitoring()
        statusBarController?.teardown()
        statusBarController = nil

        // Drop pins of apps that are no longer running, so the persisted set
        // does not grow without bound across sessions. Only menu-bar apps are
        // kept: Dock apps must never become resident icons.
        settingsStore.prunePins(
            keeping: menuBarMonitor.menuBarItems
                .filter { $0.appType == .statusbarOnly }
                .map(\.id)
        )
    }
}
