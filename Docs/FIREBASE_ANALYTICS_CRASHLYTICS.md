# Firebase Analytics and Crashlytics

Operational owner/account: `lbernardo.dev@gmail.com`

Firebase project: `reps-241f8`

iOS bundle id: `com.romerodev.repsfitness`

Google app id: `1:296521105435:ios:272a7ad1536ce6c35bf8be`

## Integration

- `Reps/GoogleService-Info.plist` is bundled in the main app target.
- The main app target links `FirebaseCore`, `FirebaseAnalytics`, and `FirebaseCrashlytics` from `firebase-ios-sdk` `12.14.0`.
- `Reps/App/RepsApp.swift` configures Firebase during app launch before telemetry events are emitted.
- `Reps/Services/TelemetryService.swift` is the single app-facing API for Analytics events, Crashlytics breadcrumbs, non-fatal errors, and debug test crashes.
- The Crashlytics build phase runs Firebase's `Crashlytics/run` script and uploads dSYMs with `GoogleService-Info.plist` as an input.

## Privacy rules

- Do not send user emails, display names, aliases, or social usernames to Firebase.
- Keep events decision-oriented and named with lowercase underscores.
- Health and workout details should stay local unless a specific event needs aggregate, non-identifying metadata.
- `REPS_DISABLE_TELEMETRY=1` disables Firebase telemetry for local diagnostic runs.

## Verification

1. Build and run the `Reps` target on a real device or simulator.
2. Open Firebase Analytics DebugView and confirm `app_open` appears after launch.
3. In a Debug build, open the developer menu and tap `Forzar crash de prueba`.
4. Relaunch the app so Crashlytics can send the pending report.
5. Confirm the crash appears in Firebase Crashlytics with app version, build number, bundle id, and `firebase_project_id = reps-241f8`.
