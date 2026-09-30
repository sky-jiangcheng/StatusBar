import Foundation

// MARK: - User-selectable languages

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case en
    case zhHans = "zh-Hans"
    case ja
    case de
    case es

    var id: String { rawValue }

    /// Native name shown in the language picker (always written in its own language).
    var nativeName: String {
        switch self {
        case .system: return ""
        case .en: return "English"
        case .zhHans: return "简体中文"
        case .ja: return "日本語"
        case .de: return "Deutsch"
        case .es: return "Español"
        }
    }

    /// Maps the user's preferred system languages onto the supported set.
    static func resolveSystem() -> AppLanguage {
        for preferred in Locale.preferredLanguages {
            if preferred.hasPrefix("zh") { return .zhHans }
            if preferred.hasPrefix("ja") { return .ja }
            if preferred.hasPrefix("de") { return .de }
            if preferred.hasPrefix("es") { return .es }
            if preferred.hasPrefix("en") { return .en }
        }
        return .en
    }
}

// MARK: - Appearance

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
}

// MARK: - Translation table
//
// Code-level localization: the app is assembled into an .app bundle by script
// (no Xcode project), so .lproj / String Catalog plumbing would be fragile.
// A struct per language gives compile-time completeness: adding a field to
// L10nTable breaks every table literal until all five languages provide it.

struct L10nTable {
    // Common / menu bar
    var statusBar: String
    var dock: String
    var all: String
    var menuBarManager: String
    var appsCount: String
    var noApps: String
    var noAppsInCategory: String
    var noAppsFound: String
    var granted: String
    var accessibilityOptional: String
    var total: String
    var open: String
    var quit: String
    var forceQuit: String
    var forceQuitConfirmTitle: String
    var forceQuitConfirmBody: String
    var cancel: String
    var searchPlaceholder: String
    var settingsDots: String
    var quitStatusBar: String
    var showAggregationPanel: String
    var hideAggregationPanel: String
    var openMainWindow: String
    var selectAppPrompt: String
    // Settings — tabs & General
    var tabGeneral: String
    var tabAggregation: String
    var tabIcons: String
    var tabOrder: String
    var sectionAppearance: String
    var appearanceSystem: String
    var appearanceLight: String
    var appearanceDark: String
    var sectionLanguage: String
    var languageSystem: String
    var sectionRefresh: String
    var scanInterval: String
    // Settings — Aggregation
    var sectionAggIcon: String
    var aggIconCaption: String
    var sectionSpacing: String
    var spacingDefault: String
    var spacingCompact: String
    var spacingSmall: String
    var spacingNone: String
    var iconTypeDots: String
    var iconTypeGrid: String
    var iconTypeChevron: String
    var iconTypeSquare: String
    var iconTypeCircle: String
    var iconTypeTransparent: String
    // Settings — Icons & Order
    var iconManagementTitle: String
    var iconManagementCaption: String
    var iconOrderTitle: String
    var iconOrderCaption: String
    var sectionCustomOrder: String
    var sectionUnordered: String
    var noIcons: String
    var noIconsDetected: String
    // Aggregation panel
    var noStatusApps: String
    var noPinnedApps: String
    var noPinnedAppsCaption: String
    var addAppToPanel: String
    var removeFromPanel: String
    var noAppsToPin: String
    // App detail pane
    var pinToMenuBar: String
    var unpinFromMenuBar: String
    var statusbarActivateHint: String
}

