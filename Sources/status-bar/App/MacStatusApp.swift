import AppKit
import SwiftUI

@main
struct StatusBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("StatusBar", id: "main") {
            ContentView()
                .environment(appDelegate.settingsStore)
                .environment(appDelegate.menuBarMonitor)
                .environment(appDelegate.accessibilityManager)
                .environment(appDelegate.visibilityMonitor)
        }
        .defaultSize(width: 700, height: 450)

        Settings {
            SettingsView()
                .environment(appDelegate.settingsStore)
                .environment(appDelegate.menuBarMonitor)
                .environment(appDelegate.accessibilityManager)
        }
        .defaultSize(width: 520, height: 480)
    }

    init() {}
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var statusBarController: StatusBarManager?

    let settingsStore = SettingsStore()
    let accessibilityManager = AccessibilityManager()

    private(set) lazy var menuBarMonitor = MenuBarMonitor(
        settingsStore: settingsStore
    )

    /// Tracks occlusion of our own menu bar icons (notch / overcrowded bar).
    /// Providers resolve lazily, so creating this before the status controllers
    /// exist is safe.
    private(set) lazy var visibilityMonitor = VisibilityMonitor(
        mainItemProvider: { [weak self] in self?.statusBarController?.visibilityMainItem },
        pinnedItemsProvider: { [weak self] in self?.statusBarController?.visibilityPinnedItems() ?? [] }
    )

    /// Fallback manager window for summoning when the SwiftUI `Window` scene
    /// has been closed and `openWindow` is unavailable (no view context).
    private var fallbackMainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        settingsStore.applyAppearance()

        statusBarController = StatusBarManager(
            menuBarMonitor: menuBarMonitor,
            settingsStore: settingsStore,
            accessibilityManager: accessibilityManager,
            visibilityMonitor: visibilityMonitor
        )

        menuBarMonitor.startMonitoring()

        // When the main menu bar icon is swallowed by the notch, the app would
        // be unreachable — surface the manager window right away.
        visibilityMonitor.start { [weak self] in
            self?.summonMainWindow()
        }
    }

    /// Permissions can change while the app is in the background (System
    /// Settings), so the read-only AX flag is re-read on every activation
    /// instead of being polled on a timer.
    func applicationDidBecomeActive(_ notification: Notification) {
        accessibilityManager.refresh()
    }

    /// Background agent (LSUIElement): closing the last window must never quit
    /// the app, or the resident status-bar icons would vanish with it.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Finder re-launch (or `open -na StatusBar`) while already running:
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
        // Status items and the aggregation panel also surface as small app
        // windows; only a content-sized window counts as reachable UI.
        if NSApp.windows.contains(where: { $0.isVisible && $0.frame.width >= 200 }) {
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
        window.title = "StatusBar"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: ContentView()
                .environment(settingsStore)
                .environment(menuBarMonitor)
                .environment(accessibilityManager)
                .environment(visibilityMonitor)
        )
        fallbackMainWindow = window
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        visibilityMonitor.stop()

        // Release menu bar resources in a deterministic order before teardown.
        menuBarMonitor.stopMonitoring()
        statusBarController?.teardown()
        statusBarController = nil

        // Drop custom-order entries of apps that are no longer running, so the
        // persisted order does not grow without bound across sessions.
        settingsStore.pruneOrder(keeping: menuBarMonitor.menuBarItems.map(\.id))
        settingsStore.prunePins(keeping: menuBarMonitor.menuBarItems.map(\.id))
    }
}
