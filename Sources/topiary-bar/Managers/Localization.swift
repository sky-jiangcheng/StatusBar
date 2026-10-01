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
    var cancel: String
    // Detail info rows
    var infoType: String
    var infoPID: String
    var searchPlaceholder: String
    var settingsDots: String
    var quitAppTitle: String
    var openMainWindow: String
    var selectAppPrompt: String
    // Main window tabs
    var windowTabApps: String
    var windowTabSettings: String
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
    // Resident bar context menu
    var removeFromPanel: String
    // App detail pane
    var pinToMenuBar: String
    var unpinFromMenuBar: String
    var statusbarActivateHint: String
    // Menu bar occlusion (notch / overflow)
    var notchWarningTitle: String
    var notchWarningMainBody: String
    var notchWarningPinnedBody: String
    // Popover overview
    var memoryUsage: String
    var popoverClose: String
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
        cancel: "Cancel",
        infoType: "Type",
        infoPID: "PID",
        searchPlaceholder: "Search...",
        settingsDots: "Settings...",
        quitAppTitle: "Quit Topiary",
        openMainWindow: "Open Main Window",
        selectAppPrompt: "Select an app to see its details.",
        windowTabApps: "Apps",
        windowTabSettings: "Settings",
        sectionAppearance: "Appearance",
        appearanceSystem: "System",
        appearanceLight: "Light",
        appearanceDark: "Dark",
        sectionLanguage: "Language",
        languageSystem: "System",
        sectionRefresh: "Refresh",
        scanInterval: "Menu bar scan interval",
        sectionAggIcon: "Menu Bar Icon",
        aggIconCaption: "Choose the icon Topiary shows in the menu bar.",
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
        removeFromPanel: "Remove from panel",
        pinToMenuBar: "Pin to Menu Bar",
        unpinFromMenuBar: "Unpin from Menu Bar",
        statusbarActivateHint: "This app has no Dock icon. “Open” re-launches it to the front.",
        notchWarningTitle: "Menu Bar Space Is Full",
        notchWarningMainBody: "Topiary's menu bar icon is hidden behind the notch — the menu bar ran out of room. Quit or remove some menu bar apps to free space; the icon comes back automatically.",
        notchWarningPinnedBody: "%d pinned app icons are hidden behind the notch or an overcrowded menu bar. Quit or remove some menu bar apps to bring them back.",
        memoryUsage: "Memory Usage",
        popoverClose: "Close"
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
        cancel: "取消",
        infoType: "类型",
        infoPID: "PID",
        searchPlaceholder: "搜索…",
        settingsDots: "设置…",
        quitAppTitle: "退出 Topiary",
        openMainWindow: "打开主窗口",
        selectAppPrompt: "在左侧选择应用以查看详情。",
        windowTabApps: "应用",
        windowTabSettings: "设置",
        sectionAppearance: "外观",
        appearanceSystem: "跟随系统",
        appearanceLight: "浅色",
        appearanceDark: "深色",
        sectionLanguage: "语言",
        languageSystem: "跟随系统",
        sectionRefresh: "刷新",
        scanInterval: "菜单栏扫描间隔",
        sectionAggIcon: "菜单栏图标",
        aggIconCaption: "选择 Topiary 在菜单栏显示的图标。",
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
        removeFromPanel: "从面板移除",
        pinToMenuBar: "常驻菜单栏",
        unpinFromMenuBar: "取消常驻",
        statusbarActivateHint: "此应用没有程序坞图标，「打开」会重新唤起它的窗口。",
        notchWarningTitle: "菜单栏空间不足",
        notchWarningMainBody: "Topiary 的菜单栏图标被刘海遮挡（菜单栏已满）。退出或移除部分菜单栏应用腾出空间后，图标会自动恢复显示。",
        notchWarningPinnedBody: "有 %d 个常驻应用图标被刘海或拥挤的菜单栏遮挡。退出或移除部分菜单栏应用即可恢复显示。",
        memoryUsage: "内存占用",
        popoverClose: "关闭"
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
        cancel: "キャンセル",
        infoType: "種類",
        infoPID: "PID",
        searchPlaceholder: "検索…",
        settingsDots: "設定…",
        quitAppTitle: "Topiary を終了",
        openMainWindow: "メインウィンドウを開く",
        selectAppPrompt: "左のアプリを選択すると詳細が表示されます。",
        windowTabApps: "アプリ",
        windowTabSettings: "設定",
        sectionAppearance: "外観",
        appearanceSystem: "システムに従う",
        appearanceLight: "ライト",
        appearanceDark: "ダーク",
        sectionLanguage: "言語",
        languageSystem: "システムに従う",
        sectionRefresh: "更新",
        scanInterval: "メニューバーのスキャン間隔",
        sectionAggIcon: "メニューバーアイコン",
        aggIconCaption: "Topiary がメニューバーに表示するアイコンを選択します。",
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
        removeFromPanel: "パネルから削除",
        pinToMenuBar: "メニューバーに常駐",
        unpinFromMenuBar: "常駐を解除",
        statusbarActivateHint: "このアプリにはドックアイコンがありません。「開く」で前面に再表示します。",
        notchWarningTitle: "メニューバーに空きがありません",
        notchWarningMainBody: "メニューバーが満杯で、Topiary のアイコンがノッチの裏に隠れています。メニューバーアプリをいくつか終了すると、アイコンは自動的に戻ります。",
        notchWarningPinnedBody: "%d 個のピン留めアイコンがノッチや混雑したメニューバーに隠れています。メニューバーアプリを終了すると表示されます。",
        memoryUsage: "メモリ使用率",
        popoverClose: "閉じる"
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
        cancel: "Abbrechen",
        infoType: "Typ",
        infoPID: "PID",
        searchPlaceholder: "Suchen…",
        settingsDots: "Einstellungen…",
        quitAppTitle: "Topiary beenden",
        openMainWindow: "Hauptfenster öffnen",
        selectAppPrompt: "Wähle links eine App aus, um Details zu sehen.",
        windowTabApps: "Apps",
        windowTabSettings: "Einstellungen",
        sectionAppearance: "Erscheinungsbild",
        appearanceSystem: "System",
        appearanceLight: "Hell",
        appearanceDark: "Dunkel",
        sectionLanguage: "Sprache",
        languageSystem: "System",
        sectionRefresh: "Aktualisieren",
        scanInterval: "Scanintervall der Menüleiste",
        sectionAggIcon: "Menüleistensymbol",
        aggIconCaption: "Wählen Sie das Symbol, das Topiary in der Menüleiste zeigt.",
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
        removeFromPanel: "Aus dem Panel entfernen",
        pinToMenuBar: "In die Menüleiste pinnen",
        unpinFromMenuBar: "Nicht mehr pinnen",
        statusbarActivateHint: "Diese App hat kein Dock-Symbol. „Öffnen“ holt sie erneut nach vorn.",
        notchWarningTitle: "Menüleiste ist voll",
        notchWarningMainBody: "Das Topiary-Symbol wird vom Notch verdeckt — die Menüleiste ist voll. Beende oder entferne einige Menüleisten-Apps; das Symbol erscheint automatisch wieder.",
        notchWarningPinnedBody: "%d angepinnte Symbole sind hinter dem Notch bzw. einer überfüllten Menüleiste verborgen. Beende oder entferne einige Menüleisten-Apps, um sie wieder anzuzeigen.",
        memoryUsage: "Speichernutzung",
        popoverClose: "Schließen"
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
        cancel: "Cancelar",
        infoType: "Tipo",
        infoPID: "PID",
        searchPlaceholder: "Buscar…",
        settingsDots: "Ajustes…",
        quitAppTitle: "Salir de Topiary",
        openMainWindow: "Abrir ventana principal",
        selectAppPrompt: "Selecciona una app a la izquierda para ver los detalles.",
        windowTabApps: "Apps",
        windowTabSettings: "Ajustes",
        sectionAppearance: "Apariencia",
        appearanceSystem: "Sistema",
        appearanceLight: "Claro",
        appearanceDark: "Oscuro",
        sectionLanguage: "Idioma",
        languageSystem: "Sistema",
        sectionRefresh: "Actualización",
        scanInterval: "Intervalo de escaneo de la barra de menú",
        sectionAggIcon: "Icono de la barra de menús",
        aggIconCaption: "Elige el icono que Topiary muestra en la barra de menús.",
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
        removeFromPanel: "Quitar del panel",
        pinToMenuBar: "Fijar a la barra de menú",
        unpinFromMenuBar: "Dejar de fijar",
        statusbarActivateHint: "Esta app no tiene icono en el Dock. «Abrir» la trae de nuevo al frente.",
        notchWarningTitle: "La barra de menús está llena",
        notchWarningMainBody: "El icono de Topiary está oculto tras el notch: la barra de menús se quedó sin espacio. Sal o elimina algunas apps de la barra de menús; el icono volverá a aparecer.",
        notchWarningPinnedBody: "%d iconos fijados están ocultos tras el notch o en una barra de menús saturada. Sal o elimina algunas apps de la barra de menús para recuperarlos.",
        memoryUsage: "Uso de memoria",
        popoverClose: "Cerrar"
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
