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

    func applicationDidFinishLaunching(_ notification: Notification) {
        settingsStore.applyAppearance()

        statusBarController = StatusBarManager(
            menuBarMonitor: menuBarMonitor,
            settingsStore: settingsStore,
            accessibilityManager: accessibilityManager
        )

        menuBarMonitor.startMonitoring()
    }

    /// Permissions can change while the app is in the background (System
    /// Settings), so the read-only AX flag is re-read on every activation
    /// instead of being polled on a timer.
    func applicationDidBecomeActive(_ notification: Notification) {
        accessibilityManager.refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
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
