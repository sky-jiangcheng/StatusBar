import SwiftUI

struct IconOrderView: View {
    @Binding var customOrder: [String]
    let menuBarItems: [MenuBarMonitor.MenuBarItem]
    let l10n: L10nTable

    var orderedItems: [MenuBarMonitor.MenuBarItem] {
        // uniquingKeysWith keeps this safe when two processes share a bundle ID
        // (duplicate keys would otherwise trap at runtime).
        let itemMap = Dictionary(
            menuBarItems.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return customOrder.compactMap { itemMap[$0] }
    }

    var unorderedItems: [MenuBarMonitor.MenuBarItem] {
        let orderSet = Set(customOrder)
        return menuBarItems.filter { !orderSet.contains($0.id) }
    }

    /// Handles an ID dragged out of the "Unordered" section and dropped on a
    /// custom-order row: the icon is inserted immediately before that row.
    /// Without a drop target the `.draggable` rows had nowhere to land, so
    /// dragging an unordered icon was a silent no-op.
    private func insertIntoOrder(_ ids: [String], before item: MenuBarMonitor.MenuBarItem) -> Bool {
        guard let dropped = ids.first,
              !customOrder.contains(dropped),
              let index = customOrder.firstIndex(of: item.id) else { return false }
        customOrder.insert(dropped, at: index)
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(l10n.iconOrderTitle)
                .font(.headline)

            Text(l10n.iconOrderCaption)
                .font(.caption)
                .foregroundStyle(.secondary)

            if orderedItems.isEmpty && unorderedItems.isEmpty {
                ContentUnavailableView(
                    l10n.noIcons,
                    systemImage: "list.bullet",
                    description: Text(l10n.noIconsDetected)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    if !orderedItems.isEmpty {
                        Section(l10n.sectionCustomOrder) {
                            ForEach(orderedItems) { item in
                                IconRow(item: item, l10n: l10n)
                                    .dropDestination(for: String.self) { ids, _ in
                                        insertIntoOrder(ids, before: item)
                                    }
                            }
                            .onMove { source, destination in
                                // onMove reports indices into the visible ordered
                                // list. Keep IDs not currently running after the
                                // visible entries so their relative order is
                                // preserved if the apps return.
                                let visibleIDs = Set(orderedItems.map(\.id))
                                let hiddenIDs = customOrder.filter { !visibleIDs.contains($0) }
                                customOrder = orderedItems.map(\.id)
                                customOrder.move(fromOffsets: source, toOffset: destination)
                                customOrder.append(contentsOf: hiddenIDs)
                            }
                            .onDelete { indexSet in
                                // Capture IDs first: orderedItems recomputes from
                                // customOrder, which mutates on each removal.
                                let ids = indexSet.compactMap { orderedItems.indices.contains($0) ? orderedItems[$0].id : nil }
                                customOrder.removeAll { ids.contains($0) }
                            }
                        }
                    }

                    if !unorderedItems.isEmpty {
                        Section(l10n.sectionUnordered) {
                            ForEach(unorderedItems) { item in
                                IconRow(item: item, l10n: l10n)
                                    .draggable(item.id)
                            }
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }
}

private struct IconRow: View {
    let item: MenuBarMonitor.MenuBarItem
    let l10n: L10nTable

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)

            if let icon = item.icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "app.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.processName)
                    .font(.body)
                Text(item.bundleIdentifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(item.appType == .statusbarOnly ? l10n.statusBar : l10n.dock)
                .font(.caption)
                .foregroundStyle(item.appType == .statusbarOnly ? .purple : .green)
        }
        .padding(.vertical, 4)
    }
}
