import AppKit
import ApplicationServices
import Carbon
import SwitchCore

@MainActor
final class KeyboardMonitor {
    var onTap: (@MainActor () -> Void)?
    var onFailure: (@MainActor (String) -> Void)?
    var onSecureInputChange: (@MainActor (Bool) -> Void)?
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var session: InputSession
    private var secureInputTimer: Timer?
    private var key: SwitchKey
    private var bufferedDown: CGEvent?
    private let replayTag: Int64 = 0x464C535752
    var isRunning: Bool {
        guard let tap, CFMachPortIsValid(tap) else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    init(key: SwitchKey) {
        self.key = key
        session = InputSession(key: key)
    }

    @discardableResult
    func start(key: SwitchKey) -> Bool {
        stop()
        self.key = key
        session = InputSession(key: key)
        resetGesture()
        refreshSecureInput()
        let types: [CGEventType] = [
            .keyDown, .keyUp, .flagsChanged,
            .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp, .scrollWheel,
            .leftMouseDragged, .rightMouseDragged, .otherMouseDragged
        ]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                // This tap is installed exclusively on the main run loop.
                // Keep event handling synchronous to preserve replay ordering.
                var result: Unmanaged<CGEvent>?
                MainActor.assumeIsolated {
                    let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(context).takeUnretainedValue()
                    result = monitor.receive(proxy: proxy, type: type, event: event)
                }
                return result
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            onFailure?("macOS could not start the keyboard monitor. FastLangSwitch will retry automatically. Check Input Monitoring if macOS requests it.")
            return false
        }
        tap = newTap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        guard isRunning else {
            stop()
            onFailure?("macOS did not enable the keyboard monitor. FastLangSwitch will retry automatically.")
            return false
        }
        // This timer belongs to monitoring, not the settings view. It observes
        // secure-input transitions even when the tap receives no events.
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshSecureInput() }
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        secureInputTimer = timer
        return true
    }

    func stop() {
        secureInputTimer?.invalidate()
        secureInputTimer = nil
        refreshSecureInput()
        flushBufferedKey()
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
    }

    private func physicalState() -> (keys: Set<UInt16>, buttons: Set<Int>) {
        let pressed = Set((0..<128).compactMap { code -> UInt16? in
            // Caps Lock is a persistent mode, not a held shortcut key. Query
            // hardware state so suppressing a key does not change this snapshot.
            guard code != 57 else { return nil }
            return CGEventSource.keyState(.hidSystemState, key: CGKeyCode(code)) ? UInt16(code) : nil
        })
        let buttons = Set((0..<32).filter {
            CGEventSource.buttonState(.hidSystemState, button: CGMouseButton(rawValue: UInt32($0))!)
        })
        return (pressed, buttons)
    }

    private func resetGesture() {
        let state = physicalState()
        session.reset(pressedKeys: state.keys, pressedButtons: state.buttons)
    }

    private func refreshSecureInput(resumingEvent: TapGesture.Event? = nil) {
        let secure = IsSecureEventInputEnabled()
        guard secure != session.secureInput else { return }
        let state = physicalState()
        if session.updateSecureInput(secure, pressedKeys: state.keys, pressedButtons: state.buttons,
                                     resumingEvent: resumingEvent) {
            // A suppressed press from before secure input must not be replayed
            // into a password field or into the app that gains focus afterwards.
            bufferedDown = nil
            onSecureInputChange?(secure)
        }
    }

    private func receive(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            refreshSecureInput()
            flushBufferedKey()
            resetGesture()
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == replayTag {
            return Unmanaged.passUnretained(event)
        }

        let code = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.rawValue
        let input: TapGesture.Event
        switch type {
        case .keyDown:
            input = .keyDown(code, repeatEvent: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
                             otherModifiers: key.hasOtherModifiers(flags: flags))
        case .keyUp: input = .keyUp(code)
        case .flagsChanged:
            let modifier = SwitchKey(code: code, name: "")
            // Caps Lock is not a held modifier, but changing it cancels a tap.
            if let mask = modifier.deviceMask {
                input = .modifier(code, isDown: flags & mask != 0,
                                  otherModifiers: key.hasOtherModifiers(flags: flags))
            } else { input = .activity }
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            input = .pointerDown(Int(event.getIntegerValueField(.mouseEventButtonNumber)))
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            input = .pointerUp(Int(event.getIntegerValueField(.mouseEventButtonNumber)))
        default: input = .activity
        }

        // Detect the end of secure input before processing the first resumed
        // event, without waiting for the next background timer tick.
        refreshSecureInput(resumingEvent: input)
        let decision = session.handle(input)
        if decision.replayDown, let original = bufferedDown {
            // Post below this tap, before forwarding the chord's current event.
            // Reposting at the session head would recurse and can reorder events.
            original.tapPostEvent(proxy)
            bufferedDown = nil
        }
        if decision.suppress && type == .keyDown && bufferedDown == nil {
            bufferedDown = event.copy()
        }
        if type == .keyUp && code == key.code { bufferedDown = nil }
        if decision.switchLayout { onTap?() }
        return decision.suppress ? nil : Unmanaged.passUnretained(event)
    }

    /// Fail open when permissions, settings, or sleep interrupt a held key.
    private func flushBufferedKey() {
        guard let down = bufferedDown else { return }
        bufferedDown = nil
        down.setIntegerValueField(.eventSourceUserData, value: replayTag)
        down.post(tap: .cgSessionEventTap)
        if !CGEventSource.keyState(.hidSystemState, key: key.code), let up = down.copy() {
            up.type = .keyUp
            up.post(tap: .cgSessionEventTap)
        }
    }
}
