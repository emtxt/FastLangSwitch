import AppKit
// The legacy SDK exposes the immutable kAXTrustedCheckOptionPrompt key as a C var.
@preconcurrency import ApplicationServices
import Carbon
import ServiceManagement
import SwitchCore

@MainActor
final class AppModel: ObservableObject {
    let inputSources = InputSources()
    @Published var key: SwitchKey {
        didSet {
            if let data = try? JSONEncoder().encode(key) { defaults.set(data, forKey: "switchKey") }
            refreshMonitoring(restart: key != oldValue)
        }
    }
    @Published var enabled: Bool {
        didSet {
            defaults.set(enabled, forKey: "enabled")
            refreshMonitoring()
        }
    }
    @Published var recording = false { didSet { refreshMonitoring() } }
    @Published private(set) var accessibilityGranted = false
    @Published private var tapRunning = false
    @Published private(set) var secureInput = false
    @Published private(set) var launchAtLogin = false
    @Published private(set) var loginNeedsApproval = false
    @Published var error: String?
    @Published private(set) var monitorError: String?
    private let defaults = UserDefaults.standard
    private let monitor: KeyboardMonitor
    private var systemObservers: [NotificationObservation] = []
    @Published private var monitoringState = MonitoringState()
    private var recoveryTimer: Timer?
    let preview: Bool

    var monitoringStatus: MonitoringState.Status {
        monitoringState.status(preview: preview, enabled: enabled, recording: recording,
                               accessibilityGranted: accessibilityGranted, secureInput: secureInput,
                               tapRunning: tapRunning)
    }

    init(preview: Bool = false) {
        self.preview = preview
        let storedKey = UserDefaults.standard.data(forKey: "switchKey")
            .flatMap { try? JSONDecoder().decode(SwitchKey.self, from: $0) }
        let initialKey = storedKey.flatMap { $0.code < 128 && $0.code != 57 ? $0 : nil } ?? .defaultKey
        key = initialKey
        enabled = UserDefaults.standard.object(forKey: "enabled") as? Bool ?? true
        monitor = KeyboardMonitor(key: initialKey)
        monitor.onTap = { [weak self] in self?.inputSources.selectNext() }
        monitor.onFailure = { [weak self] message in
            if self?.monitorError != message { self?.monitorError = message }
        }
        monitor.onSecureInputChange = { [weak self] secure in self?.secureInput = secure }
        let center = NSWorkspace.shared.notificationCenter
        systemObservers.append(NotificationObservation(center: center, name: NSWorkspace.willSleepNotification) { [weak self] in
            self?.monitoringState.sleeping = true
            self?.refreshMonitoring()
        })
        systemObservers.append(NotificationObservation(center: center, name: NSWorkspace.didWakeNotification) { [weak self] in
            self?.monitoringState.sleeping = false
            self?.refreshMonitoring()
        })
        systemObservers.append(NotificationObservation(center: center, name: NSWorkspace.sessionDidResignActiveNotification) { [weak self] in
            self?.monitoringState.sessionActive = false
            self?.refreshMonitoring()
        })
        systemObservers.append(NotificationObservation(center: center, name: NSWorkspace.sessionDidBecomeActiveNotification) { [weak self] in
            self?.monitoringState.sessionActive = true
            self?.refreshMonitoring()
        })
        refreshStatus()
    }

    func refreshStatus() {
        refreshMonitoring()
        let loginStatus = SMAppService.mainApp.status
        if launchAtLogin != (loginStatus == .enabled) { launchAtLogin = loginStatus == .enabled }
        if loginNeedsApproval != (loginStatus == .requiresApproval) {
            loginNeedsApproval = loginStatus == .requiresApproval
        }
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        refreshMonitoring()
    }

    func retry() {
        refreshMonitoring(restart: true)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            error = nil
        } catch {
            self.error = "Could not update Launch at Login: \(error.localizedDescription)"
        }
        refreshStatus()
    }

    func stop() {
        recoveryTimer?.invalidate()
        recoveryTimer = nil
        monitor.stop()
    }

    func openKeyboardSettings() {
        openSettings("x-apple.systempreferences:com.apple.Keyboard-Settings.extension")
    }

    private func openSettings(_ url: String) {
        if let url = URL(string: url) { NSWorkspace.shared.open(url) }
    }

    private func refreshMonitoring(restart: Bool = false) {
        let granted = AXIsProcessTrusted()
        if granted != accessibilityGranted { accessibilityGranted = granted }
        let secure = IsSecureEventInputEnabled()
        if secure != secureInput { secureInput = secure }

        let status = monitoringState.status(preview: preview, enabled: enabled, recording: recording,
                                            accessibilityGranted: granted, secureInput: secure,
                                            tapRunning: !restart && monitor.isRunning)
        var running = false
        if status == .waitingForKeyboard {
            running = monitor.start(key: key)
        } else if status.keepsEventTap && !restart && monitor.isRunning {
            running = true
        } else if tapRunning || restart {
            monitor.stop()
        }
        if monitorError != nil && (running || status != .waitingForKeyboard) { monitorError = nil }
        if running != tapRunning { tapRunning = running }
        inputSources.keepGlobal = running

        // Login and permission changes can happen with settings closed.
        if enabled && !preview && !monitoringState.sleeping && monitoringState.sessionActive {
            if recoveryTimer == nil {
                let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
                    MainActor.assumeIsolated { self?.refreshMonitoring() }
                }
                timer.tolerance = 0.25
                RunLoop.main.add(timer, forMode: .common)
                recoveryTimer = timer
            }
        } else {
            recoveryTimer?.invalidate()
            recoveryTimer = nil
        }
    }
}
