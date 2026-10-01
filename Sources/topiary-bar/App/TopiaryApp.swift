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

    init() {}
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

        statusBarController = StatusBarManager(
            menuBarMonitor: menuBarMonitor,
            settingsStore: settingsStore,
            visibilityMonitor: visibilityMonitor,
            systemMemoryMonitor: systemMemoryMonitor
        )

        menuBarMonitor.startMonitoring()

        systemMemoryMonitor.start()
        GlobalHotKey.apply(settingsStore.mainWindowHotKey)

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

        // When the main menu bar icon is swallowed by the notch, the app would
        // be unreachable — surface the manager window right away.
        visibilityMonitor.start { [weak self] in
            self?.summonMainWindow()
        }
    }

    /// Background agent (LSUIElement): closing the last window must never quit
    /// the app, or the resident status-bar icons would vanish with it.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
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
        // Only *titled* windows count as reachable UI. The transient popover
        // (~360pt) and the status-item windows are borderless and would
        // otherwise pass a width heuristic, making the gear button a no-op.
        if NSApp.windows.contains(where: { $0.isVisible && $0.styleMask.contains(.titled) }) {
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
