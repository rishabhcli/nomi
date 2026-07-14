import Foundation

/// Platform-neutral representation of the configured global shortcut. Carbon
/// key codes stay in the app target; config parsing remains deterministic and
/// testable in MnemoCore.
public struct HotkeyChord: Equatable, Sendable {
    public enum Modifier: String, Hashable, Sendable {
        case command, shift, option, control
    }

    public let modifiers: Set<Modifier>
    public let key: String

    public init(modifiers: Set<Modifier>, key: String) {
        self.modifiers = modifiers
        self.key = key
    }

    public static func parse(_ raw: String) -> HotkeyChord? {
        let parts = raw.lowercased()
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard parts.count >= 2 else { return nil }

        var modifiers = Set<Modifier>()
        var key: String?
        for part in parts {
            let modifier: Modifier?
            switch part {
            case "cmd", "command": modifier = .command
            case "shift": modifier = .shift
            case "opt", "option", "alt": modifier = .option
            case "ctrl", "control": modifier = .control
            default: modifier = nil
            }

            if let modifier {
                modifiers.insert(modifier)
            } else if key == nil, part == "space" || (part.count == 1 && part.first?.isASCII == true) {
                key = part
            } else {
                return nil
            }
        }

        guard !modifiers.isEmpty, let key else { return nil }
        return HotkeyChord(modifiers: modifiers, key: key)
    }
}
