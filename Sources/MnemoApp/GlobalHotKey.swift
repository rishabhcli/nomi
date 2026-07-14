import Carbon
import MnemoCore

/// Registers a real system hotkey with the WindowServer. Unlike a global
/// NSEvent monitor, this does not depend on Input Monitoring permission and is
/// reliable while Mnemo is a background accessory app.
@MainActor
final class GlobalHotKey {
    private static let signature: OSType = 0x4D4E4D4F // MNMO

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let action: @MainActor () -> Void

    init?(chord: HotkeyChord, action: @escaping @MainActor () -> Void) {
        guard let keyCode = Self.keyCode(for: chord.key) else { return nil }
        self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard InstallEventHandler(
            GetApplicationEventTarget(),
            Self.handleEvent,
            1,
            &eventType,
            context,
            &eventHandlerRef
        ) == noErr else { return nil }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
        guard RegisterEventHotKey(
            keyCode,
            Self.carbonModifiers(chord.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        ) == noErr else {
            if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
            eventHandlerRef = nil
            return nil
        }
    }

    isolated deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
    }

    private func fire() { action() }

    private static let handleEvent: EventHandlerUPP = { _, _, context in
        guard let context else { return OSStatus(eventNotHandledErr) }
        let owner = Unmanaged<GlobalHotKey>.fromOpaque(context).takeUnretainedValue()
        Task { @MainActor in owner.fire() }
        return noErr
    }

    private static func carbonModifiers(_ modifiers: Set<HotkeyChord.Modifier>) -> UInt32 {
        var value: UInt32 = 0
        if modifiers.contains(.command) { value |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { value |= UInt32(shiftKey) }
        if modifiers.contains(.option) { value |= UInt32(optionKey) }
        if modifiers.contains(.control) { value |= UInt32(controlKey) }
        return value
    }

    private static func keyCode(for key: String) -> UInt32? {
        switch key {
        case "space": return UInt32(kVK_Space)
        case "a": return UInt32(kVK_ANSI_A)
        case "b": return UInt32(kVK_ANSI_B)
        case "c": return UInt32(kVK_ANSI_C)
        case "d": return UInt32(kVK_ANSI_D)
        case "e": return UInt32(kVK_ANSI_E)
        case "f": return UInt32(kVK_ANSI_F)
        case "g": return UInt32(kVK_ANSI_G)
        case "h": return UInt32(kVK_ANSI_H)
        case "i": return UInt32(kVK_ANSI_I)
        case "j": return UInt32(kVK_ANSI_J)
        case "k": return UInt32(kVK_ANSI_K)
        case "l": return UInt32(kVK_ANSI_L)
        case "m": return UInt32(kVK_ANSI_M)
        case "n": return UInt32(kVK_ANSI_N)
        case "o": return UInt32(kVK_ANSI_O)
        case "p": return UInt32(kVK_ANSI_P)
        case "q": return UInt32(kVK_ANSI_Q)
        case "r": return UInt32(kVK_ANSI_R)
        case "s": return UInt32(kVK_ANSI_S)
        case "t": return UInt32(kVK_ANSI_T)
        case "u": return UInt32(kVK_ANSI_U)
        case "v": return UInt32(kVK_ANSI_V)
        case "w": return UInt32(kVK_ANSI_W)
        case "x": return UInt32(kVK_ANSI_X)
        case "y": return UInt32(kVK_ANSI_Y)
        case "z": return UInt32(kVK_ANSI_Z)
        default: return nil
        }
    }
}
