import AppKit
import Carbon.HIToolbox
import XCTest

@testable import topiary_bar

/// Uses a private `UserDefaults` suite per test: `SettingsStore.save()` writes
/// on every mutation, so sharing the standard domain would rewrite the
/// developer's real preferences on each test run.
@MainActor
final class LogicTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "topiary-bar-tests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        try await super.tearDown()
    }

    private func makeStore() -> SettingsStore {
        SettingsStore(defaults: defaults)
    }

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
        let store = makeStore()
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
        let store = makeStore()
        store.pinnedAppIDs = ["com.running", "com.quit"]
        store.prunePins(keeping: ["com.running"])
        // Run again (no-op) to assert idempotence.
        store.prunePins(keeping: ["com.running"])
        XCTAssertEqual(store.pinnedAppIDs, ["com.running"])
    }

    func testPrunePinsKeepsEverythingUnalteredWhenNothingPruned() {
        let store = makeStore()
        store.pinnedAppIDs = ["com.running"]
        store.prunePins(keeping: ["com.running"])
        XCTAssertEqual(store.pinnedAppIDs, ["com.running"])
    }

    // MARK: - Persistence

    func testSaveThenLoadRoundTripsEveryPreference() {
        let store = makeStore()
        store.aggregationIcon = .chevron
        store.refreshInterval = 5
        store.pinnedAppIDs = ["com.a", "com.b"]
        store.appearance = .dark
        store.language = .ja
        store.showDockIcon = false
        store.launchAtLogin = true
        store.mainWindowHotKey = HotKeyValue(
            keyCode: 8,
            modifiers: UInt32(controlKey | shiftKey),
            display: "⌃⇧C"
        )
        store.save()

        // A fresh store over the same domain must see every written key —
        // guards the icon / hotkey bindings that had no save() call site.
        let reloaded = makeStore()
        XCTAssertEqual(reloaded.aggregationIcon, .chevron)
        XCTAssertEqual(reloaded.refreshInterval, 5)
        XCTAssertEqual(reloaded.pinnedAppIDs, ["com.a", "com.b"])
        XCTAssertEqual(reloaded.appearance, .dark)
        XCTAssertEqual(reloaded.language, .ja)
        XCTAssertFalse(reloaded.showDockIcon)
        XCTAssertTrue(reloaded.launchAtLogin)
        XCTAssertEqual(reloaded.mainWindowHotKey?.display, "⌃⇧C")
    }

    func testDisabledHotKeyPersistsAsNil() {
        let store = makeStore()
        store.mainWindowHotKey = .mainWindow
        store.save()
        store.mainWindowHotKey = nil
        store.save()

        XCTAssertNil(makeStore().mainWindowHotKey)
    }

    func testDefaultsIgnoreGarbageValues() {
        defaults.set("nonsense", forKey: "aggregationIcon")
        defaults.set(-5.0, forKey: "refreshInterval")
        defaults.set(42, forKey: "showDockIcon")
        defaults.set(Data([0x00, 0x01]), forKey: "mainWindowHotKey")

        let store = makeStore()
        XCTAssertEqual(store.aggregationIcon, .dots)
        XCTAssertEqual(store.refreshInterval, 2.0)
        // An undecodable hotkey must not clobber the default binding.
        XCTAssertEqual(store.mainWindowHotKey, .mainWindow)
        // Absent-or-nonsense Dock flag: object(forKey:) exists but is not a
        // bool-able value, so the documented default wins.
        XCTAssertTrue(store.showDockIcon)
    }

    // MARK: - MenuBarItem identity vs. content

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

    func testIdentityIgnoresLiveValuesButContentDoesNot() {
        let icon = NSImage(size: NSSize(width: 16, height: 16))
        let before = MenuBarMonitor.MenuBarItem(
            id: "com.example.app",
            bundleIdentifier: "com.example.app",
            processName: "Example",
            icon: icon,
            appType: .statusbarOnly,
            pid: 100,
            memoryFootprint: 1_000
        )
        let after = MenuBarMonitor.MenuBarItem(
            id: "com.example.app",
            bundleIdentifier: "com.example.app",
            processName: "Example",
            icon: icon,
            appType: .statusbarOnly,
            pid: 200,
            memoryFootprint: 2_000
        )

        // Identity stays put so SwiftUI does not re-create the row...
        XCTAssertEqual(before, after)
        XCTAssertEqual(before.hashValue, after.hashValue)
        // ...but a scan must still detect that the rendered values moved,
        // otherwise memory / PID freeze at their first snapshot.
        XCTAssertFalse(before.hasSameContent(as: after))
    }

    func testContentEqualityHoldsForUnchangedLiveValues() {
        let icon = NSImage(size: NSSize(width: 16, height: 16))
        let a = MenuBarMonitor.MenuBarItem(
            id: "com.example.app",
            bundleIdentifier: "com.example.app",
            processName: "Example",
            icon: icon,
            appType: .statusbarOnly,
            pid: 7,
            memoryFootprint: nil
        )
        let b = MenuBarMonitor.MenuBarItem(
            id: "com.example.app",
            bundleIdentifier: "com.example.app",
            processName: "Example",
            icon: icon,
            appType: .statusbarOnly,
            pid: 7,
            memoryFootprint: nil
        )
        XCTAssertTrue(a.hasSameContent(as: b))
    }

    // MARK: - HotKeyValue

    func testHotKeyValueRoundTripsThroughCodable() throws {
        let value = HotKeyValue(
            keyCode: UInt32(kVK_ANSI_M),
            modifiers: UInt32(controlKey | optionKey),
            display: "⌃⌥M"
        )
        let data = try JSONEncoder().encode(value)
        XCTAssertEqual(try JSONDecoder().decode(HotKeyValue.self, from: data), value)
    }

    func testCarbonModifiersMapsEveryFlag() {
        let carbon = HotKeyValue.carbonModifiers(from: [.command, .control, .option, .shift])
        XCTAssertEqual(carbon, UInt32(cmdKey | controlKey | optionKey | shiftKey))
        XCTAssertEqual(HotKeyValue.carbonModifiers(from: []), 0)
    }

    func testDisplayGlyphsUseCanonicalOrder() {
        // Canonical macOS order: ⌃ ⌥ ⇧ ⌘ regardless of flag input order.
        XCTAssertEqual(
            HotKeyValue.displayGlyphs(UInt32(shiftKey | cmdKey | optionKey | controlKey)),
            "⌃⌥⇧⌘"
        )
        XCTAssertEqual(HotKeyValue.displayGlyphs(0), "")
    }

    func testMenuKeyEquivalentUsesLastDisplayCharacter() {
        let value = HotKeyValue(keyCode: 46, modifiers: UInt32(controlKey), display: "⌃M")
        XCTAssertEqual(value.menuKeyEquivalent, "m")
        XCTAssertEqual(value.menuModifierMask, [.control])
    }

    // MARK: - Format.memory

    func testMemoryFormattingPicksUnitByMagnitude() {
        // 46.0 MB → one decimal, 245 MB → none, 3.03 GB → two decimals.
        XCTAssertEqual(Format.memory(48_200_000), "46.0 MB")
        XCTAssertEqual(Format.memory(257_000_000), "245 MB")
        XCTAssertEqual(Format.memory(3_250_000_000), "3.03 GB")
    }

    func testMemoryFormattingHandlesZeroAndSubMegabyte() {
        XCTAssertEqual(Format.memory(0), "0.0 MB")
        XCTAssertEqual(Format.memory(999), "0.0 MB")
    }

    // MARK: - StatusBarVisibility.isKnownHider

    func testKnownHiderDetectionCoversBundlesAndNames() {
        let hidden = MenuBarMonitor.MenuBarItem(
            id: "com.dwarvesf.hidden",
            bundleIdentifier: "com.dwarvesf.hidden",
            processName: "Hidden Bar",
            icon: nil,
            appType: .statusbarOnly
        )
        let ice = MenuBarMonitor.MenuBarItem(
            id: "jordanbaird.Ice",
            bundleIdentifier: "jordanbaird.Ice",
            processName: "Ice",
            icon: nil,
            appType: .statusbarOnly
        )
        let other = MenuBarMonitor.MenuBarItem(
            id: "com.example.app",
            bundleIdentifier: "com.example.app",
            processName: "Example",
            icon: nil,
            appType: .statusbarOnly
        )

        XCTAssertTrue(StatusBarVisibility.isKnownHider(hidden))
        XCTAssertTrue(StatusBarVisibility.isKnownHider(ice))
        XCTAssertFalse(StatusBarVisibility.isKnownHider(other))
    }

    // MARK: - Localization

    func testSystemLanguageResolvesToAConcreteLanguage() {
        // Locale-dependent, so only the contract is asserted: the result is
        // never .system, which would make `L10n.table(for:)` recurse.
        XCTAssertNotEqual(AppLanguage.resolveSystem(), .system)
    }
}