enum L10n {
    static let en = L10nTable(
        statusBar: "Status Bar",
        dock: "Dock",
        all: "All",
        menuBarManager: "Menu Bar Manager",
        appsCount: "%d apps",
        noApps: "No Apps",
        noAppsInCategory: "No apps in this category.",
        noAppsFound: "No apps found.",
        granted: "Granted",
        accessibilityOptional: "Accessibility: off (optional)",
        total: "Total",
        open: "Open",
        quit: "Quit",
        forceQuit: "Force Quit",
        forceQuitConfirmTitle: "Force quit “%@”?",
        forceQuitConfirmBody: "The app will be terminated immediately. Unsaved changes may be lost.",
        cancel: "Cancel",
        searchPlaceholder: "Search...",
        settingsDots: "Settings...",
        quitStatusBar: "Quit StatusBar",
        showAggregationPanel: "Show Aggregation Panel",
        hideAggregationPanel: "Hide Aggregation Panel",
        openMainWindow: "Open Main Window",
        selectAppPrompt: "Select an app to see its details.",
        tabGeneral: "General",
        tabAggregation: "Aggregation",
        tabIcons: "Icons",
        tabOrder: "Order",
        sectionAppearance: "Appearance",
        appearanceSystem: "System",
        appearanceLight: "Light",
        appearanceDark: "Dark",
        sectionLanguage: "Language",
        languageSystem: "System",
        sectionRefresh: "Refresh",
        scanInterval: "Menu bar scan interval",
        sectionAggIcon: "Aggregation Icon",
        aggIconCaption: "Choose the icon displayed in the menu bar when aggregation mode is active.",
        sectionSpacing: "Icon Spacing",
        spacingDefault: "Default",
        spacingCompact: "Compact",
        spacingSmall: "Small",
        spacingNone: "None",
        iconTypeDots: "Three Dots",
        iconTypeGrid: "Grid",
        iconTypeChevron: "Chevron",
        iconTypeSquare: "Square",
        iconTypeCircle: "Circle",
        iconTypeTransparent: "Transparent",
        iconManagementTitle: "Menu Bar Icons",
        iconManagementCaption: "Detected apps and their type.",
        iconOrderTitle: "Icon Order",
        iconOrderCaption: "Drag to reorder icons. Icons not in the list will appear after custom-ordered icons.",
        sectionCustomOrder: "Custom Order",
        sectionUnordered: "Unordered",
        noIcons: "No Icons",
        noIconsDetected: "No menu bar icons detected.",
        noStatusApps: "No Status Bar apps running",
        noPinnedApps: "No apps pinned to the panel",
        noPinnedAppsCaption: "Click + in the title bar to pin apps here.",
        addAppToPanel: "Add app to panel",
        removeFromPanel: "Remove from panel",
        noAppsToPin: "No more apps to add",
        pinToMenuBar: "Pin to Menu Bar",
        unpinFromMenuBar: "Unpin from Menu Bar",
        statusbarActivateHint: "This app has no Dock icon. “Open” re-launches it to the front."
    )

    static let zhHans = L10nTable(
        statusBar: "菜单栏",
        dock: "程序坞",
        all: "全部",
        menuBarManager: "菜单栏管理器",
        appsCount: "%d 个应用",
        noApps: "无应用",
        noAppsInCategory: "此分类下没有应用。",
        noAppsFound: "未找到应用。",
        granted: "已授权",
        accessibilityOptional: "辅助功能：未开启（可选）",
        total: "总计",
        open: "打开",
        quit: "退出",
        forceQuit: "强制退出",
        forceQuitConfirmTitle: "强制退出“%@”？",
        forceQuitConfirmBody: "应用将被立即终止，未保存的更改可能丢失。",
        cancel: "取消",
        searchPlaceholder: "搜索…",
        settingsDots: "设置…",
        quitStatusBar: "退出 StatusBar",
        showAggregationPanel: "显示聚合面板",
        hideAggregationPanel: "隐藏聚合面板",
        openMainWindow: "打开主窗口",
        selectAppPrompt: "在左侧选择应用以查看详情。",
        tabGeneral: "通用",
        tabAggregation: "聚合",
        tabIcons: "图标",
        tabOrder: "排序",
        sectionAppearance: "外观",
        appearanceSystem: "跟随系统",
        appearanceLight: "浅色",
        appearanceDark: "深色",
        sectionLanguage: "语言",
        languageSystem: "跟随系统",
        sectionRefresh: "刷新",
        scanInterval: "菜单栏扫描间隔",
        sectionAggIcon: "聚合图标",
        aggIconCaption: "选择聚合模式下菜单栏显示的图标。",
        sectionSpacing: "图标间距",
        spacingDefault: "默认",
        spacingCompact: "紧凑",
        spacingSmall: "小",
        spacingNone: "无",
        iconTypeDots: "三个点",
        iconTypeGrid: "网格",
        iconTypeChevron: "箭头",
        iconTypeSquare: "方形",
        iconTypeCircle: "圆形",
        iconTypeTransparent: "透明",
        iconManagementTitle: "菜单栏图标",
        iconManagementCaption: "检测到的应用及其类型。",
        iconOrderTitle: "图标顺序",
        iconOrderCaption: "拖拽调整顺序。不在列表中的应用将排在自定义顺序之后。",
        sectionCustomOrder: "自定义顺序",
        sectionUnordered: "未排序",
        noIcons: "无图标",
        noIconsDetected: "未检测到菜单栏图标。",
        noStatusApps: "没有运行中的菜单栏应用",
        noPinnedApps: "尚未将应用固定到面板",
        noPinnedAppsCaption: "点击标题栏 + 可在此固定应用。",
        addAppToPanel: "添加应用到面板",
        removeFromPanel: "从面板移除",
        noAppsToPin: "没有更多可添加的应用",
        pinToMenuBar: "常驻菜单栏",
        unpinFromMenuBar: "取消常驻",
        statusbarActivateHint: "此应用没有程序坞图标，「打开」会重新唤起它的窗口。"
    )

