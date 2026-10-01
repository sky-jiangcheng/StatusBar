import SwiftUI

/// The settings pane embedded in the main window's "Settings" tab — one
/// grouped form replacing the former separate settings window with its four
/// tabs.
struct SettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(MenuBarMonitor.self) private var menuBarMonitor

    @State private var hotKeyConflict = false

    private var l10n: L10nTable { settings.l10n }

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section(l10n.sectionAppearance) {
                Picker("", selection: $settings.appearance) {
                    Text(l10n.appearanceSystem).tag(AppearanceMode.system)
                    Text(l10n.appearanceLight).tag(AppearanceMode.light)
                    Text(l10n.appearanceDark).tag(AppearanceMode.dark)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: settings.appearance) { _, _ in
                    settings.save()
                    settings.applyAppearance()
                }
            }

            Section(l10n.sectionLanguage) {
                Picker("", selection: $settings.language) {
                    Text(l10n.languageSystem).tag(AppLanguage.system)
                    Text(AppLanguage.en.nativeName).tag(AppLanguage.en)
                    Text(AppLanguage.zhHans.nativeName).tag(AppLanguage.zhHans)
                    Text(AppLanguage.ja.nativeName).tag(AppLanguage.ja)
                    Text(AppLanguage.de.nativeName).tag(AppLanguage.de)
                    Text(AppLanguage.es.nativeName).tag(AppLanguage.es)
                }
                .labelsHidden()
                .onChange(of: settings.language) { _, _ in
                    settings.save()
                }
            }

            Section(l10n.sectionDock) {
                Toggle(l10n.showDockIcon, isOn: $settings.showDockIcon)
                    .onChange(of: settings.showDockIcon) { _, _ in
                        settings.save()
                        NotificationCenter.default.post(name: .mainWindowVisibilityChanged, object: nil)
                    }
                Text(l10n.showDockIconCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(l10n.sectionRefresh) {
                HStack {
                    Text(l10n.scanInterval)
                    Spacer()
                    Picker("", selection: $settings.refreshInterval) {
                        Text("1s").tag(1.0)
                        Text("2s").tag(2.0)
                        Text("5s").tag(5.0)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 160)
                    .onChange(of: settings.refreshInterval) { _, _ in
                        settings.save()
                        NotificationCenter.default.post(name: .refreshIntervalChanged, object: nil)
                    }
                }
            }

            Section(l10n.hotKeyTitle) {
                HStack {
                    Text(l10n.hotKeyOpenMainWindow)
                    Spacer()
                    HotKeyRecorder(hotKey: $settings.mainWindowHotKey, l10n: l10n)
                        .frame(minWidth: 130, minHeight: 26)
                }
                if hotKeyConflict {
                    Text(l10n.hotKeyConflict)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section(l10n.sectionAggIcon) {
                Text(l10n.aggIconCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                AggregationIconSelector(selectedIcon: $settings.aggregationIcon, l10n: l10n)
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings.mainWindowHotKey) { _, newValue in
            // Swap the live registration; on conflict the hotkey stays off
            // until the user records a free combination.
            hotKeyConflict = (GlobalHotKey.apply(newValue) == .conflict)
        }
    }
}
