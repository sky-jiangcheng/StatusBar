import AppKit
import SwiftUI

// MARK: - Brand

/// The product brand, single source of truth for every surface.
enum Brand {
    static let name = "Topiary"
}

// MARK: - Design tokens

/// Shared design tokens. The pre-redesign UI hardcoded radii, opacities and
/// per-type hues in every view, and the copies drifted apart over time; the
/// shared components below read from here so all five surfaces (main window,
/// popover, aggregation panel, settings, order) stay consistent.
enum Theme {
    /// Corner radii for containers. App icons carry their own squircle
    /// artwork (macOS 11+), so radii never clip icons.
    enum Radius {
        static let control: CGFloat = 8
        static let tile: CGFloat = 10
        static let card: CGFloat = 12
    }
}

// MARK: - App icon

/// Renders an app icon at a fixed size with identical treatment on every
/// surface. macOS icons ship pre-rounded, so no extra clipping; the
/// placeholder covers apps whose icon is not (yet) available.
struct AppIconView: View {
    let icon: NSImage?
    let size: CGFloat

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: size * 0.7))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - App type badge

/// Neutral type badge: the glyph carries the Status Bar / Dock distinction
/// and the color budget stays reserved for actions (blue = open, red = quit,
/// orange = force quit). Replaces the old purple/green per-type tinting.
struct AppTypeBadge: View {
    let type: MenuBarMonitor.AppType
    let l10n: L10nTable

    var body: some View {
        Label(
            type == .statusbarOnly ? l10n.statusBar : l10n.dock,
            systemImage: type == .statusbarOnly ? "menubar.rectangle" : "dock.rectangle"
        )
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Formatting

enum Format {
    /// Human-readable memory footprint, Lemon-style: "3.25 GB", "257 MB",
    /// "48.2 MB". GB keeps two decimals; MB keeps one below 100 for the
    /// small-app tail, none above.
    static func memory(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / (1024 * 1024 * 1024)
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        let mb = Double(bytes) / (1024 * 1024)
        if mb >= 100 { return String(format: "%.0f MB", mb) }
        return String(format: "%.1f MB", mb)
    }
}

// MARK: - Stat chip

/// Compact read-only summary chip for the overview state. Filtering is owned
/// by the sidebar's segmented picker, so chips are deliberately not buttons.
struct StatChip: View {
    let systemImage: String
    let title: String
    let value: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.6), in: Capsule())
    }
}
