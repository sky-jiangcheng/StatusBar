import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class SettingsStore {
    var aggregationIcon: AggregationIconType = .dots
    var refreshInterval: TimeInterval = 2.0
    /// Bundle IDs the user chose to keep visibly resident in the menu bar,
    /// in the order they were pinned. Each pinned app gets its own always-
    /// visible status item.
    var pinnedAppIDs: [String] = []
    var appearance: AppearanceMode = .system
    var language: AppLanguage = .system
    /// Global hotkey that summons the main window; nil disables the hotkey.
    var mainWindowHotKey: HotKeyValue? = .mainWindow
    /// Whether the Topiary icon appears in the Dock while the main window is
    /// open (brand visibility + discoverability). The icon follows the main
    /// window: hidden again when the window closes — the app stays alive in
    /// the menu bar either way. Off = never show a Dock icon.
    var showDockIcon: Bool = true

    enum AggregationIconType: String, CaseIterable, Identifiable {
        case dots = "Three Dots"
        case grid = "Grid"
        case chevron = "Chevron"
        case square = "Square"
        case circle = "Circle"
        case transparent = "Transparent"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .dots: return "ellipsis"
            case .grid: return "square.grid.2x2"
            case .chevron: return "chevron.down"
            case .square: return "square"
            case .circle: return "circle"
            case .transparent: return "circle.dotted"
            }
        }
    }

    private let defaults = UserDefaults.standard

    /// Current translation table; views reading this re-render on language change.
    var l10n: L10nTable { L10n.table(for: language) }

    init() {
        load()
    }

    /// Applies the user's appearance preference globally. Call after launch and on change.
    func applyAppearance() {
        switch appearance {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    func load() {
        aggregationIcon = AggregationIconType(rawValue: defaults.string(forKey: "aggregationIcon") ?? "") ?? .dots
        pinnedAppIDs = defaults.stringArray(forKey: "pinnedAppIDs") ?? []

        let storedRefresh = defaults.double(forKey: "refreshInterval")
        refreshInterval = storedRefresh > 0 ? storedRefresh : 2.0

        appearance = AppearanceMode(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .system
        language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .system
        // Absent key → default (true): the Info.plist still launches the app
        // as LSUIElement, so first launch starts without a Dock flash either way.
        if defaults.object(forKey: "showDockIcon") != nil {
            showDockIcon = defaults.bool(forKey: "showDockIcon")
        }
        if let data = defaults.data(forKey: "mainWindowHotKey"),
           let value = try? JSONDecoder().decode(HotKeyValue.self, from: data) {
            mainWindowHotKey = value
        }
    }

    /// Applies the Dock-icon preference at runtime via activation policy.
    /// The Info.plist keeps LSUIElement=1 so launch never flashes a Dock icon;
    /// the policy is switched right after launch and on every change.
    func applyDockPolicy() {
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
    }

    func save() {
        defaults.set(aggregationIcon.rawValue, forKey: "aggregationIcon")
        defaults.set(refreshInterval, forKey: "refreshInterval")
        defaults.set(pinnedAppIDs, forKey: "pinnedAppIDs")
        defaults.set(appearance.rawValue, forKey: "appearance")
        defaults.set(language.rawValue, forKey: "language")
        defaults.set(showDockIcon, forKey: "showDockIcon")
        defaults.set(try? JSONEncoder().encode(mainWindowHotKey), forKey: "mainWindowHotKey")
    }

    /// Whether `bundleID` is currently pinned into the resident panel.
    func isPinned(_ bundleID: String) -> Bool {
        pinnedAppIDs.contains(bundleID)
    }

    /// Pins or unpins `bundleID`; newly pinned IDs go to the end of the list.
    func togglePin(_ bundleID: String) {
        if let index = pinnedAppIDs.firstIndex(of: bundleID) {
            pinnedAppIDs.remove(at: index)
        } else {
            pinnedAppIDs.append(bundleID)
        }
        save()
    }

    /// Drops the persisted pin of IDs that have quit or are no longer installed.
    func prunePins(keeping detected: [String]) {
        let keep = Set(detected)
        let pruned = pinnedAppIDs.filter { keep.contains($0) }
        guard pruned.count != pinnedAppIDs.count else { return }
        pinnedAppIDs = pruned
        save()
    }
}
