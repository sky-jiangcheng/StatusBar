import AppKit
import Observation

/// Read-only snapshot of the Accessibility (AX) trust state.
///
/// The app calls no AX APIs and never asks for the permission: every feature
/// works without it, so the flag is only rendered as a diagnostic label. That
/// keeps the privacy story honest — the app does not request a permission it
/// does not use (see docs/AppStoreChecklist.md).
@Observable
@MainActor
final class AccessibilityManager {
    var isAuthorized = false

    init() {
        refresh()
    }

    /// Re-reads the trust flag: at launch, whenever the app becomes active
    /// again (the user may have flipped the switch in System Settings and come
    /// back), and when the main window appears. Deliberately timer-free — a
    /// permanent poll would keep the CPU busy for a purely informational label.
    func refresh() {
        isAuthorized = AXIsProcessTrusted()
    }
}
