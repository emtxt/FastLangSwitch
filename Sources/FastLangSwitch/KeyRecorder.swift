import AppKit
import SwiftUI
import SwitchCore

struct KeyRecorder: NSViewRepresentable {
    let onKey: (SwitchKey) -> Void
    let onCancel: () -> Void
    let onError: (String) -> Void

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.onKey = onKey
        view.onCancel = onCancel
        view.onError = onError
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {}

    final class RecorderView: NSView {
        var onKey: ((SwitchKey) -> Void)?
        var onCancel: (() -> Void)?
        var onError: ((String) -> Void)?
        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            guard !event.isARepeat else { return }
            if event.keyCode == 53 { onCancel?(); return }
            let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
            guard modifiers.isEmpty else {
                onError?("Press one key on its own. Use a modifier preset to choose a modifier key.")
                return
            }
            let name = SwitchKey.presets.first(where: { $0.code == event.keyCode })?.name
                ?? specialName(event.keyCode)
                ?? event.charactersIgnoringModifiers?.uppercased()
                ?? "Key \(event.keyCode)"
            onKey?(SwitchKey(code: event.keyCode, name: name))
        }

        override func flagsChanged(with event: NSEvent) {
            guard event.keyCode != 57 else {
                onError?("Caps Lock is a system lock key. Choose a modifier, function key, or another ordinary key.")
                return
            }
            if let key = SwitchKey.presets.first(where: { $0.code == event.keyCode }),
               let mask = key.deviceMask, event.modifierFlags.rawValue & UInt(mask) != 0 {
                onKey?(key)
            }
        }

        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            keyDown(with: event)
            return true
        }

        private func specialName(_ code: UInt16) -> String? {
            let names: [UInt16: String] = [
                36: "Return", 51: "Delete", 76: "Keypad Enter", 117: "Forward Delete",
                123: "Left Arrow", 124: "Right Arrow", 125: "Down Arrow", 126: "Up Arrow",
                115: "Home", 119: "End", 116: "Page Up", 121: "Page Down",
                122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
                98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
                106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20", 114: "Help"
            ]
            return names[code]
        }
    }
}
