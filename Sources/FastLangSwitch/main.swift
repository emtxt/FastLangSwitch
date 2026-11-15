import AppKit
import Carbon
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var model: AppModel!
    private var window: NSWindow?
    private var reopenObserver: NotificationObservation?
    private let reopenNotification = Notification.Name("com.fastlangswitch.app.showSettings")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // LaunchServices normally handles this via applicationShouldHandleReopen.
        // This also covers direct launches of the executable in the app bundle.
        if let id = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            DistributedNotificationCenter.default().postNotificationName(reopenNotification, object: nil, userInfo: nil, deliverImmediately: true)
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        let preview = CommandLine.arguments.contains("--preview")
        model = AppModel(preview: preview)
        installMenu()
        reopenObserver = NotificationObservation(
            center: DistributedNotificationCenter.default(), name: reopenNotification
        ) { [weak self] in self?.showSettings() }

        let event = NSAppleEventManager.shared().currentAppleEvent
        let atLogin = event?.eventID == kAEOpenApplication &&
            event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if !atLogin && !CommandLine.arguments.contains("--background") { showSettings() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if model != nil { showSettings() }
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) { model?.stop() }

    func windowWillClose(_ notification: Notification) {
        model.recording = false
        // Recreate the hosting view next time so its permission timer only runs
        // while the settings window is open.
        window?.contentView = nil
        window = nil
        NSApp.hide(nil)
    }

    @objc private func showSettings() {
        model.refreshStatus()
        if window == nil {
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 790),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false
            )
            newWindow.title = "FastLangSwitch Settings"
            newWindow.isReleasedWhenClosed = false
            newWindow.delegate = self
            newWindow.contentView = NSHostingView(rootView: SettingsView(
                model: model, sources: model.inputSources, onDone: { [weak self] in self?.window?.close() }
            ))
            newWindow.minSize = NSSize(width: 560, height: 680)
            newWindow.center()
            window = newWindow
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func installMenu() {
        // An application menu is available only when settings has focus. No
        // NSStatusItem is created, and LSUIElement keeps the app out of the Dock.
        let menu = NSMenu()
        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit FastLangSwitch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        let editItem = NSMenuItem()
        menu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editItem.submenu = editMenu
        NSApp.mainMenu = menu
    }
}

let application = NSApplication.shared
if CommandLine.arguments.contains("--diagnostics") {
    let sources = InputSources()
    print("Accessibility: \(AXIsProcessTrusted() ? "granted" : "not granted")")
    print("Secure input: \(IsSecureEventInputEnabled() ? "active" : "inactive")")
    print("Selectable input sources: \(sources.sources.count)")
    for source in sources.sources {
        print("\(source.id == sources.selectedID ? "*" : " ") \(source.name) [\(source.id)]")
    }
    exit(0)
}
let delegate = AppDelegate()
application.delegate = delegate
application.run()
