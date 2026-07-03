# UI audit and resolution plan

Date: 2026-06-30  
Device: iPhone 17 Pro simulator, iOS 26.5  
Build: `Reps` Debug, bundle `com.romerodev.repsfitness`

## Result

The app builds and launches successfully in Simulator. The main interface was reviewed across Workout, Summary, Calendar, Social, Quick Log, and the Create Plan sheet. Onboarding was not reviewed in this pass because the simulator already has a persisted profile with onboarding completed.

## Resolution status

Implemented on 2026-06-30:

- Added `remote-notification` to background modes and removed deprecated `UIRequiresFullScreen`.
- Localized tabs, Quick Log, quick actions, Summary date/title, consistency label, Social empty username, and Create Plan card title.
- Added bottom padding for sticky-scroll screens and Social so Quick Log no longer competes with the final content.
- Fixed quick menu chart title truncation.
- Replaced the tab shell with a non-interactive background while Quick Log or primary sheets are active, so snapshots no longer expose underlying tab controls.

Still requires a separate clean-install pass:

- Onboarding validation on a fresh simulator, because the current simulator profile already has onboarding completed.

## Priority 0 - Runtime configuration

1. Add `remote-notification` to `UIBackgroundModes`.
   - Evidence: runtime logs report that `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` is implemented but `remote-notification` is missing.
   - Files: `project.yml`, `Reps/Info.plist`.
   - Verification: launch app and confirm the warning is gone from runtime logs.

2. Review `UIRequiresFullScreen` on iOS 26.
   - Evidence: build warning says `UIRequiresFullScreen` is deprecated and will be ignored in a future release.
   - Files: `project.yml`, `Reps/Info.plist`.
   - Verification: remove or justify the key, then rebuild on iOS 26 simulator without warning.

## Priority 1 - Localization consistency

1. Replace hard-coded tab and quick-action labels with localization keys.
   - Evidence: Spanish UI shows `Summary`, `Sharing`, `Quick Log`, `Train`, `Schedule`, `Create Plan`, `Free`, `Date`, `Routine`, `Custom`.
   - Files: `Reps/App/RootView.swift`, `Reps/Resources/Localizable.xcstrings`.
   - Current source: `AppTab.title`, `QuickLogTabAccessory`, `QuickMenuCloseButton`, `QuickAction.title`, `QuickAction.subtitle`.
   - Verification: Spanish app shows `Resumen`, `Social` or `Compartir`, `Registro rápido`, `Entrenar`, `Programar`, `Crear plan`, etc.; English still shows correct terms.

2. Normalize date formatting by profile language.
   - Evidence: Summary header shows `Tuesday, 30 Jun` while Today and Calendar show Spanish dates.
   - Files: `Reps/Features/Progress/ProgressView.swift`.
   - Current source: `currentDateSubtitle` uses `DateFormatter()` without setting `locale`.
   - Verification: with `preferredLanguage = es-ES`, Summary date uses Spanish; with `en-US`, it uses English.

3. Remove technical placeholders from user-facing empty states.
   - Evidence: Social profile shows `@—` when no social username is configured.
   - Files: `Reps/Features/Social/SocialHubView.swift`.
   - Verification: empty profile state invites setup/edit instead of showing an invalid username.

## Priority 2 - Layout and visual hierarchy

1. Fix `Quick Log` placement over the tab bar.
   - Evidence: the accessory visually crowds the tab bar and hides lower content on Workout, Summary, Calendar, and Social.
   - Files: `Reps/App/RootView.swift`, shared tab accessory styling in `PulseTheme` if needed.
   - Approach: define stable bottom spacing for scroll content when the accessory is visible; verify inline and expanded placements on iPhone and iPad.
   - Verification: no content is hidden behind Quick Log or tab bar; hit targets remain at least 44 pt.

2. Fix truncation in the quick menu chart.
   - Evidence: expanded quick menu truncates `VOLUMEN DE ENTRENAMIEN...`.
   - Files: `Reps/DesignSystem/QuickMenuProgressionChart.swift`, `Reps/App/RootView.swift`.
   - Approach: reduce title size in compact widths, use a shorter localized title, or allow two-line title with fixed chart height.
   - Verification: no ellipsis on iPhone 17 Pro width and smaller devices.

3. Reduce empty metric noise in Summary.
   - Evidence: Summary shows large chart/ring areas and metric cards with `—` and zero values, but little guidance.
   - Files: `Reps/Features/Progress/ProgressView.swift`.
   - Approach: add first-run empty states with clear primary actions, or collapse charts until there is meaningful data.
   - Verification: a fresh user sees actionable empty states, not mostly empty analytics.

## Priority 3 - Flow and accessibility polish

1. Isolate modal/sheet accessibility.
   - Evidence: after opening Quick Log and Create Plan, runtime snapshots still expose underlying Social elements and tabs as targets.
   - Files: `Reps/App/RootView.swift`, `Reps/Features/Plans/CreatePlanView.swift`.
   - Approach: mark background content hidden from accessibility while quick menu is expanded or modal sheets are active.
   - Verification: snapshot targets while Create Plan is visible include only the sheet controls and relevant system chrome.

2. Align capitalization and terminology.
   - Evidence: `Crear Plan` appears in title case while surrounding Spanish uses sentence case; social tab naming alternates between `Sharing`, `Social`, `Amigos`.
   - Files: `Reps/App/RootView.swift`, `Reps/Features/Social/SocialHubView.swift`, `Localizable.xcstrings`.
   - Verification: navigation labels, tabs, buttons, and empty states use one terminology set per locale.

3. Validate onboarding on a clean simulator.
   - Evidence: not reproduced in this pass because local simulator state bypassed onboarding.
   - Approach: install on a fresh simulator or erase app data, then review Welcome and Profile Setup in `es-ES` and `en-US`.
   - Verification: no hard-coded strings, clipped controls, permission dead-ends, or missing back/cancel paths.

## Suggested implementation order

1. Fix runtime plist/background mode warnings.
2. Localize RootView tab/accessory/quick-action strings and Summary date locale.
3. Fix Social empty username state.
4. Add bottom inset/content padding for Quick Log and verify all tabs.
5. Fix quick menu chart truncation and action capitalization.
6. Add snapshot/UI checks for Spanish and English launch states.
7. Run clean-simulator onboarding pass.

## Verification checklist

- Build and run `Reps` on iPhone 17 Pro simulator.
- Capture screenshots for Workout, Summary, Calendar, Social, Quick Log, and Create Plan.
- Confirm no English strings appear in Spanish except product/brand names.
- Confirm no visible text truncates on 368 pt width.
- Confirm no scroll content is hidden by Quick Log or the tab bar.
- Confirm runtime logs no longer include the remote notification background mode warning.
