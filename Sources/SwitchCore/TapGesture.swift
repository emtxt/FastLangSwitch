/// A deterministic tap recognizer. It never waits for a timer or stores typed text.
/// Modifier events pass through unchanged. A non-modifier's first down is held
/// until release, or replayed before a chord's next event.
public struct TapGesture {
    public enum Event {
        case keyDown(UInt16, repeatEvent: Bool, otherModifiers: Bool)
        case keyUp(UInt16)
        case modifier(UInt16, isDown: Bool, otherModifiers: Bool)
        case pointerDown(Int)
        case pointerUp(Int)
        case activity
    }

    public struct Decision: Equatable {
        public var suppress = false
        public var replayDown = false
        public var switchLayout = false
        public init() {}
    }

    public let key: SwitchKey
    private var pressedKeys: Set<UInt16>
    private var pressedButtons: Set<Int>
    private var held = false
    private var candidate = false
    private var buffered = false

    public init(key: SwitchKey, pressedKeys: Set<UInt16> = [], pressedButtons: Set<Int> = []) {
        self.key = key
        self.pressedKeys = pressedKeys
        self.pressedButtons = pressedButtons
    }

    public mutating func handle(_ event: Event) -> Decision {
        var result = Decision()
        switch event {
        case let .keyDown(code, isRepeat, otherModifiers):
            if code == key.code && !key.isModifier {
                if held {
                    result.suppress = buffered
                } else if !isRepeat && !pressedKeys.contains(code) {
                    held = true
                    candidate = !otherModifiers && pressedKeys.isEmpty && pressedButtons.isEmpty
                    buffered = candidate
                    result.suppress = buffered
                }
            } else {
                cancel(&result)
            }
            pressedKeys.insert(code)

        case let .keyUp(code):
            if code == key.code && !key.isModifier && held {
                result.suppress = buffered
                result.switchLayout = candidate
                end()
            }
            pressedKeys.remove(code)

        case let .modifier(code, isDown, otherModifiers):
            if code == key.code && key.isModifier {
                if isDown && !held && !pressedKeys.contains(code) {
                    held = true
                    candidate = !otherModifiers && pressedKeys.isEmpty && pressedButtons.isEmpty
                } else if !isDown && held {
                    result.switchLayout = candidate && !otherModifiers
                    end()
                }
            } else {
                cancel(&result)
            }
            if isDown { pressedKeys.insert(code) } else { pressedKeys.remove(code) }

        case let .pointerDown(button):
            cancel(&result)
            pressedButtons.insert(button)
        case let .pointerUp(button):
            cancel(&result)
            pressedButtons.remove(button)
        case .activity:
            cancel(&result)
        }
        return result
    }

    private mutating func cancel(_ result: inout Decision) {
        candidate = false
        result.replayDown = buffered
        buffered = false
    }

    private mutating func end() {
        held = false
        candidate = false
        buffered = false
    }
}
