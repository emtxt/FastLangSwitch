/// Gesture state across periods when macOS hides keyboard events. Secure-input
/// detection and physical-state queries belong to the platform event monitor.
public struct InputSession {
    private var gesture: TapGesture
    public private(set) var secureInput = false

    public init(key: SwitchKey) {
        gesture = TapGesture(key: key)
    }

    public mutating func reset(pressedKeys: Set<UInt16>, pressedButtons: Set<Int>) {
        gesture = TapGesture(key: gesture.key, pressedKeys: pressedKeys, pressedButtons: pressedButtons)
    }

    /// Returns true when a transition cancels the previous gesture and its buffer.
    public mutating func updateSecureInput(
        _ enabled: Bool, pressedKeys: Set<UInt16>, pressedButtons: Set<Int>,
        resumingEvent: TapGesture.Event? = nil
    ) -> Bool {
        guard enabled != secureInput else { return false }
        secureInput = enabled
        var keys = pressedKeys
        var buttons = pressedButtons
        // A snapshot taken inside the callback already includes the current
        // press. Reconstruct its preceding state so the first fresh tap after
        // secure input can work, while other physically held inputs still block it.
        if !enabled, let resumingEvent {
            switch resumingEvent {
            case let .keyDown(code, repeatEvent, _):
                if !repeatEvent { keys.remove(code) }
            case let .modifier(code, isDown, _):
                if isDown { keys.remove(code) }
            case let .pointerDown(button): buttons.remove(button)
            default: break
            }
        }
        reset(pressedKeys: keys, pressedButtons: buttons)
        return true
    }

    public mutating func handle(_ event: TapGesture.Event) -> TapGesture.Decision {
        guard !secureInput else { return TapGesture.Decision() }
        return gesture.handle(event)
    }
}
