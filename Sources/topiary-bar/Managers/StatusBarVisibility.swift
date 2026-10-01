import AppKit
import Observation

// MARK: - Frame-level visibility

/// Geometric visibility check for the app's own status items.
///
/// On notch Macs, when the menu bar runs out of room, macOS silently stops
/// rendering the items that would collide with the notch — no notification,
/// no API flag. We detect it from window geometry: an item macOS refuses to
/// render collapses to (near) zero size, and an item pushed into the notch
/// sits inside the gap between the screen's two auxiliary menu bar areas.
enum StatusBarVisibility {
    /// Horizontal band covered by the notch on `screen`; nil when the screen
    /// has no notch (the two auxiliary areas are then contiguous).
    @MainActor
    static func notchBand(on screen: NSScreen) -> ClosedRange<CGFloat>? {
        guard let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea,
              right.minX > left.maxX else { return nil }
        return left.maxX...right.minX
    }

    /// False only when the item is provably occluded: a zero-sized window, a
    /// window pushed off-screen, or one overlapping the notch band. A missing
    /// window (menu bar auto-hidden, item not laid out yet) is treated as
    /// visible so the monitor never raises a false alarm.
    ///
    /// MainActor-isolated because NSStatusItem/NSWindow/NSScreen geometry
    /// properties are annotated @MainActor in recent SDKs; every caller
    /// (VisibilityMonitor) runs on the main actor anyway.
    @MainActor
    static func isVisible(_ item: NSStatusItem?, on screen: NSScreen?) -> Bool {
        guard let item, let window = item.button?.window else { return true }
        let frame = window.frame
        if frame.width < 2 || frame.height < 2 { return false }
        guard let screen = screen ?? window.screen ?? NSScreen.main else { return true }
        if frame.minX < screen.frame.minX { return false }
        guard let band = notchBand(on: screen) else { return true }
        // Status items are laid out right of the notch; anything overlapping
        // the band is clipped away by the system.
        return frame.maxX <= band.lowerBound || frame.minX >= band.upperBound
    }
}

// MARK: - Monitor

/// Tracks occlusion of the app's own menu bar items (the main status item and
/// the pinned resident items) and publishes the result to the UI.
///
/// Checks run on a short timer plus on app-list and screen changes; reading
/// window frames is cheap. When the main item transitions to hidden, the
/// monitor fires `onMainItemHidden` exactly once so the app can surface its
/// manager window — otherwise an occluded icon would leave the LSUIElement
/// background agent completely unreachable.
@Observable
@MainActor
final class VisibilityMonitor {
    private(set) var isMainItemHidden = false

    /// Pinned bundle IDs whose resident icons are currently occluded.
    private(set) var hiddenPinnedIDs: [String] = []

    var hasOcclusion: Bool { isMainItemHidden || !hiddenPinnedIDs.isEmpty }

    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private let mainItemProvider: () -> NSStatusItem?
    private let pinnedItemsProvider: () -> [(id: String, item: NSStatusItem)]
    private var onMainItemHidden: (() -> Void)?

    init(
        mainItemProvider: @escaping () -> NSStatusItem?,
        pinnedItemsProvider: @escaping () -> [(id: String, item: NSStatusItem)]
    ) {
        self.mainItemProvider = mainItemProvider
        self.pinnedItemsProvider = pinnedItemsProvider
    }

    func start(onMainItemHidden: @escaping () -> Void) {
        self.onMainItemHidden = onMainItemHidden

        let screenChange = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        observers.append(screenChange)

        let itemsChanged = NotificationCenter.default.addObserver(
            forName: .menuBarItemsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        observers.append(itemsChanged)

        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }

        refresh()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }

    private func refresh() {
        let screen = NSScreen.main

        let mainHidden = !StatusBarVisibility.isVisible(mainItemProvider(), on: screen)
        let hiddenPins = pinnedItemsProvider()
            .filter { !StatusBarVisibility.isVisible($0.item, on: screen) }
            .map(\.id)

        let wasHidden = isMainItemHidden
        isMainItemHidden = mainHidden
        hiddenPinnedIDs = hiddenPins

        if mainHidden && !wasHidden {
            onMainItemHidden?()
        }
    }
}
