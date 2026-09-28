import AppKit
import SwiftUI

struct PopoverView: View {
    @Environment(MenuBarMonitor.self) private var menuBarMonitor
    @Environment(SettingsStore.self) private var settings
    @Environment(\.openWindow) private var openWindow

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

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            Divider()

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

            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(settings.aggregationMode == .aggregation ? .orange : .secondary)
                Text(modeBadgeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary.opacity(0.6), in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// All three aggregation modes render their own badge label; a two-way
    /// ternary previously showed "Normal" in Disabled mode.
    private var modeBadgeText: String {
        switch settings.aggregationMode {
        case .aggregation: return l10n.modeAggregation
        case .normal: return l10n.modeNormal
        case .disabled: return l10n.modeDisabled
        }
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
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
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
                    LazyVStack(spacing: 0) {
                        ForEach(filteredItems) { item in
                            IconRow(item: item, l10n: l10n)
                        }
                    }
                }
            }
        }
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

    private var panelToggleTooltip: String {
        settings.isAggregationPanelVisible ? l10n.hideAggregationPanel : l10n.showAggregationPanel
    }
}

private struct IconRow: View {
    @Environment(MenuBarMonitor.self) private var menuBarMonitor

    let item: MenuBarMonitor.MenuBarItem
    let l10n: L10nTable

    var body: some View {
        HStack(spacing: 10) {
            if let icon = item.icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "app.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.processName)
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Text(item.appType == .statusbarOnly ? l10n.statusBar : l10n.dock)
                    .font(.caption2)
                    .foregroundStyle(item.appType == .statusbarOnly ? .purple : .green)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    menuBarMonitor.activateApp(item)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .help(l10n.open)

#if !MAC_APP_STORE
                Button {
                    menuBarMonitor.quitApp(item)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help(l10n.quit)

                Button {
                    menuBarMonitor.forceQuitApp(item)
                } label: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .help(l10n.forceQuit)
#endif
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
