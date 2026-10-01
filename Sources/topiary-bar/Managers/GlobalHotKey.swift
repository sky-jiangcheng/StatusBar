import AppKit
import Carbon.HIToolbox

// MARK: - Hot key value

/// A user-configurable global hotkey: Carbon key code + modifier mask for
/// registration, plus a display glyph ("⌃⌥M") for the UI and menus.
struct HotKeyValue: Equatable, Codable {
    let keyCode: UInt32
    let modifiers: UInt32 // Carbon modifier mask (cmdKey/controlKey/…)
    let display: String

    /// ⌃⌥M — the default summon shortcut.
    static let mainWindow = HotKeyValue(
        keyCode: UInt32(kVK_ANSI_M),
        modifiers: UInt32(controlKey | optionKey),
        display: "⌃⌥M"
    )

    /// Carbon mask from NSEvent flags.
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        return carbon
    }

    static func displayGlyphs(_ modifiers: UInt32) -> String {
        var glyphs = ""
        if modifiers & UInt32(controlKey) != 0 { glyphs += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { glyphs += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { glyphs += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { glyphs += "⌘" }
        return glyphs
    }

    /// NSMenuItem display mapping for the current shortcut.
    var menuKeyEquivalent: String {
        display.last.map { String($0).lowercased() } ?? ""
    }

    var menuModifierMask: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if modifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if modifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        return flags
    }
}

// MARK: - Registration

/// Registers/unregisters the global hotkey that summons the main window.
/// Implemented with Carbon's `RegisterEventHotKey` — the only App-Store-safe
/// global hotkey mechanism: the system delivers the key event directly to our
/// own process, so no Accessibility permission is involved.
@MainActor
enum GlobalHotKey {
    enum ApplyResult {
        case success
        /// The combination is already taken by another app; the hotkey stays
        /// off until the user picks a free one.
        case conflict
    }

    private static var eventHandler: EventHandlerRef?
    private static var hotKeyRef: EventHotKeyRef?

    /// Swaps the active global hotkey. Unregisters the previous one first, so
    /// passing nil simply disables the hotkey.
    static func apply(_ hotKey: HotKeyValue?) -> ApplyResult {
        uninstall()

        guard let hotKey else { return .success }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, event, _ in
            guard let event else { return noErr }
            var id = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &id
            )
            if id.id == 1 {
                NotificationCenter.default.post(name: .openMainWindow, object: nil)
            }
            return noErr
        }

        var handlerRef: EventHandlerRef?
        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            nil,
            &handlerRef
        )

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            hotKey.keyCode,
            hotKey.modifiers,
            EventHotKeyID(signature: OSType(0x544F5052), id: 1), // 'TOPR'
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            eventHandler = nil
            return .conflict
        }

        eventHandler = handlerRef
        hotKeyRef = ref
        return .success
    }

    private static func uninstall() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        eventHandler = nil
        hotKeyRef = nil
    }
}
