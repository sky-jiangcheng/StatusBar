import AppKit
import SwiftUI

struct PopoverView: View {
    @Environment(MenuBarMonitor.self) private var menuBarMonitor
    @Environment(SettingsStore.self) private var settings
    @Environment(\.openWindow) private var openWindow
    @Environment(VisibilityMonitor.self) private var visibilityMonitor

    @State private var searchText = ""

    let onDismiss: () -> Void

    private var l10n: L10nTable { settings.l10n }

    private var filteredItems: [MenuBarMonitor.MenuBarItem] {
        let base = menuBarMonitor.sortedByCustomOrder(menuBarMonitor.menuBarItems)
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return base
        }
        return base.filter { item in
            item.processName.localizedCaseInsensitiveContains(searchText)
                || item.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Status Bar apps lead: they are the reason this app exists.
    private var statusbarItems: [MenuBarMonitor.MenuBarItem] {
        filteredItems.filter { $0.appType == .statusbarOnly }
    }

    private var dockItems: [MenuBarMonitor.MenuBarItem] {
        filteredItems.filter { $0.appType == .dockOnly }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            if visibilityMonitor.hasOcclusion {
                occlusionBanner
                Divider()
            } else {
                Divider()
            }

            searchSection

            Divider()

            iconListSection

            Divider()

            footerSection
        }
        .frame(minWidth: 360, idealWidth: 360, minHeight: 420, idealHeight: 480)
    }

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("StatusBar")
                    .font(.headline)
                Text(String(format: l10n.appsCount, menuBarMonitor.menuBarItems.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var searchSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(l10n.searchPlaceholder, text: $searchText)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: Theme.Radius.control))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var iconListSection: some View {
        VStack(spacing: 0) {
            if filteredItems.isEmpty {
                ContentUnavailableView(
                    l10n.noApps,
                    systemImage: "app.badge",
                    description: Text(l10n.noAppsFound)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        if !statusbarItems.isEmpty {
                            Section {
                                ForEach(statusbarItems) { IconRow(item: $0, l10n: l10n) }
                            } header: {
                                sectionHeader(l10n.statusBar, systemImage: "menubar.rectangle", count: statusbarItems.count)
                            }
                        }

                        if !dockItems.isEmpty {
                            Section {
                                ForEach(dockItems) { IconRow(item: $0, l10n: l10n) }
                            } header: {
                                sectionHeader(l10n.dock, systemImage: "dock.rectangle", count: dockItems.count)
                            }
                        }
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String, systemImage: String, count: Int) -> some View {
        Label("\(title) · \(count)", systemImage: systemImage)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(.quaternary.opacity(0.3))
    }

    private var footerSection: some View {
        HStack(spacing: 6) {
            Spacer(minLength: 0)

            // Icon-only keeps the row inside the 360pt popover across all five
            // languages; the state lives in the tooltip / accessibility label.
            Button {
                NotificationCenter.default.post(name: .toggleAggregationPanel, object: nil)
            } label: {
                Image(systemName: settings.isAggregationPanelVisible ? "rectangle.stack.fill" : "rectangle.stack")
                    .foregroundStyle(settings.isAggregationPanelVisible ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(panelToggleTooltip)
            .accessibilityLabel(panelToggleTooltip)

            // The main window is closable and has no other re-entry point, so
            // the popover — the surface users reach first — carries it.
            Button(l10n.openMainWindow) {
                openWindow(id: "main")
            }
            .buttonStyle(.plain)

            Button(l10n.settingsDots) {
                AppSettingsOpener.open()
            }
            .buttonStyle(.plain)

            Button(l10n.quit) {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    /// Compact warning shown when our own icons are occluded by the notch or
    /// an overcrowded menu bar (only reachable while the main icon is visible,
    /// so this is usually the pinned-icons case).
    private var occlusionBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
            Text(occlusionBody)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.10))
    }

    private var occlusionBody: String {
        if visibilityMonitor.isMainItemHidden {
            return l10n.notchWarningMainBody
        }
        return String(format: l10n.notchWarningPinnedBody, visibilityMonitor.hiddenPinnedIDs.count)
    }

    private var panelToggleTooltip: String {
        settings.isAggregationPanelVisible ? l10n.hideAggregationPanel : l10n.showAggregationPanel
    }
}

private struct IconRow: View {
    @Environment(MenuBarMonitor.self) private var menuBarMonitor

    let item: MenuBarMonitor.MenuBarItem
    let l10n: L10nTable

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            AppIconView(icon: item.icon, size: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.processName)
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                AppTypeBadge(type: item.appType, l10n: l10n)
            }

            Spacer()

            // Hidden until hover so ten quiet rows read as one calm list.
            HStack(spacing: 4) {
                RowActionButton(systemImage: "arrow.up.forward.app", tint: .accentColor, help: l10n.open) {
                    menuBarMonitor.activateApp(item)
                }

#if !MAC_APP_STORE
                RowActionButton(systemImage: "xmark.circle.fill", tint: .red, help: l10n.quit) {
                    menuBarMonitor.quitApp(item)
                }

                RowActionButton(systemImage: "exclamationmark.triangle.fill", tint: .orange, help: l10n.forceQuit) {
                    menuBarMonitor.forceQuitApp(item)
                }
#endif
            }
            .opacity(isHovering ? 1 : 0)
            .allowsHitTesting(isHovering)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}
