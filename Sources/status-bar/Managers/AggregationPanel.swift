import AppKit
import SwiftUI

@MainActor
final class AggregationPanel: NSObject, NSWindowDelegate {
    /// Single source of truth for the panel grid geometry: the window sizing
    /// code here and the grid rendering in AggregationView both read these
    /// values, so the two can never drift apart.
    enum Layout {
        static let panelWidth: CGFloat = 360
        static let iconSize: CGFloat = 56
        static let columnsPerRow = 5
        static let verticalPadding: CGFloat = 16
        static let maxVisibleRows = 2

        /// Title row above the grid ("Status Bar · N apps" + close button).
        static let headerHeight: CGFloat = 26

        /// Height used by the empty state instead of a grid row.
        static let emptyStateHeight: CGFloat = 44

        /// One grid cell is a square icon tile.
        static let rowHeight: CGFloat = iconSize
    }

    /// Called with `true` when the pointer enters the panel and `false` when
    /// it leaves; StatusBarManager pauses/resumes the auto-hide countdown.
    var onHoverChange: ((Bool) -> Void)?

    private var panel: NSPanel?
    private var isOrderedIn = false
    private let menuBarMonitor: MenuBarMonitor
    private let settingsStore: SettingsStore

    var isShown: Bool {
        isOrderedIn
    }

    init(menuBarMonitor: MenuBarMonitor, settingsStore: SettingsStore) {
        self.menuBarMonitor = menuBarMonitor
        self.settingsStore = settingsStore
    }

    func show() {
        guard panel == nil else {
            // Panel already exists: re-fit to the current app count and bring it front.
            updatePosition()
            panel?.orderFront(nil)
            isOrderedIn = true
            settingsStore.isAggregationPanelVisible = true
            return
        }

        let height = Self.heightFor(statusbarCount: statusbarCount(), spacing: settingsStore.iconSpacing.value)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Layout.panelWidth, height: height),
            styleMask: [.nonactivatingPanel, .hudWindow, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Deliberately not `isMovableByWindowBackground`: the panel is a
        // transient popup, so an accidental drag would strand it away from the
        // menu bar while the next scan re-centered it anyway.
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95)
        // .hudWindow gives the panel a dark background but does not set
        // NSAppearance, so SwiftUI semantic colors (.primary, .secondary) resolve
        // against the *system* appearance. In light mode that produces dark text
        // on the dark HUD background — invisible. Pin the panel to a dark
        // appearance so the content always renders with light-on-dark colours.
        panel.appearance = NSAppearance(named: .vibrantDark)
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        // The container view owns the tracking area, so AppKit-level hover
        // events reach this class even though the content itself is SwiftUI.
        let container = HoverContainerView(frame: NSRect(x: 0, y: 0, width: Layout.panelWidth, height: height))
        container.autoresizesSubviews = true
        container.onHoverChange = { [weak self] hovering in
            self?.onHoverChange?(hovering)
        }

        let hostingView = NSHostingView(
            rootView: AggregationView()
                .environment(menuBarMonitor)
                .environment(settingsStore)
        )
        // NSHostingView(rootView:) starts with a zero frame, and an
        // autoresizingMask only stretches a frame that already exists — it
        // cannot grow one back from zero. Without this explicit bounds-sized
        // frame the entire SwiftUI content is invisible and the panel is an
        // empty dark rectangle (the "black box" over the user's work). Once
        // sized, autoresizing keeps it glued to the container on every re-fit.
        hostingView.frame = container.bounds
        hostingView.autoresizingMask = [.width, .height]
        container.addSubview(hostingView)

        panel.contentView = container

        positionPanel(panel)

        panel.orderFront(nil)
        self.panel = panel
        isOrderedIn = true
        settingsStore.isAggregationPanelVisible = true
    }

    func hide() {
        panel?.orderOut(nil)
        isOrderedIn = false
        settingsStore.isAggregationPanelVisible = false
    }

    func windowWillClose(_ notification: Notification) {
        isOrderedIn = false
        settingsStore.isAggregationPanelVisible = false
    }

    func toggle() {
        if isShown {
            hide()
        } else {
            show()
        }
    }

    /// Re-positions and re-sizes the panel to fit the current Status Bar app count.
    func updatePosition() {
        guard let panel else { return }
        positionPanel(panel)
    }

    private func statusbarCount() -> Int {
        let byID = Set(menuBarMonitor.menuBarItems.map(\.id))
        return settingsStore.pinnedAppIDs.filter { byID.contains($0) }.count
    }

    /// Total panel height: vertical padding (top + bottom combined) + title row
    /// + grid block.
    ///
    /// Height for a grid of `Layout.columnsPerRow` fixed-size columns; rows
    /// beyond `Layout.maxVisibleRows` scroll inside the panel instead of
    /// growing it.
    static func heightFor(statusbarCount count: Int, spacing: CGFloat) -> CGFloat {
        let rows = count > 0
            ? min(Int(ceil(Double(count) / Double(Layout.columnsPerRow))), Layout.maxVisibleRows)
            : 0
        let gridHeight = rows > 0
            ? CGFloat(rows) * Layout.rowHeight + CGFloat(rows - 1) * spacing
            : Layout.emptyStateHeight
        return Layout.verticalPadding + Layout.headerHeight + gridHeight
    }

    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }

        let menuBarHeight = NSStatusBar.system.thickness
        let spacing = settingsStore.iconSpacing.value
        let height = Self.heightFor(statusbarCount: statusbarCount(), spacing: spacing)
        let x = screen.frame.midX - Layout.panelWidth / 2
        let y = screen.frame.maxY - menuBarHeight - height - 4

        panel.setFrame(NSRect(x: x, y: y, width: Layout.panelWidth, height: height), display: true)
    }
}

/// Plain AppKit container that re-emits mouse entered/exited as a closure.
/// `.inVisibleRect` keeps the tracking area glued to the bounds while the
/// panel re-fits its frame.
private final class HoverContainerView: NSView {
    var onHoverChange: ((Bool) -> Void)?

    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChange?(false)
    }
}
