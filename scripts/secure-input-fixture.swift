// Run only for explicitly requested UI testing. See README.md.
import AppKit
import Carbon

@MainActor
final class SecureInputFixture: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private let status = NSTextField(wrappingLabelWithString: "Ready")
    private let input = NSTextField(string: "")
    private var ownsSecureInput = false
    private var testInProgress = false
    private var sawHiddenRelease = false
    private var keyObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 240),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Secure Input Test Fixture"
        window.isReleasedWhenClosed = false
        let instructions = NSTextField(wrappingLabelWithString:
            "Click Start, then immediately hold A for 0.9 seconds. Secure input begins after 0.5 seconds and ends after 2 seconds. Verify switching afterward with FastLangSwitch settings closed.")
        let start = NSButton(title: "Start secure-input test", target: self, action: #selector(startTest))
        let quit = NSButton(title: "Quit fixture", target: NSApp, action: #selector(NSApplication.terminate(_:)))
        let stack = NSStackView(views: [instructions, input, start, status, quit])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 20),
            input.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        keyObserver = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            if event.keyCode == 0, self?.ownsSecureInput == true { self?.sawHiddenRelease = true }
            return event
        }
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func startTest() {
        guard !testInProgress else { return }
        testInProgress = true
        sawHiddenRelease = false
        input.stringValue = ""
        window.makeFirstResponder(input)
        status.stringValue = "Armed: hold A now"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            let result = EnableSecureEventInput()
            self.ownsSecureInput = result == noErr
            self.status.stringValue = self.ownsSecureInput ? "Secure input active" : "Enable failed: \(result)"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self else { return }
            self.releaseSecureInput()
            self.testInProgress = false
            self.status.stringValue = "Completed; A released during secure input: \(self.sawHiddenRelease ? "yes" : "no")"
        }
    }

    private func releaseSecureInput() {
        if ownsSecureInput {
            DisableSecureEventInput()
            ownsSecureInput = false
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) {
        releaseSecureInput()
        if let keyObserver { NSEvent.removeMonitor(keyObserver) }
    }
}

let application = NSApplication.shared
let delegate = SecureInputFixture()
application.delegate = delegate
application.run()