    static let ja = L10nTable(
        statusBar: "ステータスバー",
        dock: "ドック",
        all: "すべて",
        menuBarManager: "メニューバーマネージャー",
        appsCount: "%d 個のアプリ",
        noApps: "アプリなし",
        noAppsInCategory: "このカテゴリにアプリはありません。",
        noAppsFound: "アプリが見つかりません。",
        granted: "許可済み",
        accessibilityOptional: "アクセシビリティ：オフ（任意）",
        total: "合計",
        open: "開く",
        quit: "終了",
        forceQuit: "強制終了",
        forceQuitConfirmTitle: "「%@」を強制終了しますか？",
        forceQuitConfirmBody: "アプリは直ちに終了します。未保存の変更は失われる可能性があります。",
        cancel: "キャンセル",
        searchPlaceholder: "検索…",
        settingsDots: "設定…",
        quitStatusBar: "StatusBar を終了",
        showAggregationPanel: "集約パネルを表示",
        hideAggregationPanel: "集約パネルを隠す",
        openMainWindow: "メインウィンドウを開く",
        selectAppPrompt: "左のアプリを選択すると詳細が表示されます。",
        tabGeneral: "一般",
        tabAggregation: "集約",
        tabIcons: "アイコン",
        tabOrder: "順序",
        sectionAppearance: "外観",
        appearanceSystem: "システムに従う",
        appearanceLight: "ライト",
        appearanceDark: "ダーク",
        sectionLanguage: "言語",
        languageSystem: "システムに従う",
        sectionRefresh: "更新",
        scanInterval: "メニューバーのスキャン間隔",
        sectionAggIcon: "集約アイコン",
        aggIconCaption: "集約モードでメニューバーに表示するアイコンを選択します。",
        sectionSpacing: "アイコンの間隔",
        spacingDefault: "デフォルト",
        spacingCompact: "コンパクト",
        spacingSmall: "小",
        spacingNone: "なし",
        iconTypeDots: "3 つのドット",
        iconTypeGrid: "グリッド",
        iconTypeChevron: "シェブロン",
        iconTypeSquare: "四角",
        iconTypeCircle: "円",
        iconTypeTransparent: "透明",
        iconManagementTitle: "メニューバーのアイコン",
        iconManagementCaption: "検出されたアプリとその種類。",
        iconOrderTitle: "アイコンの順序",
        iconOrderCaption: "ドラッグして並べ替えます。リストにないアイコンはカスタム順序の後に表示されます。",
        sectionCustomOrder: "カスタム順序",
        sectionUnordered: "未整列",
        noIcons: "アイコンなし",
        noIconsDetected: "メニューバーのアイコンが検出されません。",
        noStatusApps: "実行中のステータスバーアプリはありません",
        noPinnedApps: "パネルに固定されたアプリはありません",
        noPinnedAppsCaption: "タイトルバーの + をクリックして、ここにアプリを固定します。",
        addAppToPanel: "パネルにアプリを追加",
        removeFromPanel: "パネルから削除",
        noAppsToPin: "追加できるアプリはありません",
        pinToMenuBar: "メニューバーに常駐",
        unpinFromMenuBar: "常駐を解除",
        statusbarActivateHint: "このアプリにはドックアイコンがありません。「開く」で前面に再表示します。"
    )

