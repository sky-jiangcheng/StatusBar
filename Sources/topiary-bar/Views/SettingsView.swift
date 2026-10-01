import SwiftUI

struct SettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(MenuBarMonitor.self) private var menuBarMonitor

    var body: some View {
        TabView {
            GeneralSettingsTab(
                l10n: settings.l10n,
                appearance: Binding(
                    get: { settings.appearance },
                    set: {
                        settings.appearance = $0
                        settings.save()
                        settings.applyAppearance()
                    }
                ),
                language: Binding(
                    get: { settings.language },
                    set: { settings.language = $0; settings.save() }
                ),
                refreshInterval: Binding(
                    get: { settings.refreshInterval },
                    set: {
                        settings.refreshInterval = $0
                        settings.save()
                        NotificationCenter.default.post(name: .refreshIntervalChanged, object: nil)
                    }
                )
            )
            .tabItem {
                Label(settings.l10n.tabGeneral, systemImage: "gear")
            }

            AggregationSettingsTab(
                l10n: settings.l10n,
                aggregationIcon: Binding(
                    get: { settings.aggregationIcon },
                    set: { settings.aggregationIcon = $0; settings.save() }
                ),
                iconSpacing: Binding(
                    get: { settings.iconSpacing },
                    set: { settings.iconSpacing = $0; settings.save() }
                )
            )
            .tabItem {
                Label(settings.l10n.tabAggregation, systemImage: "rectangle.stack")
            }

            IconManagementTab()
                .tabItem {
                    Label(settings.l10n.tabIcons, systemImage: "list.bullet")
                }

            IconOrderTab(
                customOrder: Binding(
                    get: { settings.customOrder },
                    set: { settings.customOrder = $0; settings.save() }
                )
            )
            .tabItem {
                Label(settings.l10n.tabOrder, systemImage: "arrow.up.arrow.down")
            }
        }
        .formStyle(.grouped)
    }
}

struct GeneralSettingsTab: View {
    let l10n: L10nTable
    @Binding var appearance: AppearanceMode
    @Binding var language: AppLanguage
    @Binding var refreshInterval: TimeInterval

    var body: some View {
        Form {
            Section(l10n.sectionAppearance) {
                Picker("", selection: $appearance) {
                    Text(l10n.appearanceSystem).tag(AppearanceMode.system)
                    Text(l10n.appearanceLight).tag(AppearanceMode.light)
                    Text(l10n.appearanceDark).tag(AppearanceMode.dark)
                }
                .pickerStyle(.segmented)
            }

            Section(l10n.sectionLanguage) {
                Picker("", selection: $language) {
                    Text(l10n.languageSystem).tag(AppLanguage.system)
                    Text(AppLanguage.en.nativeName).tag(AppLanguage.en)
                    Text(AppLanguage.zhHans.nativeName).tag(AppLanguage.zhHans)
                    Text(AppLanguage.ja.nativeName).tag(AppLanguage.ja)
                    Text(AppLanguage.de.nativeName).tag(AppLanguage.de)
                    Text(AppLanguage.es.nativeName).tag(AppLanguage.es)
                }
            }

            Section(l10n.sectionRefresh) {
                HStack {
                    Text(l10n.scanInterval)
                    Spacer()
                    Picker("", selection: $refreshInterval) {
                        Text("1s").tag(1.0)
                        Text("2s").tag(2.0)
                        Text("5s").tag(5.0)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
            }
        }
    }
}

struct AggregationSettingsTab: View {
    let l10n: L10nTable
    @Binding var aggregationIcon: SettingsStore.AggregationIconType
    @Binding var iconSpacing: SettingsStore.IconSpacing

    var body: some View {
        Form {
            Section(l10n.sectionAggIcon) {
                AggregationIconSelector(selectedIcon: $aggregationIcon, l10n: l10n)
            }

            Section(l10n.sectionSpacing) {
                Picker(l10n.sectionSpacing, selection: $iconSpacing) {
                    Text(l10n.spacingDefault).tag(SettingsStore.IconSpacing.default)
                    Text(l10n.spacingCompact).tag(SettingsStore.IconSpacing.compact)
                    Text(l10n.spacingSmall).tag(SettingsStore.IconSpacing.small)
                    Text(l10n.spacingNone).tag(SettingsStore.IconSpacing.none)
                }
            }
        }
    }
}

struct IconManagementTab: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(MenuBarMonitor.self) private var menuBarMonitor

    var body: some View {
        Form {
            Section(settings.l10n.iconManagementTitle) {
                Text(settings.l10n.iconManagementCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                List(menuBarMonitor.menuBarItems) { item in
                    HStack {
                        AppIconView(icon: item.icon, size: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.processName)
                                .font(.body)
                            Text(item.bundleIdentifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        AppTypeBadge(type: item.appType, l10n: settings.l10n)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .frame(height: 280)
            }
        }
    }
}

struct IconOrderTab: View {
    @Binding var customOrder: [String]
    @Environment(MenuBarMonitor.self) private var menuBarMonitor
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        Form {
            IconOrderView(
                customOrder: $customOrder,
                menuBarItems: menuBarMonitor.menuBarItems,
                l10n: settings.l10n
            )
        }
    }
}
