import SwiftUI
import Combine
import ServiceManagement
import SwitchCore

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var sources: InputSources
    var onDone: () -> Void
    @State private var recorderError: String?
    private let statusTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
                Text("FastLangSwitch").font(.title2.bold())
                Spacer()
                Circle().fill(model.monitoringStatus == .running ? Color.green : Color.orange).frame(width: 8, height: 8)
                Text(model.monitoringStatus.rawValue)
                    .font(.callout).foregroundStyle(.secondary)
            }
            .padding(24)
            Divider()
            Form {
                Section {
                    Toggle("Enable layout switching", isOn: $model.enabled)
                    HStack {
                        Text("Switch key")
                        Spacer()
                        Menu {
                            ForEach(SwitchKey.presets, id: \.code) { key in
                                Button(key.name) { model.key = key }
                            }
                            Divider()
                            Button("Record another key…") {
                                recorderError = nil
                                model.recording = true
                            }
                        } label: {
                            Text(model.key.name).frame(minWidth: 130)
                        }
                        .fixedSize()
                        .disabled(model.recording)
                    }
                    if model.recording {
                        HStack {
                            Text("Press a key on its own. Escape cancels.").foregroundStyle(.secondary)
                            Spacer()
                            Button("Cancel") { model.recording = false }
                        }
                        KeyRecorder(onKey: { key in
                            model.key = key
                            model.recording = false
                            recorderError = nil
                        }, onCancel: { model.recording = false }, onError: { recorderError = $0 })
                        .frame(height: 1)
                    }
                    if let recorderError { Text(recorderError).foregroundStyle(.orange).font(.callout) }
                    Text("Release the key to switch. Pressing another key, clicking, or scrolling while it is held cancels the switch.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if !model.key.isModifier {
                        Text("A solo tap replaces this key’s normal action. If you use it in a chord, its press is forwarded before the next event. Modifier keys preserve shortcuts most reliably.")
                            .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                } header: { Text("Switching") }

                Section {
                    if sources.sources.isEmpty {
                        Text("No selectable keyboard input sources were found.").foregroundStyle(.secondary)
                    }
                    ForEach(sources.sources) { source in
                        HStack {
                            Text(source.name)
                            Spacer()
                            if source.id == sources.selectedID {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                                    .accessibilityLabel("Current input source")
                            }
                        }
                    }
                    if sources.sources.count < 2 {
                        Text("Add at least two input sources to switch between languages.")
                            .font(.callout).foregroundStyle(.orange)
                    }
                    Button("Open Keyboard Settings…") { model.openKeyboardSettings() }
                } header: { Text("System input sources") }

                Section {
                    Label(model.accessibilityGranted ? "Accessibility access granted" : "Accessibility access required",
                          systemImage: model.accessibilityGranted ? "checkmark.shield" : "lock.shield")
                    if !model.accessibilityGranted {
                        Text("Allow FastLangSwitch in System Settings → Privacy & Security → Accessibility to access keyboard events.")
                            .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Text("If you rebuilt FastLangSwitch and access appears enabled, remove the old entry and add the app you currently use.")
                            .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Button("Grant Accessibility Access…") { model.requestAccessibility() }
                    }
                    Button("Retry Keyboard Access") { model.retry() }
                    Toggle("Launch at login", isOn: Binding(
                        get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }
                    ))
                    if model.loginNeedsApproval {
                        Button("Approve in Login Items…") { SMAppService.openSystemSettingsLoginItems() }
                    }
                    if model.secureInput {
                        Text("Secure Keyboard Entry is active. macOS may suspend switching in password fields or apps using secure input.")
                            .font(.callout).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                    }
                    if let error = model.error ?? model.monitorError ?? sources.error {
                        Text(error).font(.callout).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                    }
                } header: { Text("Permissions & startup") }

                Section {
                    Text("In Keyboard → Text Input → Edit, turn off “Automatically switch to a document’s input source” to keep one layout across apps and documents. Turn on “Show Input menu in menu bar” if you want the system indicator.")
                    Text("Disable any macOS or third-party shortcut that uses your chosen key to change input sources. For Fn / Globe, set “Press 🌐 key to” to “Do Nothing” in Keyboard Settings.")
                } header: { Text("macOS settings") }
                .font(.callout).foregroundStyle(.secondary)
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Text("Open FastLangSwitch to change settings.").font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                Button("Done", action: onDone).keyboardShortcut(.defaultAction)
            }.padding(16)
        }
        .frame(minWidth: 560, idealWidth: 600, minHeight: 680, idealHeight: 790)
        .onReceive(statusTimer) { _ in model.refreshStatus() }
        .onDisappear { model.recording = false }
    }
}