    static let de = L10nTable(
        statusBar: "Statusleiste",
        dock: "Dock",
        all: "Alle",
        menuBarManager: "Menüleisten-Manager",
        appsCount: "%d Apps",
        noApps: "Keine Apps",
        noAppsInCategory: "Keine Apps in dieser Kategorie.",
        noAppsFound: "Keine Apps gefunden.",
        granted: "Erteilt",
        accessibilityOptional: "Bedienungshilfen: aus (optional)",
        total: "Gesamt",
        open: "Öffnen",
        quit: "Beenden",
        forceQuit: "Beenden erzwingen",
        forceQuitConfirmTitle: "„%@“ sofort beenden?",
        forceQuitConfirmBody: "Die App wird sofort beendet. Ungespeicherte Änderungen können verloren gehen.",
        cancel: "Abbrechen",
        searchPlaceholder: "Suchen…",
        settingsDots: "Einstellungen…",
        quitStatusBar: "StatusBar beenden",
        showAggregationPanel: "Aggregations-Panel anzeigen",
        hideAggregationPanel: "Aggregations-Panel ausblenden",
        openMainWindow: "Hauptfenster öffnen",
        selectAppPrompt: "Wähle links eine App aus, um Details zu sehen.",
        tabGeneral: "Allgemein",
        tabAggregation: "Aggregation",
        tabIcons: "Symbole",
        tabOrder: "Reihenfolge",
        sectionAppearance: "Erscheinungsbild",
        appearanceSystem: "System",
        appearanceLight: "Hell",
        appearanceDark: "Dunkel",
        sectionLanguage: "Sprache",
        languageSystem: "System",
        sectionRefresh: "Aktualisieren",
        scanInterval: "Scanintervall der Menüleiste",
        sectionAggIcon: "Aggregationssymbol",
        aggIconCaption: "Wählen Sie das Symbol, das im Aggregationsmodus in der Menüleiste angezeigt wird.",
        sectionSpacing: "Symbolabstand",
        spacingDefault: "Standard",
        spacingCompact: "Kompakt",
        spacingSmall: "Klein",
        spacingNone: "Keine",
        iconTypeDots: "Drei Punkte",
        iconTypeGrid: "Raster",
        iconTypeChevron: "Chevron",
        iconTypeSquare: "Quadrat",
        iconTypeCircle: "Kreis",
        iconTypeTransparent: "Transparent",
        iconManagementTitle: "Menüleisten-Symbole",
        iconManagementCaption: "Erkannte Apps und ihr Typ.",
        iconOrderTitle: "Symbolreihenfolge",
        iconOrderCaption: "Ziehen Sie Symbole zum Neuanordnen. Symbole außerhalb der Liste erscheinen hinter den sortierten.",
        sectionCustomOrder: "Eigene Reihenfolge",
        sectionUnordered: "Nicht sortiert",
        noIcons: "Keine Symbole",
        noIconsDetected: "Keine Menüleisten-Symbole erkannt.",
        noStatusApps: "Keine Statusleisten-Apps aktiv",
        noPinnedApps: "Keine Apps aus dem Panel angeheftet",
        noPinnedAppsCaption: "Klicken Sie im Titel auf +, um hier Apps anzupinnen.",
        addAppToPanel: "App zum Panel hinzufügen",
        removeFromPanel: "Aus dem Panel entfernen",
        noAppsToPin: "Keine weiteren Apps zum Hinzufügen",
        pinToMenuBar: "In die Menüleiste pinnen",
        unpinFromMenuBar: "Nicht mehr pinnen",
        statusbarActivateHint: "Diese App hat kein Dock-Symbol. „Öffnen“ holt sie erneut nach vorn."
    )

