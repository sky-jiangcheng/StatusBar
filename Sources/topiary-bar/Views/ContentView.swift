import SwiftUI

struct ContentView: View {
    @Environment(MenuBarMonitor.self) private var menuBarMonitor
    @Environment(SettingsStore.self) private var settings
    @Environment(AccessibilityManager.self) private var accessibilityManager
    @Environment(VisibilityMonitor.self) private var visibilityMonitor

    @State private var selectedFilter: AppFilter = .all
    @State private var searchText = ""
    @State private var selectedItemID: String?

    enum AppFilter: String, CaseIterable {
        case all, statusbar, dock
    }

    private var l10n: L10nTable { settings.l10n }

    /// Type filter first, then the search query over name and bundle ID.
    /// Mirrors PopoverView so both surfaces find the same apps.
    private var filteredItems: [MenuBarMonitor.MenuBarItem] {
        let base = menuBarMonitor.sortedByCustomOrder(menuBarMonitor.menuBarItems)
        let scoped: [MenuBarMonitor.MenuBarItem]
        switch selectedFilter {
        case .all:
            scoped = base
        case .statusbar:
            scoped = base.filter { $0.appType == .statusbarOnly }
        case .dock:
            scoped = base.filter { $0.appType == .dockOnly }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return scoped }
        return scoped.filter {
            $0.processName.localizedCaseInsensitiveContains(query)
                || $0.bundleIdentifier.localizedCaseInsensitiveContains(query)
        }
    }

    /// Status Bar apps lead: they are the reason this app exists.
    private var statusbarItems: [MenuBarMonitor.MenuBarItem] {
        filteredItems.filter { $0.appType == .statusbarOnly }
    }

    private var dockItems: [MenuBarMonitor.MenuBarItem] {
        filteredItems.filter { $0.appType == .dockOnly }
    }

