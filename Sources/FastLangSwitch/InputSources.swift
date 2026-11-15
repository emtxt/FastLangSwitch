import AppKit
import Carbon

struct InputSource: Identifiable {
    let id: String
    let name: String
    let reference: TISInputSource
}

@MainActor
final class InputSources: ObservableObject {
    @Published private(set) var sources: [InputSource] = []
    @Published private(set) var selectedID = ""
    @Published private(set) var error: String?
    private var globalID = ""
    private var restoring = false
    private var observers: [NotificationObservation] = []
    var keepGlobal = false

    init() {
        reload()
        selectedID = currentID()
        globalID = selectedID
        let center = DistributedNotificationCenter.default()
        observers.append(NotificationObservation(
            center: center, name: Notification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String)
        ) { [weak self] in self?.reload() })
        observers.append(NotificationObservation(
            center: center, name: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String)
        ) { [weak self] in self?.selectionChanged() })
        observers.append(NotificationObservation(
            center: NSWorkspace.shared.notificationCenter, name: NSWorkspace.didActivateApplicationNotification
        ) { [weak self] in self?.restoreGlobalSource() })
    }

    func reload() {
        let filter: [String: Any] = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource!,
            kTISPropertyInputSourceIsEnabled as String: true,
            kTISPropertyInputSourceIsSelectCapable as String: true
        ]
        let list = TISCreateInputSourceList(filter as CFDictionary, false).takeRetainedValue() as NSArray
        sources = (list as? [TISInputSource] ?? []).compactMap { source in
            guard let id: String = property(source, kTISPropertyInputSourceID),
                  let name: String = property(source, kTISPropertyLocalizedName) else { return nil }
            return InputSource(id: id, name: name, reference: source)
        }
        if !sources.contains(where: { $0.id == globalID }) { globalID = currentID() }
        selectionChanged()
    }

    /// Synchronous selection on the event tap's main run loop. No synthetic
    /// system shortcut, input-source HUD, debounce, or background dispatch.
    func selectNext() {
        guard sources.count > 1 else {
            error = "Add at least two input sources in System Settings → Keyboard → Text Input."
            return
        }
        let current = currentID()
        let next = sources.firstIndex(where: { $0.id == current }).map { ($0 + 1) % sources.count } ?? 0
        select(sources[next])
    }

    func select(_ source: InputSource) {
        let status = TISSelectInputSource(source.reference)
        guard status == noErr else {
            error = "macOS could not select \(source.name) (error \(status))."
            return
        }
        error = nil
        globalID = source.id
        selectedID = currentID()
    }

    private func selectionChanged() {
        selectedID = currentID()
        // Explicit selections from the native Input menu become the global choice.
        if !restoring { globalID = selectedID }
    }

    private func restoreGlobalSource() {
        guard keepGlobal, let source = sources.first(where: { $0.id == globalID }) else { return }
        restoring = true
        if currentID() != source.id { select(source) }
        // App activation and AppKit's input context can run in the same turn.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.keepGlobal, let desired = self.sources.first(where: { $0.id == self.globalID }),
               self.currentID() != desired.id { self.select(desired) }
            self.restoring = false
            self.selectedID = self.currentID()
        }
    }

    private func currentID() -> String {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        return property(source, kTISPropertyInputSourceID) ?? ""
    }

    private func property<T>(_ source: TISInputSource, _ key: CFString) -> T? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as? T
    }
}