    static let es = L10nTable(
        statusBar: "Barra de estado",
        dock: "Dock",
        all: "Todos",
        menuBarManager: "Gestor de la barra de menú",
        appsCount: "%d aplicaciones",
        noApps: "Sin aplicaciones",
        noAppsInCategory: "No hay aplicaciones en esta categoría.",
        noAppsFound: "No se encontraron aplicaciones.",
        granted: "Concedido",
        accessibilityOptional: "Accesibilidad: desactivada (opcional)",
        total: "Total",
        open: "Abrir",
        quit: "Salir",
        forceQuit: "Forzar salida",
        forceQuitConfirmTitle: "¿Forzar la salida de “%@”?",
        forceQuitConfirmBody: "La aplicación se cerrará de inmediato. Los cambios sin guardar pueden perderse.",
        cancel: "Cancelar",
        searchPlaceholder: "Buscar…",
        settingsDots: "Ajustes…",
        quitStatusBar: "Salir de StatusBar",
        showAggregationPanel: "Mostrar panel de agregación",
        hideAggregationPanel: "Ocultar panel de agregación",
        openMainWindow: "Abrir ventana principal",
        selectAppPrompt: "Selecciona una app a la izquierda para ver los detalles.",
        tabGeneral: "General",
        tabAggregation: "Agregación",
        tabIcons: "Iconos",
        tabOrder: "Orden",
        sectionAppearance: "Apariencia",
        appearanceSystem: "Sistema",
        appearanceLight: "Claro",
        appearanceDark: "Oscuro",
        sectionLanguage: "Idioma",
        languageSystem: "Sistema",
        sectionRefresh: "Actualización",
        scanInterval: "Intervalo de escaneo de la barra de menú",
        sectionAggIcon: "Icono de agregación",
        aggIconCaption: "Elige el icono que se muestra en la barra de menú cuando el modo de agregación está activo.",
        sectionSpacing: "Espaciado de iconos",
        spacingDefault: "Predeterminado",
        spacingCompact: "Compacto",
        spacingSmall: "Pequeño",
        spacingNone: "Ninguno",
        iconTypeDots: "Tres puntos",
        iconTypeGrid: "Cuadrícula",
        iconTypeChevron: "Cheurón",
        iconTypeSquare: "Cuadrado",
        iconTypeCircle: "Círculo",
        iconTypeTransparent: "Transparente",
        iconManagementTitle: "Iconos de la barra de menú",
        iconManagementCaption: "Aplicaciones detectadas y su tipo.",
        iconOrderTitle: "Orden de iconos",
        iconOrderCaption: "Arrastra para reordenar. Los iconos que no estén en la lista aparecerán después de los ordenados.",
        sectionCustomOrder: "Orden personalizado",
        sectionUnordered: "Sin ordenar",
        noIcons: "Sin iconos",
        noIconsDetected: "No se detectaron iconos de la barra de menú.",
        noStatusApps: "No hay aplicaciones de barra de estado en ejecución",
        noPinnedApps: "No hay apps fijadas al panel",
        noPinnedAppsCaption: "Haz clic en + de la barra de título para fijar apps aquí.",
        addAppToPanel: "Añadir app al panel",
        removeFromPanel: "Quitar del panel",
        noAppsToPin: "No hay más apps para añadir",
        pinToMenuBar: "Fijar a la barra de menú",
        unpinFromMenuBar: "Dejar de fijar",
        statusbarActivateHint: "Esta app no tiene icono en el Dock. «Abrir» la trae de nuevo al frente."
    )

    // Memoized: Locale.preferredLanguages is stable within a launch session,
    // and this lookup runs on every view render via SettingsStore.l10n.
    private static let resolvedSystem: AppLanguage = AppLanguage.resolveSystem()

    static func table(for language: AppLanguage) -> L10nTable {
        switch language {
        case .system: return table(for: resolvedSystem)
        case .en: return en
        case .zhHans: return zhHans
        case .ja: return ja
        case .de: return de
        case .es: return es
        }
    }
}
