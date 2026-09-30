import SwiftUI

/// Resident panel that shows the apps the user pinned (rather than "every
/// Status Bar app currently running"). It is managed in place: a "+" in the
/// header adds more apps, hovering an icon reveals its × to unpin.
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
        .onExitCommand {
            NotificationCenter.default.post(name: .toggleAggregationPanel, object: nil)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(l10n.statusBar)
                .font(.headline)

            Text(String(format: l10n.appsCount, pinnedItems.count))
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 4)

            // Add a new app to the resident panel from all detectable apps.
            Menu {
                ForEach(addableItems) { item in
                    Button {
                        settings.togglePin(item.id)
                    } label: {
                        Label {
                            Text(item.processName)
                        } icon: {
                            if let icon = item.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 16, height: 16)
                            }
                        }
                    }
                }
                if addableItems.isEmpty {
                    Text(l10n.noAppsToPin)
                        .disabled(true)
                }
            } label: {
                Image(systemName: "plus.circle")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(l10n.addAppToPanel)
            .accessibilityLabel(l10n.addAppToPanel)

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
        if pinnedItems.isEmpty {
            emptyState
        } else {
            grid
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                Text(l10n.noPinnedApps)
                    .font(.callout)
            }
            Text(l10n.noPinnedAppsCaption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, AggregationPanel.Layout.headerHeight)
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
                ForEach(pinnedItems) { item in
                    AggregationIcon(item: item)
                }
            }
        }
    }

    /// Only the apps the user pinned (in pin order); apps already pinned hide
    /// until explicitly removed.
    private var pinnedItems: [MenuBarMonitor.MenuBarItem] {
        let byID = Dictionary(menuBarMonitor.menuBarItems.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return settings.pinnedAppIDs.compactMap { byID[$0] }
    }

    /// Detectable apps that are not yet pinned, offered by the "+" menu.
    private var addableItems: [MenuBarMonitor.MenuBarItem] {
        let pinned = Set(settings.pinnedAppIDs)
        return menuBarMonitor.menuBarItems
            .filter { !pinned.contains($0.id) }
            .sorted { $0.processName.localizedCaseInsensitiveCompare($1.processName) == .orderedAscending }
    }
}

private struct AggregationIcon: View {
    @Environment(MenuBarMonitor.self) private var menuBarMonitor
    @Environment(SettingsStore.self) private var settings

    let item: MenuBarMonitor.MenuBarItem

    @State private var isHovering = false

    private var l10n: L10nTable { settings.l10n }

    var body: some View {
        VStack(spacing: 4) {
            AppIconView(icon: item.icon, size: 30)

            Text(item.processName)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
        }
        .frame(width: AggregationPanel.Layout.iconSize, height: AggregationPanel.Layout.iconSize)
        .background(
            Color.white.opacity(isHovering ? 0.14 : 0.07),
            in: RoundedRectangle(cornerRadius: Theme.Radius.tile)
        )
        .overlay {
            if isHovering {
                RoundedRectangle(cornerRadius: Theme.Radius.tile)
                    .stroke(Color.accentColor.opacity(0.6), lineWidth: 1)
            }
        }
        .scaleEffect(isHovering ? 1.04 : 1.0)
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .overlay(alignment: .topTrailing) {
            if isHovering {
                Button {
                    settings.togglePin(item.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondary, Color.black.opacity(0.7))
                        .background(Circle().fill(Color.white))
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
                .help(l10n.removeFromPanel)
                .accessibilityLabel(l10n.removeFromPanel)
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