    /// Resolved from the full item list, so a selection survives filtering:
    /// clearing a search never blanks the detail pane.
    private var selectedItem: MenuBarMonitor.MenuBarItem? {
        guard let selectedItemID else { return nil }
        return menuBarMonitor.menuBarItems.first { $0.id == selectedItemID }
    }

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)

            detailView
                .frame(minWidth: 400, idealWidth: 500)
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            accessibilityManager.refresh()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            sidebarHeader
            Divider()
            sidebarList
        }
    }

    private var sidebarHeader: some View {
        VStack(spacing: 8) {
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
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: Theme.Radius.control))

            Picker(l10n.all, selection: $selectedFilter) {
                Text(l10n.all).tag(AppFilter.all)
                Text(l10n.statusBar).tag(AppFilter.statusbar)
                Text(l10n.dock).tag(AppFilter.dock)
            }
            .pickerStyle(.segmented)

            // Section headers carry the per-type counts; only a live search
            // needs the extra "N apps" result line.
            if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(String(format: l10n.appsCount, filteredItems.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var sidebarList: some View {
        List(selection: $selectedItemID) {
            if filteredItems.isEmpty {
                ContentUnavailableView(
                    l10n.noApps,
                    systemImage: "app.badge",
                    description: Text(searchText.isEmpty ? (selectedFilter == .all ? l10n.noAppsFound : l10n.noAppsInCategory) : l10n.noAppsFound)
                )
            } else {
                if !statusbarItems.isEmpty {
                    Section {
                        ForEach(statusbarItems) { row(item: $0) }
                    } header: {
                        sectionHeader(l10n.statusBar, systemImage: "menubar.rectangle", count: statusbarItems.count)
                    }
                }

                if !dockItems.isEmpty {
                    Section {
                        ForEach(dockItems) { row(item: $0) }
                    } header: {
                        sectionHeader(l10n.dock, systemImage: "dock.rectangle", count: dockItems.count)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func row(item: MenuBarMonitor.MenuBarItem) -> some View {
        SidebarRow(
            item: item,
            l10n: l10n,
            isSelected: selectedItemID == item.id,
            onSelect: { selectedItemID = item.id }
        )
        .tag(item.id)
    }

    private func sectionHeader(_ title: String, systemImage: String, count: Int) -> some View {
        Label("\(title) · \(count)", systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        if let selectedItem {
            AppDetailView(item: selectedItem, l10n: l10n)
        } else {
            OverviewView(
                l10n: l10n,
                total: menuBarMonitor.menuBarItems.count,
                statusbarCount: menuBarMonitor.menuBarItems.filter { $0.appType == .statusbarOnly }.count,
                dockCount: menuBarMonitor.menuBarItems.filter { $0.appType == .dockOnly }.count,
                accessibilityAuthorized: accessibilityManager.isAuthorized
            )
        }
    }
}

// MARK: - Sidebar row

private struct SidebarRow: View {
    @Environment(MenuBarMonitor.self) private var menuBarMonitor

    let item: MenuBarMonitor.MenuBarItem
    let l10n: L10nTable
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            AppIconView(icon: item.icon, size: 28)

            // Single-line row: the section header already carries the type,
            // a per-row badge only added a second line of noise.
            Text(item.processName)
                .font(.body)
                .lineLimit(1)

            Spacer()

            actionCluster
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovering = $0 }
    }

    /// Kept constant-width so revealing it never shifts the row text, and
    /// hit-tested away while hidden so those pixels fall through to row
    /// selection instead of swallowing the click.
    @ViewBuilder
    private var actionCluster: some View {
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
        .opacity(isHovering || isSelected ? 1 : 0)
        .allowsHitTesting(isHovering || isSelected)
    }
}

// MARK: - Overview (no selection)

/// Landing state shown while no app is selected: brand, a one-glance summary
/// and the passive Accessibility diagnostic.
private struct OverviewView: View {
    let l10n: L10nTable
    let total: Int
    let statusbarCount: Int
    let dockCount: Int
    let accessibilityAuthorized: Bool

    @Environment(VisibilityMonitor.self) private var visibilityMonitor

    /// Main icon occluded and pinned icons occluded read differently; the
    /// pinned variant carries the count.
    private var occlusionBody: String {
        if visibilityMonitor.isMainItemHidden {
            return l10n.notchWarningMainBody
        }
        return String(format: l10n.notchWarningPinnedBody, visibilityMonitor.hiddenPinnedIDs.count)
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "menubar.rectangle")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 4) {
                Text("Topiary")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(l10n.menuBarManager)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                StatChip(systemImage: "list.bullet", title: l10n.total, value: total)
                StatChip(systemImage: "menubar.rectangle", title: l10n.statusBar, value: statusbarCount)
                StatChip(systemImage: "dock.rectangle", title: l10n.dock, value: dockCount)
            }

            if visibilityMonitor.hasOcclusion {
                VStack(alignment: .leading, spacing: 6) {
                    Label(l10n.notchWarningTitle, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                    Text(occlusionBody)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: 420, alignment: .leading)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.Radius.control))
            }

            Text(l10n.selectAppPrompt)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            accessibilityBadge

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    // Diagnostic only — the app never requests Accessibility access, so this
    // is a passive label instead of a permission prompt.
    @ViewBuilder
    private var accessibilityBadge: some View {
        if accessibilityAuthorized {
            Label(l10n.granted, systemImage: "checkmark.shield.fill")
                .font(.caption)
                .foregroundStyle(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.green.opacity(0.1), in: Capsule())
        } else {
            Label(l10n.accessibilityOptional, systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.6), in: Capsule())
        }
    }
}

// MARK: - App detail (selection)

private struct AppDetailView: View {
    @Environment(MenuBarMonitor.self) private var menuBarMonitor
    @Environment(SettingsStore.self) private var settings

    let item: MenuBarMonitor.MenuBarItem
    let l10n: L10nTable

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                AppIconView(icon: item.icon, size: 64)

                VStack(spacing: 4) {
                    Text(item.processName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)

                    Text(item.bundleIdentifier)
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.center)

                    if let footprint = item.memoryFootprint {
                        Text(Format.memory(footprint))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                AppTypeBadge(type: item.appType, l10n: l10n)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.quaternary.opacity(0.6), in: Capsule())

                actions

                if item.appType == .statusbarOnly {
                    Text(l10n.statusbarActivateHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    menuBarMonitor.activateApp(item)
                } label: {
                    Label(l10n.open, systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    settings.togglePin(item.id)
                } label: {
                    Label(
                        settings.isPinned(item.id) ? l10n.unpinFromMenuBar : l10n.pinToMenuBar,
                        systemImage: settings.isPinned(item.id) ? "pin.slash.fill" : "pin.fill"
                    )
                }
                .buttonStyle(.bordered)
            }

#if !MAC_APP_STORE
            HStack(spacing: 10) {
                Button {
                    menuBarMonitor.quitApp(item)
                } label: {
                    Label(l10n.quit, systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    menuBarMonitor.forceQuitApp(item)
                } label: {
                    Label(l10n.forceQuit, systemImage: "exclamationmark.triangle")
                }
                .buttonStyle(.bordered)
            }
#endif
        }
        .padding(.top, 4)
    }
}
