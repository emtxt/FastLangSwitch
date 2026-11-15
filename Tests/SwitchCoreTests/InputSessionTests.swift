import Testing
import SwitchCore

struct InputSessionTests {
    private let command = SwitchKey.defaultKey
    private let space = SwitchKey(code: 49, name: "Space")

    @Test
    func hiddenKeyReleaseDoesNotBlockLaterTaps() {
        var session = InputSession(key: command)
        _ = session.handle(.keyDown(8, repeatEvent: false, otherModifiers: false))
        let enteredSecureInput = session.updateSecureInput(true, pressedKeys: [8], pressedButtons: [])
        #expect(enteredSecureInput)
        // The key is released while macOS hides events; no keyUp is delivered.
        let leftSecureInput = session.updateSecureInput(false, pressedKeys: [], pressedButtons: [])
        #expect(leftSecureInput)
        _ = session.handle(.modifier(54, isDown: true, otherModifiers: false))
        #expect(session.handle(.modifier(54, isDown: false, otherModifiers: false)).switchLayout)
    }

    @Test
    func interruptedModifierTapCannotSwitchOnRelease() {
        var session = InputSession(key: command)
        _ = session.handle(.modifier(54, isDown: true, otherModifiers: false))
        _ = session.updateSecureInput(true, pressedKeys: [54], pressedButtons: [])
        _ = session.updateSecureInput(false, pressedKeys: [54], pressedButtons: [])
        #expect(!session.handle(.modifier(54, isDown: false, otherModifiers: false)).switchLayout)
        _ = session.handle(.modifier(54, isDown: true, otherModifiers: false))
        #expect(session.handle(.modifier(54, isDown: false, otherModifiers: false)).switchLayout)
    }

    @Test
    func interruptedOrdinaryTapDoesNotReplayOrConsumeLaterInput() {
        var session = InputSession(key: space)
        #expect(session.handle(.keyDown(49, repeatEvent: false, otherModifiers: false)).suppress)
        let canceledBuffer = session.updateSecureInput(true, pressedKeys: [49], pressedButtons: [])
        #expect(canceledBuffer)
        _ = session.updateSecureInput(false, pressedKeys: [], pressedButtons: [])
        let next = session.handle(.keyDown(8, repeatEvent: false, otherModifiers: false))
        #expect(!next.replayDown)
        #expect(!next.suppress)
        let oldRelease = session.handle(.keyUp(49))
        #expect(!oldRelease.switchLayout)
        #expect(!oldRelease.suppress)
        _ = session.handle(.keyUp(8))
        _ = session.handle(.keyDown(49, repeatEvent: false, otherModifiers: false))
        #expect(session.handle(.keyUp(49)).switchLayout)
    }

    @Test
    func inputDuringSecureEntryPassesThroughWithoutSwitching() {
        var session = InputSession(key: space)
        _ = session.updateSecureInput(true, pressedKeys: [], pressedButtons: [])
        for event: TapGesture.Event in [
            .keyDown(49, repeatEvent: false, otherModifiers: false), .keyUp(49),
            .keyDown(8, repeatEvent: false, otherModifiers: false), .keyUp(8)
        ] {
            #expect(session.handle(event) == TapGesture.Decision())
        }
        _ = session.updateSecureInput(false, pressedKeys: [], pressedButtons: [])
        _ = session.handle(.keyDown(49, repeatEvent: false, otherModifiers: false))
        #expect(session.handle(.keyUp(49)).switchLayout)
    }

    @Test
    func keysPressedDuringSecureEntryStillDisqualifyChordsAfterResuming() {
        var session = InputSession(key: command)
        _ = session.updateSecureInput(true, pressedKeys: [], pressedButtons: [])
        _ = session.updateSecureInput(false, pressedKeys: [8], pressedButtons: [])
        _ = session.handle(.modifier(54, isDown: true, otherModifiers: false))
        #expect(!session.handle(.modifier(54, isDown: false, otherModifiers: false)).switchLayout)
        _ = session.handle(.keyUp(8))
        _ = session.handle(.modifier(54, isDown: true, otherModifiers: false))
        #expect(session.handle(.modifier(54, isDown: false, otherModifiers: false)).switchLayout)
    }

    @Test
    func mouseStateIsReseededAfterSecureEntry() {
        for heldButtons: Set<Int> in [[], [0]] {
            var session = InputSession(key: command)
            _ = session.handle(.pointerDown(0))
            _ = session.updateSecureInput(true, pressedKeys: [], pressedButtons: [0])
            _ = session.updateSecureInput(false, pressedKeys: [], pressedButtons: heldButtons)
            _ = session.handle(.modifier(54, isDown: true, otherModifiers: false))
            #expect(session.handle(.modifier(54, isDown: false, otherModifiers: false)).switchLayout == heldButtons.isEmpty)
        }
    }

    @Test
    func firstResumedModifierPressCanSwitchWithoutWaitingForPolling() {
        var session = InputSession(key: command)
        _ = session.updateSecureInput(true, pressedKeys: [], pressedButtons: [])
        let down = TapGesture.Event.modifier(54, isDown: true, otherModifiers: false)
        _ = session.updateSecureInput(false, pressedKeys: [54], pressedButtons: [], resumingEvent: down)
        _ = session.handle(down)
        #expect(session.handle(.modifier(54, isDown: false, otherModifiers: false)).switchLayout)
    }

    @Test
    func firstResumedOrdinaryPressCanSwitchWithoutWaitingForPolling() {
        var session = InputSession(key: space)
        _ = session.updateSecureInput(true, pressedKeys: [], pressedButtons: [])
        let down = TapGesture.Event.keyDown(49, repeatEvent: false, otherModifiers: false)
        _ = session.updateSecureInput(false, pressedKeys: [49], pressedButtons: [], resumingEvent: down)
        #expect(session.handle(down).suppress)
        #expect(session.handle(.keyUp(49)).switchLayout)
    }

    @Test
    func firstResumedRepeatOrReleaseCannotBecomeASoloTap() {
        for event: TapGesture.Event in [
            .keyDown(49, repeatEvent: true, otherModifiers: false), .keyUp(49)
        ] {
            var session = InputSession(key: space)
            _ = session.updateSecureInput(true, pressedKeys: [], pressedButtons: [])
            _ = session.updateSecureInput(false, pressedKeys: [49], pressedButtons: [], resumingEvent: event)
            #expect(session.handle(event) == TapGesture.Decision())
            #expect(!session.handle(.keyUp(49)).switchLayout)
        }
    }

    @Test
    func pollingWithoutATransitionDoesNotCancelAnOrdinaryTap() {
        var session = InputSession(key: space)
        _ = session.handle(.keyDown(49, repeatEvent: false, otherModifiers: false))
        let changed = session.updateSecureInput(false, pressedKeys: [49], pressedButtons: [])
        #expect(!changed)
        #expect(session.handle(.keyUp(49)).switchLayout)
    }
}
