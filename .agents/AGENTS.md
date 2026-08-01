# Project Rules

## Post-Modification Workflow
- Always compile the app for simulator (`xcodebuild -scheme Reps -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` or using the active booted simulator destination).
- Install the newly built app into the booted simulator (`xcrun simctl install booted <path-to-app>`).
- Launch the app in the simulator (`xcrun simctl launch booted com.romerodev.repsfitness`).
