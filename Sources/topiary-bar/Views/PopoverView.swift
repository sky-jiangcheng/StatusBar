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
        let base = menuBarMonitor.menuBarItems
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
                Text(Brand.name)
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

    /// Compact Lemon-style overview: one label/value line over a thin bar —
    /// deliberately small so the app list stays the protagonist.
    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: "memorychip")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(l10n.memoryUsage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Format.memory(systemMemory.usedBytes)) / \(Format.memory(systemMemory.totalBytes))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(percentText)
                    .font(.callout.monospacedDigit())
                    .fontWeight(.semibold)
                    .foregroundStyle(systemMemory.usedFraction > 0.85 ? Color.orange : Color.primary)
            }
            ProgressView(value: systemMemory.usedFraction)
                .progressViewStyle(.linear)
                .controlSize(.small)
                .tint(systemMemory.usedFraction > 0.85 ? Color.orange : Color.accentColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: Theme.Radius.control))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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
            // Settings, left: opens the main window on its Settings tab
            // (AppDelegate summons the window, ContentView switches tabs).
            Button {
                NotificationCenter.default.post(name: .openSettingsTab, object: nil)
            } label: {
                Image(systemName: "gearshape")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(l10n.settingsDots)
            .accessibilityLabel(l10n.settingsDots)
            .frame(width: 60, alignment: .leading)

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

            // Quit, right: this is an LSUIElement background agent with no
            // Dock icon — without this button there is no discoverable way
            // to exit the app.
            Button {
                NSApp.terminate(nil)
            } label: {
                Text(l10n.quit)
                    .font(.callout)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
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
}

private struct IconRow: View {
    @Environment(MenuBarMonitor.self) private var menuBarMonitor

    let item: MenuBarMonitor.MenuBarItem
    let l10n: L10nTable

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

            // Visible, labeled mini buttons: icon-only hover controls were
            // unreadable at a glance. Dead actions are hidden entirely — see
            // canOpen/canQuit.
            if menuBarMonitor.canOpen(item) {
                Button(l10n.open) {
                    menuBarMonitor.activateApp(item)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

#if !MAC_APP_STORE
            if menuBarMonitor.canQuit(item) {
                Button(l10n.quit) {
                    menuBarMonitor.quitApp(item)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
#endif
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }
}
