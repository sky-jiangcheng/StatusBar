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

    // MARK: - Aggregation auto-show policy

    /// The priming scan inventories what is already running and must never
    /// be mistaken for "a Status Bar app just appeared": emitting the signal there
    /// popped the panel over the user on every single launch.
    func testStartMonitoringDoesNotEmitAggregationShow() {
        let monitor = MenuBarMonitor(settingsStore: SettingsStore())
        let show = expectation(forNotification: .aggregationShouldShow, object: nil)
        show.isInverted = true

        monitor.startMonitoring()
        wait(for: [show], timeout: 0.5)
        monitor.stopMonitoring()
    }

    // MARK: - AggregationShowGate

    func testGateBaselineNeverFiresButPersistentNewAppsDo() {
        var gate = MenuBarMonitor.AggregationShowGate()

        // Priming scan inventories the running app; it never fires, no
        // matter how many scans it survives.
        XCTAssertTrue(gate.evaluate(newIDs: ["com.running.app"]).isEmpty)
        XCTAssertTrue(gate.evaluate(newIDs: ["com.running.app"]).isEmpty)

        // A genuinely new app fires on its SECOND consecutive scan...
        _ = gate.evaluate(newIDs: ["com.running.app", "com.downloaded.app"])
        XCTAssertEqual(
            gate.evaluate(newIDs: ["com.running.app", "com.downloaded.app"]),
            ["com.downloaded.app"]
        )
        // ...then stays silent, and the baseline app never fires at all.
        XCTAssertTrue(gate.evaluate(newIDs: ["com.running.app", "com.downloaded.app"]).isEmpty)
    }

    func testGateRequiresTwoConsecutiveScansBeforeFiring() {
        var gate = MenuBarMonitor.AggregationShowGate()
        gate.establishBaseline([])

        // First sighting: too young to tell a real icon from launch churn.
        XCTAssertTrue(gate.evaluate(newIDs: ["com.new.app"]).isEmpty)
        // Second consecutive scan: the app is real — fire.
        XCTAssertEqual(gate.evaluate(newIDs: ["com.new.app"]), ["com.new.app"])
        // Already fired: silent for the rest of the session.
        XCTAssertTrue(gate.evaluate(newIDs: ["com.new.app"]).isEmpty)
    }

    func testGateIgnoresHelperSeenForASingleScan() {
        var gate = MenuBarMonitor.AggregationShowGate()
        gate.establishBaseline(["com.parent.app"])

        // Quit residue: the helper surfaces for one scan, then disappears.
        _ = gate.evaluate(newIDs: ["com.parent.helper"])
        XCTAssertTrue(gate.evaluate(newIDs: ["com.parent.app"]).isEmpty)

        // A helper that returns must again persist two consecutive scans.
        _ = gate.evaluate(newIDs: ["com.parent.helper"])
        XCTAssertEqual(gate.evaluate(newIDs: ["com.parent.helper"]), ["com.parent.helper"])
    }

    /// Regression: clicking 打开 on an app in the main window popped the
    /// aggregation panel seconds later (the app and its helpers looked like
    /// "new icons"), and again after the app was quit.
    func testGateSuppressesAppsTheUserOpenedFromOurUI() {
        var gate = MenuBarMonitor.AggregationShowGate()
        gate.establishBaseline([])
        gate.noteUserAction(bundleID: "com.vendor.app")

        // The app itself, then its persistent helper: both would otherwise
        // fire on their second consecutive scan.
        _ = gate.evaluate(newIDs: ["com.vendor.app"])
        XCTAssertTrue(gate.evaluate(newIDs: ["com.vendor.app"]).isEmpty)
        _ = gate.evaluate(newIDs: ["com.vendor.app.launcher"])
        XCTAssertTrue(gate.evaluate(newIDs: ["com.vendor.app.launcher"]).isEmpty)
    }

    func testGateSuppressesHelperOutlivingAUserQuit() {
        var gate = MenuBarMonitor.AggregationShowGate()
        gate.establishBaseline(["com.vendor.app", "com.vendor.app.helper"])
        // The user quits the app from our UI; its accessory helper may
        // linger for seconds after the parent is gone.
        gate.noteUserAction(bundleID: "com.vendor.app")

        _ = gate.evaluate(newIDs: ["com.vendor.app.helper"])
        XCTAssertTrue(gate.evaluate(newIDs: ["com.vendor.app.helper"]).isEmpty)
    }

    func testGateStillFiresForUnrelatedNewApps() {
        var gate = MenuBarMonitor.AggregationShowGate()
        gate.establishBaseline(["com.vendor.app"])
        gate.noteUserAction(bundleID: "com.vendor.app")

        // Suppression is family-scoped: an unrelated app still notifies.
        _ = gate.evaluate(newIDs: ["com.vendor.app", "com.unrelated.app"])
        XCTAssertEqual(
            gate.evaluate(newIDs: ["com.vendor.app", "com.unrelated.app"]),
            ["com.unrelated.app"]
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

    // MARK: - Mode policy

    func testAggregationModeAutomaticShowPolicy() {
        XCTAssertTrue(SettingsStore.AggregationMode.aggregation.showsAggregationPanelAutomatically)
        XCTAssertFalse(SettingsStore.AggregationMode.normal.showsAggregationPanelAutomatically)
        XCTAssertFalse(SettingsStore.AggregationMode.disabled.showsAggregationPanelAutomatically)
    }

    func testAggregationModeAutoHidePolicy() {
        XCTAssertTrue(SettingsStore.AggregationMode.aggregation.usesAggregationAutoHide)
        XCTAssertFalse(SettingsStore.AggregationMode.normal.usesAggregationAutoHide)
        XCTAssertFalse(SettingsStore.AggregationMode.disabled.usesAggregationAutoHide)
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
