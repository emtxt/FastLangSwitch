// Explicit UI/integration test only; excluded from the default SwiftPM test target.
import AppKit
import Carbon
import SwitchCore

@main
struct SecureInputMonitorProbe {
    @MainActor
    static func main() {
        guard !IsSecureEventInputEnabled() else {
            report("FAIL: secure input is already active; finish that session before testing")
            exit(2)
        }
        let application = NSApplication.shared
        application.setActivationPolicy(.prohibited)
        // A reserved key avoids intercepting ordinary typing in other apps.
        let key = SwitchKey(code: 127, name: "Unused test key")
        let monitor = KeyboardMonitor(key: key)
        var entered = false
        var completed = false
        monitor.onFailure = { message in report("FAIL: " + message); exit(2) }
        monitor.onSecureInputChange = { secure in
            report("Secure input: \(secure)")
            if secure { entered = true }
            if entered && !secure {
                completed = true
                monitor.stop()
                report("PASS: background monitor observed entry and exit without settings")
                CFRunLoopStop(CFRunLoopGetMain())
            }
        }
        guard monitor.start(key: key) else { exit(2) }
        report("Ready: click Start in the secure-input fixture within 30 seconds")
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if !completed {
                monitor.stop()
                report("FAIL: transition timeout")
                exit(1)
            }
        }
        CFRunLoopRun()
        monitor.stop()
        exit(completed ? 0 : 1)
    }

    private static func report(_ message: String) {
        FileHandle.standardOutput.write(Data((message + "\n").utf8))
    }
}
