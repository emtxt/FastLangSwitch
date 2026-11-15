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
            configureMonitor()
        }
    }
    @Published var enabled: Bool {
        didSet {
            defaults.set(enabled, forKey: "enabled")
            configureMonitor()
        }
    }
    @Published var recording = false { didSet { configureMonitor() } }
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var running = false
    @Published private(set) var secureInput = false
    @Published private(set) var launchAtLogin = false
    @Published private(set) var loginNeedsApproval = false
    @Published var error: String?
    private let defaults = UserDefaults.standard
    private let monitor: KeyboardMonitor
    private var systemObservers: [NotificationObservation] = []
    private var sleeping = false
    let preview: Bool

    init(preview: Bool = false) {
        self.preview = preview
        let storedKey = UserDefaults.standard.data(forKey: "switchKey")
            .flatMap { try? JSONDecoder().decode(SwitchKey.self, from: $0) }
        let initialKey = storedKey.flatMap { $0.code < 128 && $0.code != 57 ? $0 : nil } ?? .defaultKey
        key = initialKey
        enabled = UserDefaults.standard.object(forKey: "enabled") as? Bool ?? true
        monitor = KeyboardMonitor(key: initialKey)
        monitor.onTap = { [weak self] in self?.inputSources.selectNext() }
        monitor.onFailure = { [weak self] message in self?.error = message }
        monitor.onSecureInputChange = { [weak self] secure in self?.secureInput = secure }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            systemObservers.append(NotificationObservation(center: center, name: name) { [weak self] in
                self?.sleeping = true
                self?.configureMonitor()
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            systemObservers.append(NotificationObservation(center: center, name: name) { [weak self] in
                self?.sleeping = false
                self?.configureMonitor()
            })
        }
        refreshStatus()
    }

    func refreshStatus() {
        let granted = AXIsProcessTrusted()
        let wasGranted = accessibilityGranted
        accessibilityGranted = granted
        secureInput = IsSecureEventInputEnabled()
        launchAtLogin = SMAppService.mainApp.status == .enabled
        loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
        if granted != wasGranted || (granted && enabled && !monitor.isRunning && !recording && !sleeping && !preview) {
            configureMonitor()
        }
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
        openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        configureMonitor()
    }

    func retry() {
        accessibilityGranted = AXIsProcessTrusted()
        configureMonitor()
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

    func stop() { monitor.stop() }

    func openKeyboardSettings() {
        openSettings("x-apple.systempreferences:com.apple.Keyboard-Settings.extension")
    }

    private func openSettings(_ url: String) {
        if let url = URL(string: url) { NSWorkspace.shared.open(url) }
    }

    private func configureMonitor() {
        inputSources.keepGlobal = false
        monitor.stop()
        running = false
        guard enabled, accessibilityGranted, !recording, !sleeping, !preview else { return }
        error = nil
        running = monitor.start(key: key)
        inputSources.keepGlobal = running
    }
}
