import XCTest

@testable import topiary_bar

@MainActor
final class LogicTests: XCTestCase {
    // MARK: - MenuBarMonitor.baseBundleID

    func testBaseBundleIDKeepsFirstTwoSegments() {
        XCTAssertEqual(MenuBarMonitor.baseBundleID(of: "com.docker.helper"), "com.docker")
        XCTAssertEqual(MenuBarMonitor.baseBundleID(of: "com.docker"), "com.docker")
        XCTAssertEqual(MenuBarMonitor.baseBundleID(of: "com.apple.finder"), "com.apple")
    }

    func testBaseBundleIDSegmentAlignmentPreventsPrefixAbsorption() {
        // The comparison must be segment-aligned, not a prefix match: otherwise
        // com.docker would also dominate com.dockerized.app.
        XCTAssertNotEqual(
            MenuBarMonitor.baseBundleID(of: "com.docker.helper"),
            MenuBarMonitor.baseBundleID(of: "com.dockerized.app")
        )
    }

    func testBaseBundleIDSingleSegmentIsNil() {
        XCTAssertNil(MenuBarMonitor.baseBundleID(of: "localhost"))
        XCTAssertNil(MenuBarMonitor.baseBundleID(of: ""))
    }

    // MARK: - Pin management

    func testTogglePinAddsOnesInOrderAndRemoves() {
        let store = SettingsStore()
        store.pinnedAppIDs = []

        store.togglePin("com.b")
        store.togglePin("com.a")
        XCTAssertEqual(store.pinnedAppIDs, ["com.b", "com.a"])
        XCTAssertTrue(store.isPinned("com.a"))

        store.togglePin("com.a")
        XCTAssertFalse(store.isPinned("com.a"))
        XCTAssertEqual(store.pinnedAppIDs, ["com.b"])
    }

    func testPrunePinsDropsQuitApps() {
        let store = SettingsStore()
        store.pinnedAppIDs = ["com.running", "com.quit"]
        store.prunePins(keeping: ["com.running"])
        // Run again (no-op) to assert idempotence.
        store.prunePins(keeping: ["com.running"])
        XCTAssertEqual(store.pinnedAppIDs, ["com.running"])
    }

    func testPrunePinsKeepsEverythingUnalteredWhenNothingPruned() {
        let store = SettingsStore()
        store.pinnedAppIDs = ["com.running"]
        store.prunePins(keeping: ["com.running"])
        XCTAssertEqual(store.pinnedAppIDs, ["com.running"])
    }

    // MARK: - MenuBarItem equality

    func testMenuBarItemEqualityDetectsPresentationChanges() {
        let icon = NSImage(size: NSSize(width: 16, height: 16))
        let original = MenuBarMonitor.MenuBarItem(
            id: "com.example.app",
            bundleIdentifier: "com.example.app",
            processName: "Example",
            icon: icon,
            appType: .statusbarOnly
        )
        let renamed = MenuBarMonitor.MenuBarItem(
            id: "com.example.app",
            bundleIdentifier: "com.example.app",
            processName: "Renamed Example",
            icon: icon,
            appType: .statusbarOnly
        )
        let reclassified = MenuBarMonitor.MenuBarItem(
            id: "com.example.app",
            bundleIdentifier: "com.example.app",
            processName: "Example",
            icon: icon,
            appType: .dockOnly
        )

        XCTAssertNotEqual(original, renamed)
        XCTAssertNotEqual(original, reclassified)
    }
}
