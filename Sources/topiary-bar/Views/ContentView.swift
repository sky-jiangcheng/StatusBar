import SwiftUI

struct ContentView: View {
    @Environment(MenuBarMonitor.self) private var menuBarMonitor
    @Environment(SettingsStore.self) private var settings
    @Environment(VisibilityMonitor.self) private var visibilityMonitor

    @State private var selectedFilter: AppFilter = .all
    @State private var searchText = ""
    @State private var selectedItemID: String?
    @State private var windowTab: WindowTab = .apps

    enum WindowTab: Hashable {
        case apps, settings
    }

    enum AppFilter: String, CaseIterable {
        case all, statusbar, dock
    }

    private var l10n: L10nTable { settings.l10n }

    /// Type filter first, then the search query over name and bundle ID.
    /// Mirrors PopoverView so both surfaces find the same apps.
    private var filteredItems: [MenuBarMonitor.MenuBarItem] {
        let scoped: [MenuBarMonitor.MenuBarItem]
        switch selectedFilter {
        case .all:
            scoped = menuBarMonitor.menuBarItems
        case .statusbar:
            scoped = menuBarMonitor.menuBarItems.filter { $0.appType == .statusbarOnly }
        case .dock:
            scoped = menuBarMonitor.menuBarItems.filter { $0.appType == .dockOnly }
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
        Group {
            switch windowTab {
            case .apps:
                appsView
            case .settings:
                SettingsView()
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .toolbar {
            ToolbarItem(placement: .principal) {
                // Brand + window tabs share the title bar, so the full name
                // stays visible on both tabs.
                HStack(spacing: 14) {
                    Text(Brand.name)
                        .font(.headline)
                    Picker("", selection: $windowTab) {
                        Text(l10n.windowTabApps).tag(WindowTab.apps)
                        Text(l10n.windowTabSettings).tag(WindowTab.settings)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 200)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectSettingsTab)) { _ in
            windowTab = .settings
        }
    }

    private var appsView: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)

            detailView
                .frame(minWidth: 400, idealWidth: 500)
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
            .labelsHidden()

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
        SidebarRow(item: item, onSelect: { selectedItemID = item.id })
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
                dockCount: menuBarMonitor.menuBarItems.filter { $0.appType == .dockOnly }.count
            )
        }
    }
}

// MARK: - Sidebar row

private struct SidebarRow: View {
    @Environment(SettingsStore.self) private var settings

    let item: MenuBarMonitor.MenuBarItem
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            AppIconView(icon: item.icon, size: 28)

            // Single-line row, consistent with the popover list: the section
            // header carries the type, actions live in the detail pane.
            Text(item.processName)
                .font(.body)
                .lineLimit(1)

            // Pinned apps carry their own resident status item in the menu
            // bar — mark it right in the list.
            if settings.isPinned(item.id) {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Spacer()

            if let footprint = item.memoryFootprint {
                Text(Format.memory(footprint))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}

// MARK: - Overview (no selection)

/// Landing state shown while no app is selected: brand and a one-glance
/// summary of what the menu bar currently holds.
private struct OverviewView: View {
    let l10n: L10nTable
    let total: Int
    let statusbarCount: Int
    let dockCount: Int

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
                Text(Brand.name)
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

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

// MARK: - App detail (selection)

/// Left-aligned definition-list layout — identity header, an info card
/// (type / memory / PID), then actions — instead of everything floating
/// centered with no hierarchy.
private struct AppDetailView: View {
    @Environment(MenuBarMonitor.self) private var menuBarMonitor
    @Environment(SettingsStore.self) private var settings

    let item: MenuBarMonitor.MenuBarItem
    let l10n: L10nTable

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    AppIconView(icon: item.icon, size: 64)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.processName)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        Text(item.bundleIdentifier)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 0) {
                    infoRow(l10n.infoType) {
                        AppTypeBadge(type: item.appType, l10n: l10n)
                    }
                    Divider()
                    infoRow(l10n.memoryUsage) {
                        Text(item.memoryFootprint.map { Format.memory($0) } ?? "—")
                            .font(.callout.monospacedDigit())
                    }
                    Divider()
                    infoRow(l10n.infoPID) {
                        Text("\(item.pid)")
                            .font(.callout.monospacedDigit())
                    }
                }
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: Theme.Radius.control))

                actions

                if item.appType == .statusbarOnly {
                    Text(l10n.statusbarActivateHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: 400)
            .padding(24)
        }
    }

    private func infoRow<Content: View>(_ label: String, @ViewBuilder value: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            value()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: 10) {
            if menuBarMonitor.canOpen(item) {
                Button {
                    menuBarMonitor.activateApp(item)
                } label: {
                    Label(l10n.open, systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.borderedProminent)
            }

            // Residency only makes sense for menu-bar (accessory) apps: Dock
            // apps are already permanently visible in the Dock.
            if item.appType == .statusbarOnly {
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
            if menuBarMonitor.canQuit(item) {
                Button {
                    menuBarMonitor.quitApp(item)
                } label: {
                    Label(l10n.quit, systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
            }
#endif
        }
        .padding(.top, 4)
    }
}
