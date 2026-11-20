# FastLangSwitch

A small native Swift app for macOS 13 and later. Tap **Right Command** to cycle through the keyboard input sources enabled in System Settings. Choose a different modifier, Fn / Globe, function key, or ordinary key in settings.

The app runs without a Dock icon or a status item. Switching uses Text Input Source Services directly, so macOS’s existing Input menu reflects the selected language. No switcher overlay, synthetic language-switch shortcut, debounce, or hold threshold is used. Open FastLangSwitch again to bring up its settings; closing settings leaves it running. Quit from the settings window or with ⌘Q while settings has focus.

## Build and run

Requires Swift 6 and the macOS SDK from Xcode 16 or later. The package uses Swift 6 language mode with strict concurrency checking. Tests use the bundled Swift Testing framework. There are no external dependencies.

```sh
./scripts/build-app.sh
open build/FastLangSwitch.app
```

For local development, build and deploy to `~/Applications` with:

```sh
./scripts/deploy-app.sh
```

The script builds the app, creates `~/Applications` if needed, removes an existing `FastLangSwitch.app`, and copies the new bundle into place. If the app is already running, quit it and reopen `~/Applications/FastLangSwitch.app` to use the new build. Set `APPLICATIONS_DIR` to override the installation directory, for example when verifying a deployment in a temporary folder.

Use a stable installation path in `~/Applications` or `/Applications` before granting access or enabling Launch at Login. Launch at Login uses `SMAppService.mainApp` and starts quietly. The same executable accepts `--background` for a quiet manual launch.

The build script signs ad hoc by default. For a stable permission identity across rebuilds, set `CODE_SIGN_IDENTITY` to your Apple Development or Developer ID certificate. Distribution outside your own Mac also requires the appropriate signing and notarization. `CONFIGURATION=debug` produces a debug app. Both variables also apply to `deploy-app.sh`. Open `Package.swift` in Xcode to work on the project.

## Initial setup

1. Open the app and grant **Accessibility** access. If macOS requests **Input Monitoring**, allow that too. Return to settings and click **Retry Keyboard Access** if needed.
2. Add at least two input sources in **System Settings → Keyboard → Text Input → Edit**. The app reads enabled, selectable keyboard sources, including input-method modes, and refreshes when macOS announces a change. It cycles in the order returned by the system API.
3. Turn **off** **Automatically switch to a document’s input source** in that same panel. This is required for consistent global behavior within documents as well as between apps. FastLangSwitch keeps one global choice and reasserts it at application activation, but macOS can otherwise restore a document’s input context later. There is no supported public API for changing this system preference, so the app links to Keyboard Settings instead.
4. Turn **on** **Show Input menu in menu bar** if you want the native language indicator. The app does not add its own indicator.
5. Disable conflicting macOS/third-party input-source shortcuts for your chosen key. If using **Fn / Globe**, set **Press 🌐 key to → Do Nothing** in Keyboard Settings. This prevents macOS’s own picker or other action from responding to the same key.

Settings apply immediately and persist in the app’s preferences. The app does not modify your system keyboard settings, enable/disable input sources, or keep a per-app layout database. Selections made using the native Input menu become the current global choice.

## If switching stops after login

Open FastLangSwitch to see why the keyboard monitor is stopped. **Accessibility required** means macOS hasn't granted access to the running copy. An ad hoc signature identifies one particular build, so a rebuild can invalidate an existing grant even when the old entry still appears enabled. In **Privacy & Security → Accessibility**, remove the old entry and add the exact app registered for Launch at Login. Use **Retry Keyboard Access** or reopen the app if needed. To keep the grant across rebuilds, sign consistently with the same Apple Development or Developer ID identity using `CODE_SIGN_IDENTITY`. A change of signing identity can require a new grant.

**Waiting for keyboard** means the granted app couldn't start its event tap. It retries in the background with settings closed. Allow Input Monitoring for that same copy if macOS requests it. **Secure input active** means macOS is protecting keyboard input. Switching resumes after secure input ends. If the app never launches, check **Launch at Login** and make sure it points to the copy you intend to use.

## Tap and shortcut behavior

Switching occurs **on release**, as soon as a solo tap is known. Switching on the initial press would change the language before it is possible to know whether the key will participate in a shortcut. There is no additional waiting interval, and holding a key alone still switches exactly once when released.

