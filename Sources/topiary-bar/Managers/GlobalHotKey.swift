import AppKit
import Carbon.HIToolbox

/// Global hotkey ⌃⌥M: summons the main window from anywhere.
///
/// Implemented with Carbon's `RegisterEventHotKey` — the only App-Store-safe
/// global hotkey mechanism: the system delivers the key event directly to our
/// own process, so no Accessibility permission is involved. The callback posts
/// `.openMainWindow`, which the AppDelegate already observes to summon the
/// window.
@MainActor
enum GlobalHotKey {
    private static let hotKeyID = EventHotKeyID(
        signature: OSType(0x544F5052), // 'TOPR'
        id: 1
    )

    static func install() {
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

        // The refs are kept registered for the process lifetime; we never
        // uninstall, so the returned refs are not retained.
        var handlerRef: EventHandlerRef?
        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            nil,
            &handlerRef
        )

        var hotKeyRef: EventHotKeyRef?
        RegisterEventHotKey(
            UInt32(kVK_ANSI_M),
            UInt32(controlKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        _ = handlerRef
        _ = hotKeyRef
    }
}
