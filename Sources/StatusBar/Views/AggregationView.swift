import SwiftUI

struct AggregationView: View {
    @Environment(MenuBarMonitor.self) private var menuBarMonitor
    @Environment(SettingsStore.self) private var settings

    private var l10n: L10nTable { settings.l10n }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Escape dismisses the panel through the same path as the context menu,
        // so the manual-hide grace window keeps suppressing the next auto-show.
        .onExitCommand {
            NotificationCenter.default.post(name: .toggleAggregationPanel, object: nil)
        }
    }

    /// Without a title row the panel is a bare grid of icons that floats over
    /// the user's work, and the only way to get rid of it is to wait for the
    /// auto-hide countdown.
    private var header: some View {
        HStack(spacing: 8) {
            Text(l10n.statusBar)
                .font(.headline)

            Text(String(format: l10n.appsCount, statusbarItems.count))
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 4)

            Button {
                NotificationCenter.default.post(name: .toggleAggregationPanel, object: nil)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(l10n.hideAggregationPanel)
            .accessibilityLabel(l10n.hideAggregationPanel)
        }
        .frame(height: AggregationPanel.Layout.headerHeight)
    }

    @ViewBuilder
    private var content: some View {
        if statusbarItems.isEmpty {
            emptyState
        } else {
            grid
        }
    }

    // Aggregation semantics: only Status Bar (accessory) apps belong in the panel.
    private var statusbarItems: [MenuBarMonitor.MenuBarItem] {
        menuBarMonitor.sortedByCustomOrder(
            menuBarMonitor.menuBarItems.filter { $0.appType == .statusbarOnly }
        )
    }

    private var emptyState: some View {
        HStack {
            aggregationIconView
                .frame(width: 20, height: 20)
            Text(settings.l10n.noStatusApps)
                .font(.callout)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var grid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.fixed(AggregationPanel.Layout.iconSize), spacing: settings.iconSpacing.value),
                    count: AggregationPanel.Layout.columnsPerRow
                ),
                spacing: settings.iconSpacing.value
            ) {
                ForEach(statusbarItems) { item in
                    AggregationIcon(item: item)
                }
            }
        }
    }

    @ViewBuilder
    private var aggregationIconView: some View {
        switch settings.aggregationIcon {
        case .dots:
            HStack(spacing: 3) {
                Circle().fill(Color.primary).frame(width: 5, height: 5)
                Circle().fill(Color.primary).frame(width: 5, height: 5)
                Circle().fill(Color.primary).frame(width: 5, height: 5)
            }
        case .grid:
            Image(systemName: "square.grid.2x2")
        case .chevron:
            Image(systemName: "chevron.down")
        case .square:
            Image(systemName: "square.fill")
        case .circle:
            Image(systemName: "circle.fill")
        case .transparent:
            Image(systemName: "circle.dotted")
                .foregroundStyle(.secondary)
        }
    }
}

private struct AggregationIcon: View {
    @Environment(MenuBarMonitor.self) private var menuBarMonitor

    let item: MenuBarMonitor.MenuBarItem

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 4) {
            if let icon = item.icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "app.fill")
                    .font(.title3)
                    .frame(width: 24, height: 24)
            }

            Text(item.processName)
                .font(.system(size: 9))
                .lineLimit(1)
        }
        .frame(width: AggregationPanel.Layout.iconSize, height: AggregationPanel.Layout.iconSize)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            if isHovering {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.secondary, lineWidth: 1)
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
        // Clicking an aggregated icon activates its app. The panel is a
        // non-activating NSPanel, so focus stays with whatever the user was on.
        .onTapGesture {
            menuBarMonitor.activateApp(item)
        }
        .help(item.processName)
    }
}
