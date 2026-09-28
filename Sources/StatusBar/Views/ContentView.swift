import SwiftUI

struct ContentView: View {
    @Environment(MenuBarMonitor.self) private var menuBarMonitor
    @Environment(SettingsStore.self) private var settings
    @Environment(AccessibilityManager.self) private var accessibilityManager

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
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))

            Picker(l10n.all, selection: $selectedFilter) {
                Text(l10n.all).tag(AppFilter.all)
                Text(l10n.statusBar).tag(AppFilter.statusbar)
                Text(l10n.dock).tag(AppFilter.dock)
            }
            .pickerStyle(.segmented)

            Text(String(format: l10n.appsCount, filteredItems.count))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
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
                ForEach(filteredItems) { item in
                    SidebarRow(
                        item: item,
                        l10n: l10n,
                        isSelected: selectedItemID == item.id,
                        onSelect: { selectedItemID = item.id }
                    )
                    .tag(item.id)
                }
            }
        }
        .listStyle(.sidebar)
    }

    private var detailView: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            statsView
            Divider()

            // The detail pane used to end here, leaving an empty half of the
            // window; it now carries the selected app (or a prompt for it).
            if let selectedItem {
                AppDetailView(item: selectedItem, l10n: l10n)
            } else {
                ContentUnavailableView(l10n.selectAppPrompt, systemImage: "cursorarrow.click.2")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "menubar.rectangle")
                .font(.system(size: 36))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("StatusBar")
                    .font(.title)
                    .fontWeight(.semibold)

                Text(l10n.menuBarManager)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Diagnostic only — the app never requests Accessibility access, so
            // this is a passive label instead of a permission prompt.
            if accessibilityManager.isAuthorized {
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
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    private var statsView: some View {
        HStack(spacing: 12) {
            StatCard(
                title: l10n.total,
                value: "\(menuBarMonitor.menuBarItems.count)",
                icon: "list.bullet",
                color: .blue,
                isSelected: selectedFilter == .all
            ) {
                withAnimation { selectedFilter = .all }
            }

            StatCard(
                title: l10n.statusBar,
                value: "\(menuBarMonitor.menuBarItems.filter { $0.appType == .statusbarOnly }.count)",
                icon: "menubar.rectangle",
                color: .purple,
                isSelected: selectedFilter == .statusbar
            ) {
                withAnimation { selectedFilter = .statusbar }
            }

            StatCard(
                title: l10n.dock,
                value: "\(menuBarMonitor.menuBarItems.filter { $0.appType == .dockOnly }.count)",
                icon: "dock.rectangle",
                color: .green,
                isSelected: selectedFilter == .dock
            ) {
                withAnimation { selectedFilter = .dock }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

private struct SidebarRow: View {
    @Environment(MenuBarMonitor.self) private var menuBarMonitor

    let item: MenuBarMonitor.MenuBarItem
    let l10n: L10nTable
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            if let icon = item.icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "app.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.processName)
                    .font(.body)
                    .lineLimit(1)

                Text(item.appType == .statusbarOnly ? l10n.statusBar : l10n.dock)
                    .font(.caption)
                    .foregroundStyle(item.appType == .statusbarOnly ? .purple : .green)
            }

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
        HStack(spacing: 8) {
            Button {
                menuBarMonitor.activateApp(item)
            } label: {
                Image(systemName: "arrow.up.forward.app")
                    .font(.body)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .help(l10n.open)

#if !MAC_APP_STORE
            Button {
                menuBarMonitor.quitApp(item)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help(l10n.quit)

            Button {
                menuBarMonitor.forceQuitApp(item)
            } label: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
            .help(l10n.forceQuit)
#endif
        }
        .opacity(isHovering || isSelected ? 1 : 0)
        .allowsHitTesting(isHovering || isSelected)
    }
}

private struct AppDetailView: View {
    @Environment(MenuBarMonitor.self) private var menuBarMonitor

    let item: MenuBarMonitor.MenuBarItem
    let l10n: L10nTable

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                appIcon

                Text(item.processName)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)

                Text(item.bundleIdentifier)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.center)

                Text(item.appType == .statusbarOnly ? l10n.statusBar : l10n.dock)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (item.appType == .statusbarOnly ? Color.purple : Color.green).opacity(0.15),
                        in: Capsule()
                    )
                    .foregroundStyle(item.appType == .statusbarOnly ? .purple : .green)

                actions
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
    }

    @ViewBuilder
    private var appIcon: some View {
        if let icon = item.icon {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
                .frame(width: 64, height: 64)
        }
    }

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                menuBarMonitor.activateApp(item)
            } label: {
                Label(l10n.open, systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.borderedProminent)

#if !MAC_APP_STORE
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
#endif
        }
        .padding(.top, 4)
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : color)
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? .white : .primary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? color : color.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? color : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
