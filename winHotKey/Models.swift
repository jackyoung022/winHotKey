import Foundation
import Carbon

struct WindowInfo: Identifiable, Hashable, Codable {
    let ownerName: String
    let ownerPID: pid_t
    let windowNumber: CGWindowID
    let title: String
    let bundleIdentifier: String?

    var id: String {
        "\(bundleIdentifier ?? ownerName)-\(windowNumber)"
    }

    var displayName: String {
        if title.isEmpty {
            return ownerName
        }
        return "\(ownerName) — \(title)"
    }
}

struct HotkeyBinding: Identifiable, Codable, Hashable {
    let id: UUID
    var hotKey: HotKeyDescriptor
    var window: WindowInfo
    var isEnabled: Bool

    init(id: UUID = UUID(), hotKey: HotKeyDescriptor, window: WindowInfo, isEnabled: Bool = true) {
        self.id = id
        self.hotKey = hotKey
        self.window = window
        self.isEnabled = isEnabled
    }
}

struct HotKeyDescriptor: Codable, Hashable {
    var keyCode: UInt32
    var modifiers: UInt32

    var readable: String {
        HotKeyDescriptor.describe(keyCode: keyCode, modifiers: modifiers)
    }

    static func describe(keyCode: UInt32, modifiers: UInt32) -> String {
        let symbols: [UInt32: String] = [
            UInt32(cmdKey): "⌘",
            UInt32(optionKey): "⌥",
            UInt32(controlKey): "⌃",
            UInt32(shiftKey): "⇧"
        ]
        var parts: [String] = []
        for (mask, symbol) in symbols.sorted(by: { $0.key < $1.key }) {
            if modifiers & mask != 0 {
                parts.append(symbol)
            }
        }
        if let keyString = KeycodeLookup.displayName(for: keyCode) {
            parts.append(keyString)
        } else {
            parts.append(String(format: "0x%02X", keyCode))
        }
        return parts.joined(separator: "")
    }
}

enum AccessibilityStatus {
    case authorized
    case denied
    case unknown
}

enum PermissionRequestResult {
    case granted
    case denied
    case requiresManual
}
