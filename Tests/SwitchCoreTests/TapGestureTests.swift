import Testing
import SwitchCore

struct TapGestureTests {
    private let command = SwitchKey.defaultKey
    private let space = SwitchKey(code: 49, name: "Space")

    @Test
    func modifierTapSwitchesOnlyOnRelease() {
        var gesture = TapGesture(key: command)
        let down = gesture.handle(.modifier(54, isDown: true, otherModifiers: false))
        #expect(!down.suppress)
        #expect(!down.switchLayout)
        let up = gesture.handle(.modifier(54, isDown: false, otherModifiers: false))
        #expect(up.switchLayout)
        #expect(!up.suppress)
        #expect(!gesture.handle(.modifier(54, isDown: false, otherModifiers: false)).switchLayout)
    }

    @Test
    func commandShortcutDoesNotSwitchEvenWhenCommandReleasesFirst() {
        var gesture = TapGesture(key: command)
        _ = gesture.handle(.modifier(54, isDown: true, otherModifiers: false))
        let letter = gesture.handle(.keyDown(8, repeatEvent: false, otherModifiers: false))
        #expect(!letter.suppress)
        #expect(!letter.replayDown)
        #expect(!gesture.handle(.modifier(54, isDown: false, otherModifiers: false)).switchLayout)
        _ = gesture.handle(.keyUp(8))
        _ = gesture.handle(.modifier(54, isDown: true, otherModifiers: false))
        #expect(gesture.handle(.modifier(54, isDown: false, otherModifiers: false)).switchLayout)
    }

    @Test
    func anotherModifierCancelsTapInEitherOrder() {
        var gesture = TapGesture(key: command)
        _ = gesture.handle(.modifier(54, isDown: true, otherModifiers: false))
        _ = gesture.handle(.modifier(56, isDown: true, otherModifiers: true))
        _ = gesture.handle(.modifier(56, isDown: false, otherModifiers: false))
        #expect(!gesture.handle(.modifier(54, isDown: false, otherModifiers: false)).switchLayout)

        _ = gesture.handle(.modifier(56, isDown: true, otherModifiers: true))
        _ = gesture.handle(.modifier(54, isDown: true, otherModifiers: true))
        _ = gesture.handle(.modifier(56, isDown: false, otherModifiers: false))
        #expect(!gesture.handle(.modifier(54, isDown: false, otherModifiers: false)).switchLayout)
    }

    @Test
    func clickScrollAndDragCancelTap() {
        for activity: TapGesture.Event in [.pointerDown(0), .pointerDown(2), .activity] {
            var gesture = TapGesture(key: command)
            _ = gesture.handle(.modifier(54, isDown: true, otherModifiers: false))
            _ = gesture.handle(activity)
            #expect(!gesture.handle(.modifier(54, isDown: false, otherModifiers: false)).switchLayout)
        }
    }

    @Test
    func preexistingKeyOrMouseButtonDisqualifiesTap() {
        for gesture in [TapGesture(key: command, pressedKeys: [8]), TapGesture(key: command, pressedButtons: [0])] {
            var gesture = gesture
            _ = gesture.handle(.modifier(54, isDown: true, otherModifiers: false))
            _ = gesture.handle(.keyUp(8))
            _ = gesture.handle(.pointerUp(0))
            #expect(!gesture.handle(.modifier(54, isDown: false, otherModifiers: false)).switchLayout)
        }
    }

    @Test
    func startingWhileSwitchKeyHeldNeverSwitchesOnItsRelease() {
        var modifier = TapGesture(key: command, pressedKeys: [54])
        #expect(!modifier.handle(.modifier(54, isDown: false, otherModifiers: false)).switchLayout)
        var regular = TapGesture(key: space, pressedKeys: [49])
        #expect(!regular.handle(.keyDown(49, repeatEvent: true, otherModifiers: false)).suppress)
        #expect(!regular.handle(.keyUp(49)).switchLayout)
        _ = regular.handle(.keyDown(49, repeatEvent: false, otherModifiers: false))
        #expect(regular.handle(.keyUp(49)).switchLayout)
    }

    @Test
    func ordinaryKeyTapConsumesBothEdgesAndIgnoresRepeat() {
        var gesture = TapGesture(key: space)
        #expect(gesture.handle(.keyDown(49, repeatEvent: false, otherModifiers: false)).suppress)
        for _ in 0..<10 {
            let repeated = gesture.handle(.keyDown(49, repeatEvent: true, otherModifiers: false))
            #expect(repeated.suppress)
            #expect(!repeated.switchLayout)
        }
        let up = gesture.handle(.keyUp(49))
        #expect(up.suppress)
        #expect(up.switchLayout)
    }

