import AppKit
import SwiftUI

struct PopoverView: View {
    @Environment(MenuBarMonitor.self) private var menuBarMonitor
    @Environment(SettingsStore.self) private var settings
    @Environment(\.openWindow) private var openWindow
    @Environment(VisibilityMonitor.self) private var visibilityMonitor
    @Environment(SystemMemoryMonitor.self) private var systemMemory

    @State private var searchText = ""
    @State private var occlusionDismissed = false

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

    /// Status Bar apps lead; within each section the heaviest memory users
    /// surface first, so the hog is always the top row.
    private var statusbarItems: [MenuBarMonitor.MenuBarItem] {
        filteredItems
            .filter { $0.appType == .statusbarOnly }
            .sorted { ($0.memoryFootprint ?? 0) > ($1.memoryFootprint ?? 0) }
    }

    private var dockItems: [MenuBarMonitor.MenuBarItem] {
        filteredItems
            .filter { $0.appType == .dockOnly }
            .sorted { ($0.memoryFootprint ?? 0) > ($1.memoryFootprint ?? 0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            memorySection

            if visibilityMonitor.hasOcclusion && !occlusionDismissed {
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
        .frame(minWidth: 360, idealWidth: 360, minHeight: 420, idealHeight: 520)
        .onChange(of: visibilityMonitor.hasOcclusion) { _, stillOccluded in
            // Re-arm the manual dismissal once the occlusion clears, so a new
            // occurrence warns again instead of staying silenced forever.
            if !stillOccluded { occlusionDismissed = false }
        }
    }

    private var headerSection: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Topiary")
                    .font(.headline)
                Text(String(format: l10n.appsCount, menuBarMonitor.menuBarItems.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Explicit close affordance — outside clicks already dismiss the
            // transient popover, but a visible × makes the way out obvious.
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(l10n.popoverClose)
            .accessibilityLabel(l10n.popoverClose)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// Lemon-style overview: system memory as a percentage with a progress
    /// bar and used/total breakdown.
    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Label(l10n.memoryUsage, systemImage: "memorychip")
                    .font(.callout)
                Spacer()
                Text(percentText)
                    .font(.callout.monospacedDigit())
                    .fontWeight(.semibold)
                    .foregroundStyle(systemMemory.usedFraction > 0.85 ? Color.orange : Color.primary)
            }

            ProgressView(value: systemMemory.usedFraction)
                .progressViewStyle(.linear)
                .tint(systemMemory.usedFraction > 0.85 ? Color.orange : Color.accentColor)

            Text("\(Format.memory(systemMemory.usedBytes)) / \(Format.memory(systemMemory.totalBytes))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: Theme.Radius.control))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var percentText: String {
        "\(Int((systemMemory.usedFraction * 100).rounded()))%"
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
                                sectionHeader(l10n.statusBar, count: statusbarItems.count)
                            }
                        }

                        if !dockItems.isEmpty {
                            Section {
                                ForEach(dockItems) { IconRow(item: $0, l10n: l10n) }
                            } header: {
                                sectionHeader(l10n.dock, count: dockItems.count)
                            }
                        }
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        Text("\(title) · \(count)")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 5)
            .background(.quaternary.opacity(0.25))
    }

    private var footerSection: some View {
        HStack(spacing: 12) {
            // Settings, left.
            Button {
                AppSettingsOpener.open()
            } label: {
                Image(systemName: "gearshape")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(l10n.settingsDots)
            .accessibilityLabel(l10n.settingsDots)

            Spacer(minLength: 0)

            // Primary action, centered like Lemon's "Open Lemon": the main
            // window is closable with no other re-entry point, so the popover
            // — the surface users reach first — carries it.
            Button {
                openWindow(id: "main")
            } label: {
                Label(l10n.openMainWindow, systemImage: "macwindow")
                    .font(.callout)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Spacer(minLength: 0)

            // Panel toggle, right; icon-only with the state in the tooltip.
            Button {
                NotificationCenter.default.post(name: .toggleAggregationPanel, object: nil)
            } label: {
                Image(systemName: settings.isAggregationPanelVisible ? "rectangle.stack.fill" : "rectangle.stack")
                    .foregroundStyle(settings.isAggregationPanelVisible ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(panelToggleTooltip)
            .accessibilityLabel(panelToggleTooltip)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    /// Compact, dismissible warning for genuine occlusion (a menu-bar hider
    /// utility suppresses it entirely).
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
            Button {
                occlusionDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(l10n.popoverClose)
            .accessibilityLabel(l10n.popoverClose)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.08))
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
            AppIconView(icon: item.icon, size: 26)

            Text(item.processName)
                .font(.system(.body, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(.primary)

            Spacer()

            if let footprint = item.memoryFootprint {
                Text(Format.memory(footprint))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

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
