struct MonitoringState {
    enum Status: String {
        case preview = "Preview"
        case disabled = "Disabled"
        case recording = "Recording"
        case inactiveSession = "Session inactive"
        case accessibilityRequired = "Accessibility required"
        case secureInput = "Secure input active"
        case waitingForKeyboard = "Waiting for keyboard"
        case running = "Running"

        var keepsEventTap: Bool {
            self == .running || self == .secureInput
        }
    }

    var sleeping = false
    var sessionActive = true

    func status(preview: Bool, enabled: Bool, recording: Bool,
                accessibilityGranted: Bool, secureInput: Bool, tapRunning: Bool) -> Status {
        if preview { return .preview }
        if !enabled { return .disabled }
        if recording { return .recording }
        if sleeping || !sessionActive { return .inactiveSession }
        if !accessibilityGranted { return .accessibilityRequired }
        if secureInput { return .secureInput }
        return tapRunning ? .running : .waitingForKeyboard
    }
}
