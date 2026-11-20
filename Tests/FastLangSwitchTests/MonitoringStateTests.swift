import Testing
@testable import FastLangSwitch

struct MonitoringStateTests {
    private func status(
        _ state: MonitoringState = MonitoringState(), enabled: Bool = true, recording: Bool = false,
        trusted: Bool = true, secure: Bool = false, tapRunning: Bool = false, preview: Bool = false
    ) -> MonitoringState.Status {
        state.status(preview: preview, enabled: enabled, recording: recording,
                     accessibilityGranted: trusted, secureInput: secure, tapRunning: tapRunning)
    }

    @Test func permissionBecomingAvailableMakesTheTapEligibleForRetry() {
        #expect(status(trusted: false) == .accessibilityRequired)
        #expect(!status(trusted: false, tapRunning: true).keepsEventTap)
        #expect(status() == .waitingForKeyboard)
        #expect(status(tapRunning: true) == .running)
    }

    @Test func wakingDoesNotResumeAnInactiveSession() {
        var state = MonitoringState()
        state.sessionActive = false
        state.sleeping = true
        #expect(status(state) == .inactiveSession)
        state.sleeping = false
        #expect(status(state) == .inactiveSession)
        state.sessionActive = true
        #expect(status(state) == .waitingForKeyboard)
    }

    @Test func sessionActivationDoesNotResumeBeforeWake() {
        var state = MonitoringState(sleeping: true, sessionActive: false)
        state.sessionActive = true
        #expect(status(state) == .inactiveSession)
        state.sleeping = false
        #expect(status(state) == .waitingForKeyboard)
    }

    @Test func loginWithSecureInputDefersTapCreationUntilItEnds() {
        #expect(status(secure: true) == .secureInput)
        #expect(status(secure: true, tapRunning: true).keepsEventTap)
        #expect(status() == .waitingForKeyboard)
    }

    @Test func explicitPauseReasonsRemainVisible() {
        #expect(status(enabled: false, trusted: false) == .disabled)
        #expect(status(recording: true, tapRunning: true) == .recording)
        #expect(status(trusted: false, preview: true) == .preview)
    }
}
