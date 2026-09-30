import XCTest

@testable import StatusBar

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

    // MARK: - AggregationPanel.heightFor

    func testHeightForEmptyListUsesFixedMinimum() {
        XCTAssertEqual(
            AggregationPanel.heightFor(statusbarCount: 0, spacing: 8),
            AggregationPanel.Layout.verticalPadding
                + AggregationPanel.Layout.headerHeight
                + AggregationPanel.Layout.emptyStateHeight
        )
    }

    func testHeightForGrowsPerRowThenCaps() {
        let layout = AggregationPanel.Layout.self
        XCTAssertEqual(
            AggregationPanel.heightFor(statusbarCount: 1, spacing: 8),
            layout.verticalPadding + layout.headerHeight + layout.rowHeight
        )
        // 10 apps / 5 columns = 2 rows: exactly one inter-row spacing gap.
        XCTAssertEqual(
            AggregationPanel.heightFor(statusbarCount: 10, spacing: 4),
            layout.verticalPadding + layout.headerHeight + 2 * layout.rowHeight + 4
        )
        // 15 apps = 3 rows, but the panel caps at maxVisibleRows.
        XCTAssertEqual(
            AggregationPanel.heightFor(statusbarCount: 15, spacing: 4),
            layout.verticalPadding + layout.headerHeight
                + CGFloat(layout.maxVisibleRows) * layout.rowHeight + 4
        )
    }

    // MARK: - MenuBarMonitor.sortedByCustomOrder

    private func item(_ id: String, _ name: String) -> MenuBarMonitor.MenuBarItem {
        MenuBarMonitor.MenuBarItem(
            id: id,
            bundleIdentifier: id,
            processName: name,
            icon: nil,
            appType: .dockOnly
        )
    }

    func testSortedByCustomOrderPutsOrderedFirstThenUnorderedAlphabetically() {
        let store = SettingsStore()
        store.customOrder = ["b"]
        let monitor = MenuBarMonitor(settingsStore: store)

        let sorted = monitor.sortedByCustomOrder([
            item("c", "Cherry"),
            item("b", "Banana"),
            item("a", "Apple"),
        ])

        XCTAssertEqual(sorted.map(\.id), ["b", "a", "c"])
    }

    func testSortedByCustomOrderWithoutOrderKeepsInputOrder() {
        // With no custom order the input is passed through; the alphabetical
        // baseline comes from getMenuItemsFromRunningApps.
        let store = SettingsStore()
        store.customOrder = []
        let monitor = MenuBarMonitor(settingsStore: store)

        let sorted = monitor.sortedByCustomOrder([
            item("c", "Cherry"),
            item("a", "Apple"),
        ])

        XCTAssertEqual(sorted.map(\.id), ["c", "a"])
    }

    func testSortedByCustomOrderIgnoresUnknownOrderedIDs() {
        // IDs of apps that have quit must not break the ordering.
        let store = SettingsStore()
        store.customOrder = ["ghost", "a"]
        let monitor = MenuBarMonitor(settingsStore: store)

        let sorted = monitor.sortedByCustomOrder([
            item("b", "Banana"),
            item("a", "Apple"),
        ])

        XCTAssertEqual(sorted.map(\.id), ["a", "b"])
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

    // MARK: - Custom order ownership

    func testCustomOrderOnlyContainsExplicitlyOrderedItems() {
        let store = SettingsStore()
        store.customOrder = ["b"]
        let monitor = MenuBarMonitor(settingsStore: store)

        let sorted = monitor.sortedByCustomOrder([
            item("b", "Banana"),
            item("a", "Apple"),
            item("c", "Cherry"),
        ])

        XCTAssertEqual(sorted.map(\.id), ["b", "a", "c"])
        XCTAssertEqual(store.customOrder, ["b"])
        XCTAssertEqual(
            sorted.filter { !store.customOrder.contains($0.id) }.map(\.id),
            ["a", "c"]
        )
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
