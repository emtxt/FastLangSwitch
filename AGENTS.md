# Agent instructions

These instructions apply to the entire repository.

## Project

FastLangSwitch is a native macOS keyboard-layout switcher. Keep it small, quiet,
and responsive. Read `README.md` for setup requirements and known limitations.

- Target macOS 13 and later. Use Swift 6 language mode with Swift 6 / Xcode 16
  or later; preserve strict concurrency checking.
- Use the system's enabled input sources and native Input menu. Keep one global
  layout choice rather than introducing app-specific layout preferences.
- Keep the running app out of the Dock and do not create an app status item.
  Preserve `LSUIElement`, settings on relaunch, single-instance behavior, and
  quiet login startup. Closing settings must leave the app running.
- Keep settings functional and concise. Do not add marketing copy, slogans,
  switch overlays, notifications, or animations to the switching flow.
- Prefer existing Apple frameworks and avoid unnecessary dependencies.

## Code map

- `Sources/SwitchCore/`: deterministic key definitions and tap recognition;
  keep this independent of AppKit, permissions, and system input-source APIs.
  `InputSession` cancels and reseeds gestures across secure-input transitions.
- `Sources/FastLangSwitch/KeyboardMonitor.swift`: event tap, physical-state
  snapshots, event suppression/replay, and recovery.
- `Sources/FastLangSwitch/InputSources.swift`: Text Input Source Services,
  source-change notifications, and the global layout choice.
- `Sources/FastLangSwitch/AppModel.swift`: settings, permissions, monitoring
  lifecycle, and Launch at Login.
- `Sources/FastLangSwitch/NotificationObservation.swift`: main-queue notification
  delivery and observer-token cleanup.
- `Sources/FastLangSwitch/main.swift`: AppKit lifecycle and settings window.
- `Sources/FastLangSwitch/SettingsView.swift` and `KeyRecorder.swift`: settings UI.
- `Tests/SwitchCoreTests/`: Swift Testing tests for gesture behavior.
- `Tests/UI/` and `scripts/test-secure-input.sh`: opt-in background-monitor
  integration probe; `scripts/secure-input-fixture.swift` is its UI fixture.
- `Support/Info.plist`: app identity, icon, deployment target, and agent behavior.
- `scripts/build-app.sh`: build, bundle, icon generation, and signing.
- `scripts/deploy-app.sh`: local build and deployment to `~/Applications`;
  `APPLICATIONS_DIR` overrides the destination for isolated deployment checks.
- `scripts/generate-icon.swift`: editable vector drawing source for the app icon.
  Change this source rather than generated PNG or ICNS files.
- `.build/` and `build/`: generated output; do not commit or hand-edit it.

## Keyboard behavior

- Resolve a solo tap on release. Do not switch on initial press or add timers,
  debounce, or hold thresholds to distinguish taps from shortcuts.
- Forward modifier events unchanged. Other keys, modifiers, mouse buttons,
  drags, and scrolling must cancel the pending switch.
- For ordinary switch keys, suppress solo presses and repeats. If a chord forms,
  replay the buffered press below the current event tap before forwarding the
  chord's next event. Preserve event order and prevent replay recursion.
- Seed held-key and mouse-button state when monitoring starts or resumes.
  Flush buffered events when stopping or recovering so keys do not get stuck.
- Preserve left/right modifier distinctions. Caps Lock is a persistent mode;
  function/navigation keys can carry a Function flag without physical Fn being
  held. Keep these cases distinct.
- Keep event callbacks short. Do not add blocking work, network requests, or
  typed-text logging. Retain only events needed for the pending gesture.
- Call Text Input Source Services on the main thread. Use direct source selection
  rather than synthesizing macOS's language-switch shortcut.
- Keep app state and keyboard monitoring isolated to `@MainActor`. Bridge legacy
  callbacks with synchronous `MainActor.assumeIsolated` only where main-thread
  delivery is guaranteed. Do not add tasks to the event callback or use unchecked
  `Sendable` conformances to suppress concurrency errors. Document any necessary
  compatibility imports for legacy SDK declarations.
- Respect secure input and permission restrictions. Do not silently change system
  keyboard preferences. Consistent global behavior requires the user to disable
  macOS's per-document input-source memory; preserve that setup guidance.

## Validation

During normal feature development, make the necessary changes to code, tests,
documentation, and other affected files. Add or update unit tests and run them
as part of that work.

Do not run UI tests or inspections that open the app window or manipulate UI
state unless the user explicitly requests testing. This includes automated UI
tests, manual UI checks, computer-use automation, and launching with `--preview`;
these actions can disturb the user's interaction with the system.

- A request such as "Implement feature X" authorizes implementation and unit
  testing, but does not authorize UI testing. Complete the feature without
  launching or manipulating the UI for verification.
- An explicit request such as "run tests" authorizes all tests relevant to the
  feature in question, including UI tests, unless the user limits the scope
  (for example, "run unit tests only").
- UI test code may be added or updated during feature development, but running
  it requires that explicit testing request. Keep the default unit-test command
  noninteractive; put UI tests behind a separate command or explicit opt-in.

Use checks appropriate to the change:

```sh
swift test
./scripts/build-app.sh
codesign --verify --strict --verbose=2 build/FastLangSwitch.app
build/FastLangSwitch.app/Contents/MacOS/FastLangSwitch --diagnostics
```

- Use Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest. Prefer
  isolated value-type suites. Add or update behavior tests for gesture changes;
  preserve coverage for chords, release order, repeats, held inputs, modifier
  sides, function flags, and replay decisions.
- `swift test` builds the package. Run the bundle script when changing packaging,
  icons, resources, or when delivering an updated app. It signs ad hoc by default;
  `CODE_SIGN_IDENTITY` supplies a certificate and `CONFIGURATION=debug` selects
  a debug build.
- When UI testing is explicitly requested, launch the bundled executable with
  `--preview` for visual checks so startup does not install the keyboard tap or
  restore layouts. Permission and startup controls still perform real actions;
  avoid changing them during visual checks.
- `--diagnostics` reports access and input sources without starting monitoring.
  Do not claim live interception or cross-app switching was verified unless
  tested with the required permissions and system settings.
- Documentation-only changes do not require builds or tests. Keep `README.md`
  aligned with changes to setup, behavior, commands, and limitations.

Keep changes focused and preserve existing user work. Report what changed,
which checks passed, and any verification that still requires a real Mac session.
