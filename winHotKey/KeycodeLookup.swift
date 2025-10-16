import Carbon

enum KeycodeLookup {
    private static let keyMap: [UInt32: String] = [
        0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H", 0x05: "G",
        0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V", 0x0B: "B", 0x0C: "Q",
        0x0D: "W", 0x0E: "E", 0x0F: "R", 0x10: "Y", 0x11: "T", 0x12: "1",
        0x13: "2", 0x14: "3", 0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=",
        0x19: "9", 0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0", 0x1E: "]",
        0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I", 0x23: "P", 0x24: "Return",
        0x25: "L", 0x26: "J", 0x27: "'", 0x28: "K", 0x29: ";", 0x2A: "\\",
        0x2B: ",", 0x2C: "/", 0x2D: "N", 0x2E: "M", 0x2F: ".", 0x30: "Tab",
        0x31: "Space", 0x32: "`", 0x33: "Delete", 0x35: "Esc", 0x37: "⌘",
        0x38: "Shift", 0x39: "Caps", 0x3A: "Option", 0x3B: "Control", 0x3C: "Shift",
        0x3D: "Option", 0x3E: "Control", 0x3F: "Fn",
        0x40: "F17", 0x41: "Num .", 0x43: "Num *", 0x45: "Num +",
        0x47: "Num Clear", 0x4B: "Num /", 0x4C: "Num Enter", 0x4E: "Num -",
        0x4F: "F18", 0x50: "F19", 0x51: "Num =", 0x52: "Num 0", 0x53: "Num 1",
        0x54: "Num 2", 0x55: "Num 3", 0x56: "Num 4", 0x57: "Num 5",
        0x58: "Num 6", 0x59: "Num 7", 0x5A: "F20", 0x5B: "Num 8",
        0x5C: "Num 9", 0x5D: "Help", 0x60: "F5", 0x61: "F6",
        0x62: "F7", 0x63: "F3", 0x64: "F8", 0x65: "F9", 0x67: "F11",
        0x69: "F13", 0x6A: "F16", 0x6B: "F14", 0x6D: "F10", 0x6F: "F12",
        0x71: "F15", 0x72: "Help", 0x73: "Home", 0x74: "Page Up",
        0x75: "Delete", 0x76: "F4", 0x77: "End", 0x78: "F2",
        0x79: "Page Down", 0x7A: "F1", 0x7B: "←", 0x7C: "→", 0x7D: "↓",
        0x7E: "↑"
    ]

    private static let functionKeyMap: [UInt32: String] = [
        UInt32(kVK_F1): "F1",
        UInt32(kVK_F2): "F2",
        UInt32(kVK_F3): "F3",
        UInt32(kVK_F4): "F4",
        UInt32(kVK_F5): "F5",
        UInt32(kVK_F6): "F6",
        UInt32(kVK_F7): "F7",
        UInt32(kVK_F8): "F8",
        UInt32(kVK_F9): "F9",
        UInt32(kVK_F10): "F10",
        UInt32(kVK_F11): "F11",
        UInt32(kVK_F12): "F12",
        UInt32(kVK_F13): "F13",
        UInt32(kVK_F14): "F14",
        UInt32(kVK_F15): "F15",
        UInt32(kVK_F16): "F16",
        UInt32(kVK_F17): "F17",
        UInt32(kVK_F18): "F18",
        UInt32(kVK_F19): "F19",
        UInt32(kVK_F20): "F20"
    ]

    static func displayName(for keyCode: UInt32) -> String? {
        if let name = functionKeyMap[keyCode] {
            return name
        }
        return keyMap[keyCode]
    }
}