- **Modifier keys:** both press and release pass through unchanged. Any other key, modifier, mouse button, drag, or scroll during the press cancels switching. Existing Command, Option, Control, and Shift shortcuts retain their events and timing. Left and right modifiers are distinguished, including when both sides are held.
- **Ordinary keys:** the initial press and repeats are swallowed for a solo tap. When another input makes the gesture a chord, the original press is replayed below the event tap before that input, and its release passes through normally. This preserves event order, but apps that inspect hardware key state, custom event taps, or timing may behave differently. A dedicated modifier is the most reliable choice. A solo tap replaces the key’s normal action.
- A key or mouse button already held when the switch key is pressed disqualifies the tap. The recognizer also seeds physical state when starting or resuming, avoiding switches from keys that were already held.
- **Caps Lock is intentionally unavailable:** its hardware/system lock state cannot be safely treated like an ordinary held modifier with this event-tap approach. Selecting another key avoids altering capitalization or breaking Caps Lock shortcuts. Media keys and Touch ID are not ordinary keyboard events and cannot be recorded.
- macOS **Secure Keyboard Entry**, password entry, and the lock screen can block global event taps. While monitoring is enabled, the app checks secure-input state independently of the settings window and also checks before handling events. Entering secure input cancels the pending gesture and discards any buffered switch-key press; leaving it reseeds held keys and mouse buttons so hidden releases cannot leave stale state. The app shows secure-input status in settings and resumes its tap after sleep/session transitions. It cannot bypass secure input. Third-party input methods may display their own composition UI; the app itself never displays a language-switch view.

The event tap runs on the main run loop because Apple requires UI applications to call Text Input Source Services on the main thread. Input sources are cached; a switch performs a current-source lookup and a synchronous selection. No network activity or typed-text logging is involved. Only a pending switch-key event is retained, and only until the gesture is resolved. Outside secure input, buffered events fail open when monitoring stops or the tap is disabled.

## Verification

```sh
swift test
./scripts/build-app.sh
build/FastLangSwitch.app/Contents/MacOS/FastLangSwitch --diagnostics
```

The diagnostics command prints the app path, Launch at Login status, switching preference, Accessibility status, secure input, and the enabled source list without installing an event tap, changing the selected language, or opening a window. Run it from the exact app bundle you use. `--preview` opens settings without starting keyboard monitoring or restoring layouts, for UI inspection.

Automated tests cover solo taps, release timing, shortcuts in either modifier order, overlapping left/right modifiers, repeats, rapid taps, existing held keys/buttons, clicks/scrolls, ordinary-key replay decisions, and gesture recovery after secure input hides releases. Hardware event delivery, TCC permission prompts, and switching across real input methods need manual testing on a permission-granted Mac:

1. With two layouts, tap the configured modifier repeatedly; confirm one switch per release in the native Input menu and no overlay.
2. Hold that modifier for shortcuts, modifier combinations, clicks, and scrolling; confirm the shortcut works and no layout switch occurs. Repeat with the opposite-side modifier held.
3. Type in different apps and documents; confirm the global layout persists with the system’s per-document option disabled. Select a source through the native Input menu and confirm that choice persists.
4. Configure an ordinary key; verify solo taps type nothing, modified shortcuts pass through, and a chord started with that key receives its initial press before the next event.
5. Add/remove an input source while running; verify the list and cycle update. Sleep/wake and log out/in with Launch at Login enabled; verify quiet startup and normal switching.
6. Close settings, relaunch the app, and confirm a single running instance reopens settings without a Dock or app status icon.
7. With settings closed, enter and leave a secure text field while a key is held, then release it during secure entry. Confirm the next solo switch tap works, interrupted taps do not switch, and shortcuts still work after recovery.

For explicitly requested secure-input UI testing, run the fixture in one terminal:

```sh
swift -swift-version 6 scripts/secure-input-fixture.swift
```

In another terminal, run `./scripts/test-secure-input.sh`, then click **Start secure-input test** in the fixture and immediately hold A for 0.9 seconds. The fixture briefly enables secure input and reports whether the key was released during it. The probe uses the production `KeyboardMonitor` without a settings window and must report both transitions and `PASS`. It requires keyboard access; it fails with a timeout if no transitions arrive. Quit the fixture when finished; it balances its own secure-input enable/disable calls. These tests are opt-in and are not run by `swift test`.

Use a physical keyboard to verify global switching after the fixture completes. Automation that delivers keys directly to a target app can bypass the session event tap, so a successful text-entry check alone does not verify global interception. The unit tests separately cover gesture recovery after hidden releases.

Apple references: [Text Input Source Services threading requirements](https://developer.apple.com/documentation/carbon/text_input_source_services), [event taps](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:)), [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice), and [Input Sources settings](https://support.apple.com/guide/mac-help/mchl84525d76/mac).
