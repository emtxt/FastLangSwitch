import Foundation

/// Physical key codes, independent of the active keyboard layout.
public struct SwitchKey: Codable, Equatable, Sendable {
    public let code: UInt16
    public let name: String

    public init(code: UInt16, name: String) {
        self.code = code
        self.name = name
    }

    public static let defaultKey = SwitchKey(code: 54, name: "Right Command")
    public static let presets: [SwitchKey] = [
        defaultKey, .init(code: 55, name: "Left Command"),
        .init(code: 61, name: "Right Option"), .init(code: 58, name: "Left Option"),
        .init(code: 62, name: "Right Control"), .init(code: 59, name: "Left Control"),
        .init(code: 60, name: "Right Shift"), .init(code: 56, name: "Left Shift"),
        .init(code: 63, name: "Fn / Globe"), .init(code: 49, name: "Space"),
        .init(code: 48, name: "Tab"), .init(code: 53, name: "Escape"),
        .init(code: 105, name: "F13"), .init(code: 107, name: "F14"),
        .init(code: 113, name: "F15")
    ]

    // NX_DEVICE* masks from IOKit's IOLLEvent.h. Side-specific flags distinguish
    // the release of one modifier while its opposite-side sibling is still held.
    public var deviceMask: UInt64? {
        switch code {
        case 54: return 0x10
        case 55: return 0x08
        case 56: return 0x02
        case 60: return 0x04
        case 58: return 0x20
        case 61: return 0x40
        case 59: return 0x01
        case 62: return 0x2000
        case 63: return 0x800000
        default: return nil
        }
    }

    public var aggregateMask: UInt64? {
        switch code {
        case 54, 55: return 0x100000
        case 56, 60: return 0x20000
        case 58, 61: return 0x80000
        case 59, 62: return 0x40000
        case 63: return 0x800000
        default: return nil
        }
    }

    public var isModifier: Bool { deviceMask != nil }

    private static let functionKeyCodes: Set<UInt16> = [
        64, 79, 80, 90, 96, 97, 98, 99, 100, 101, 103, 105, 106, 107, 109, 111,
        113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126
    ]

    public func hasOtherModifiers(flags: UInt64) -> Bool {
        // Caps Lock is a mode, not a held shortcut modifier.
        let aggregates: UInt64 = 0x20000 | 0x40000 | 0x80000 | 0x100000 | 0x800000
        let devices: UInt64 = 0x01 | 0x02 | 0x04 | 0x08 | 0x10 | 0x20 | 0x40 | 0x2000
        // macOS sets the Function flag on function/navigation keys even without
        // a physical Fn press. Actual held Fn is tracked separately by TapGesture.
        let ownAggregate = aggregateMask ?? (Self.functionKeyCodes.contains(code) ? 0x800000 : 0)
        return flags & ((aggregates & ~ownAggregate) | (devices & ~(deviceMask ?? 0))) != 0
    }
}