    @Test
    func ordinaryKeyReplaysExactlyOnceBeforeChord() {
        var gesture = TapGesture(key: space)
        _ = gesture.handle(.keyDown(49, repeatEvent: false, otherModifiers: false))
        let chord = gesture.handle(.keyDown(8, repeatEvent: false, otherModifiers: false))
        #expect(chord.replayDown)
        #expect(!chord.suppress)
        #expect(!gesture.handle(.keyDown(8, repeatEvent: true, otherModifiers: false)).replayDown)
        let up = gesture.handle(.keyUp(49))
        #expect(!up.switchLayout)
        #expect(!up.suppress)
    }

    @Test
    func ordinaryKeyBeforeModifierReplaysInsteadOfSwitching() {
        var gesture = TapGesture(key: space)
        _ = gesture.handle(.keyDown(49, repeatEvent: false, otherModifiers: false))
        let modifier = gesture.handle(.modifier(55, isDown: true, otherModifiers: true))
        #expect(modifier.replayDown)
        #expect(!modifier.suppress)
        #expect(!gesture.handle(.keyUp(49)).switchLayout)
    }

    @Test
    func ordinaryKeyWithModifierAlreadyDownPassesThrough() {
        var gesture = TapGesture(key: space)
        #expect(!gesture.handle(.keyDown(49, repeatEvent: false, otherModifiers: true)).suppress)
        let up = gesture.handle(.keyUp(49))
        #expect(!up.suppress)
        #expect(!up.switchLayout)
    }

    @Test
    func ordinaryKeyReplayBeforeMouseActivity() {
        for activity: TapGesture.Event in [.pointerDown(0), .activity] {
            var gesture = TapGesture(key: space)
            _ = gesture.handle(.keyDown(49, repeatEvent: false, otherModifiers: false))
            #expect(gesture.handle(activity).replayDown)
            #expect(!gesture.handle(.keyUp(49)).switchLayout)
        }
    }

    @Test
    func rapidTapsEachSwitchExactlyOnce() {
        var gesture = TapGesture(key: command)
        for _ in 0..<100 {
            #expect(!gesture.handle(.modifier(54, isDown: true, otherModifiers: false)).switchLayout)
            #expect(gesture.handle(.modifier(54, isDown: false, otherModifiers: false)).switchLayout)
        }
    }

    @Test
    func sideSpecificModifierFlags() {
        #expect(!command.hasOtherModifiers(flags: 0x100010))
        #expect(!command.hasOtherModifiers(flags: 0x110010)) // Caps Lock doesn't disqualify a tap.
        #expect(command.hasOtherModifiers(flags: 0x100018)) // Both Command keys held.
        #expect(command.hasOtherModifiers(flags: 0x120012)) // Command + Shift.
        #expect(command.hasOtherModifiers(flags: 0x900010)) // Command + Fn.
        #expect(!space.hasOtherModifiers(flags: 0x10000))
        #expect(space.hasOtherModifiers(flags: 0x100010))
        let fn = SwitchKey(code: 63, name: "Fn")
        #expect(!fn.hasOtherModifiers(flags: 0x800000))
        #expect(fn.hasOtherModifiers(flags: 0x900010))
    }

    @Test
    func functionAndNavigationKeysAllowTheirIntrinsicFunctionFlag() {
        for code: UInt16 in [105, 107, 113, 123, 126, 115, 117] {
            let key = SwitchKey(code: code, name: "Function key")
            #expect(!key.hasOtherModifiers(flags: 0x800000))
            #expect(key.hasOtherModifiers(flags: 0x820002))
            var gesture = TapGesture(key: key)
            _ = gesture.handle(.keyDown(code, repeatEvent: false,
                                        otherModifiers: key.hasOtherModifiers(flags: 0x800000)))
            #expect(gesture.handle(.keyUp(code)).switchLayout)

            // Physical Fn is still a chord, even though its flag is intrinsic.
            var withFn = TapGesture(key: key, pressedKeys: [63])
            #expect(!withFn.handle(.keyDown(code, repeatEvent: false, otherModifiers: false)).suppress)
            #expect(!withFn.handle(.keyUp(code)).switchLayout)
        }
    }
}
