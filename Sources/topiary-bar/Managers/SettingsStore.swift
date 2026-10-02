import AppKit
import Foundation
import Observation
import ServiceManagement

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
    /// Launch at login. Claiming a menu bar spot early at every login is the
    /// only way to keep the icon near the right edge — later apps stack to
    /// the left, toward the notch.
    var launchAtLogin: Bool = false

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

    /// Backing store. Defaults to the standard domain in the app; unit tests
    /// inject a private suite so running them never rewrites the user's
    /// real preferences.
    private let defaults: UserDefaults

    /// Current translation table; views reading this re-render on language change.
    var l10n: L10nTable { L10n.table(for: language) }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
        launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        if let data = defaults.data(forKey: "mainWindowHotKey"),
           let boxed = try? JSONDecoder().decode(Boxed.self, from: data) {
            mainWindowHotKey = boxed.hotKey
        }
    }

    /// Syncs the login-item with the user's preference (best-effort: failures
    /// fall back to System Settings → Login Items).
    func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Unbundled dev runs and approval-pending states land here; the
            // user can always toggle it in System Settings.
        }
    }

    func save() {
        defaults.set(aggregationIcon.rawValue, forKey: "aggregationIcon")
        defaults.set(refreshInterval, forKey: "refreshInterval")
        defaults.set(pinnedAppIDs, forKey: "pinnedAppIDs")
        defaults.set(appearance.rawValue, forKey: "appearance")
        defaults.set(language.rawValue, forKey: "language")
        defaults.set(showDockIcon, forKey: "showDockIcon")
        defaults.set(launchAtLogin, forKey: "launchAtLogin")
        // A nil hotkey (user cleared it) must stay distinguishable from an
        // absent key (never configured): `set(nil, forKey:)` *removes* the
        // key, which made the default shortcut resurrect on every launch.
        // Boxing the optional makes "disabled" an explicit stored value.
        defaults.set(try? JSONEncoder().encode(Boxed(hotKey: mainWindowHotKey)), forKey: "mainWindowHotKey")
    }

    /// `UserDefaults` cannot store a top-level `nil`, so the hotkey is boxed.
    private struct Boxed: Codable {
        let hotKey: HotKeyValue?
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
