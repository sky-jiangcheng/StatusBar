import AppKit

/// `NSApp.sendAction` is main-actor isolated, so the helper is too.
@MainActor
enum AppSettingsOpener {
    /// Opens the app's Settings scene. The app targets macOS 14+ only, where
    /// `showSettingsWindow:` is the SwiftUI `Settings` scene action.
    static func open() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
