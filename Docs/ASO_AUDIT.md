# StreakRep ASO Audit

## Execution Update - 2026-07-10

- App Store Connect app: `6775801149` (`StreakRep Fit`).
- Bundle ID: `com.romerodev.repsfitness`.
- Version: `1.0.0`.
- App Store version ID: `0c1e0276-0689-43c3-9c94-8c92a4b43d74`.
- State after this execution: `PREPARE_FOR_SUBMISSION`.
- No App Store review submission exists.
- Uploaded and attached build: `100202607101`.
- Build ID: `13b0a93d-0e5c-4639-88a5-79827c1171ee`.
- Build processing state: `VALID`.
- Encryption declaration: `usesNonExemptEncryption=false`.
- Archive: `.asc/artifacts/Reps-1.0.0-100202607101.xcarchive`.
- IPA: `.asc/artifacts/Reps-1.0.0-100202607101.ipa`.

ASO applied remotely:

- Spanish and English app-info metadata synced.
- Spanish and English version metadata synced.
- Metadata validation: 0 errors, 0 warnings.
- iPhone 6.7 screenshots: 10 `en-US`, 10 `es-ES`, all `COMPLETE`.
- Apple Watch Series 10 screenshots: 5 `en-US`, 5 `es-ES`, all `COMPLETE`.
- The screenshot generator was adjusted to avoid unverified claims, remove community promises while the age-range entitlement is unavailable, keep status chrome clean, and align copy with the Apple Health/Fitness positioning.

Current ASO positioning:

- Competes with Strong, Hevy and Fitbod on fast workout logging, strength progress and Apple Watch support.
- Differentiates through Apple Health/Fitness integration, recovery context, routes, muscle load and progress views that Apple Fitness does not expose for strength users.
- Follows Apple's product page guidance: the first screenshots focus on the highest-conversion claims, keywords avoid repeated title terms and competitor names, and both localizations are fully adapted rather than literal clones.

Remaining manual/App Store Connect actions:

- Do not submit the app yet unless you are ready for review.
- `Reps Pro Lifetime` is now `READY_TO_SUBMIT`; submit it together with the app when you decide to send the release.
- The weekly, monthly and annual subscriptions still report Apple's opaque `MISSING_METADATA` state, while all public API checks are complete: group localizations, subscription localizations, review screenshots, availability and price records. Open each subscription in App Store Connect, review the UI-only checklist, save any prompted field, then re-run validation.
- Confirm App Privacy in App Store Connect. The public API cannot verify its published state.
- To restore community age verification later, enable Declared Age Range for `com.romerodev.repsfitness` in the Apple Developer portal, regenerate the distribution profile, restore the entitlement in `project.yml` and `Reps/Reps.entitlements`, then rebuild.

## Scope

- New App Store Connect app: `6775801149`
- Previous App Store Connect app: `6775740629`
- Target Bundle ID: `com.romerodev.repsfitness`
- Version: `1.0.0`
- Current state: `PREPARE_FOR_SUBMISSION`
- Primary locale in ASC: `es-ES`
- Locales prepared: `es-ES`, `en-US`
- Previously uploaded build: `100202606022`
- Current uploaded build: `100202606023`
- Attached build ID: `4c3e726f-f080-412a-88ed-db5e13ebb655`

Important ASC bundle status:

- The local project has been moved to `com.romerodev.repsfitness`.
- ASC Bundle ID `com.romerodev.repsfitness` exists: `QYPTD4W73L`.
- ASC Bundle ID `com.romerodev.repsfitness.widgets` exists: `Q3Z7N8252Y`.
- ASC Bundle ID `com.romerodev.repsfitness.watchkitapp` exists: `M92QVKVZ65`.
- App Store app `6775740629` is still associated with the previous bundle prefix, not the final RomeroDev bundle.
- Attempting `asc apps update --id 6775740629 --bundle-id com.romerodev.repsfitness` failed with: `An attribute value is not acceptable for the current resource state.`
- New App Store app `6775801149` was created with bundle ID `com.romerodev.repsfitness`.
- Deletion of the previous app was requested after uploading build `100202606023`, but the available `asc` public/API and web-session command surfaces do not expose an app-record delete operation.

## Positioning

StreakRep should compete as a focused strength training tracker, not as a generic fitness diary. The strongest conversion angle is: build a plan, log sets quickly, and prove progress with strength metrics.

Primary audience:

- Gym and home strength users.
- Lifters who want progression, 1RM estimates, PRs, volume and consistency.
- Users who dislike spreadsheets or bloated all-purpose fitness apps.

Core ASO benefits to repeat across metadata and screenshots:

1. Plan your training week.
2. Log every set fast.
3. Track strength progress.
4. See muscle load and fatigue.
5. Connect Apple Health, Apple Watch and widgets.

## Metadata Decisions

App name:

- Current ASC name: `StreakRep Fit`
- Intended final name: `StreakRep`
- Reason: the previous app still occupies the `StreakRep` name. Rename the new app back to `StreakRep` after the previous app is safely removed or the name becomes available.

Spanish subtitle:

- `Entrena, registra y progresa`
- 28/30 characters. Clear, action-oriented and broad enough for the primary locale.

English subtitle:

- `Train, track, get stronger`
- 26/30 characters. Stronger conversion language than a literal translation.

Spanish keywords:

- `gimnasio,rutinas,pesas,fuerza,fitness,entreno,progreso,series,reps,1rm,calendario`
- 81/100 characters.

English keywords:

- `workout,fitness,gym,strength,tracker,routines,weights,progress,reps,sets,1rm,calendar`
- 85/100 characters.

Notes:

- Keywords avoid repeating the brand name because the title already covers it.
- Keywords prioritize high-intent strength-training terms over generic wellness terms.
- `1rm`, `sets`, `series`, `pesas`, `rutinas`, and `calendar/calendario` support feature-specific search intent.

## Fields Completed Locally

- `metadata/app-info/es-ES.json`
- `metadata/app-info/en-US.json`
- `metadata/version/1.0.0/es-ES.json`
- `metadata/version/1.0.0/en-US.json`

Completed fields:

- Name.
- Subtitle.
- Description.
- Keywords.
- Promotional text.

Prepared but blocked by ASC state:

- What's new. ASC returned `Attribute 'whatsNew' cannot be edited at this time` for version `1.0.0`, so it was not applied remotely and is not kept in the canonical push files yet.

Recommended what's new copy when ASC allows editing:

- ES: `Lanzamiento inicial de StreakRep: planes de entrenamiento, registro de series, historial, progreso por ejercicio, mapa muscular, widgets, Apple Watch e integracion con Apple Health.`
- EN: `Initial StreakRep release: workout plans, set logging, history, exercise progress, muscle map, widgets, Apple Watch, and Apple Health integration.`

## Required Before Final Submission

These URLs are now present in the new app metadata:

- Privacy policy: `https://romerodev.com/streakrep/privacy`
- Support: `https://romerodev.com/streakrep/support`
- Marketing: `https://romerodev.com/streakrep`

Privacy policy must explicitly cover:

- Apple Health data read/write behavior.
- Workout, body metrics, hydration, calories and activity data.
- Local storage and backup behavior.
- Analytics/crash reporting if enabled.
- Subscription purchase handling via Apple.
- Contact email: `romerodev.app+streakreps@gmail.com`.

## Screenshot Plan

Real captures will be supplied later. Recommended order:

1. Today / active plan: headline around knowing exactly what to train today.
2. Active workout logging: headline around logging sets fast.
3. Progress dashboard: headline around volume, PRs and consistency.
4. Exercise progress: headline around 1RM and overload trends.
5. Muscle map / fatigue: headline around balancing training load.
6. Apple Watch/widgets: headline around following workouts everywhere.

Capture guidance:

- Use realistic filled data, never empty states.
- Use one visual mode consistently.
- Clean simulator status bar, ideally 9:41 with full battery.
- Avoid settings, login and low-content screens.
- Spanish and English screenshots should match the locale of the metadata.

## New ASC App Setup Completed

- New app created in ASC: `6775801149`.
- Bundle ID attached: `com.romerodev.repsfitness`.
- SKU: `STREAKREP-ROMERODEV-001`.
- Version set to `1.0.0`.
- Copyright set to `2026 RomeroDev`.
- Availability enabled for `US` and `ES`, with future new territories enabled.
- App price set to free.
- Category set to Health & Fitness.
- Content rights set to no third-party content.
- Age rating copied from the previous setup with health/wellness topics enabled.
- Build `100202606023` was archived, exported, uploaded, processed as `VALID`, encryption set to `usesNonExemptEncryption=false`, and attached to version `1.0.0`.
- The prior uploaded build `100202606022` remains in ASC build history but is no longer the active attached build for the App Store version.

## Monetization Setup Completed

- Subscription group: `Reps Pro` (`22128988`).
- Weekly subscription: `com.romerodev.repsfitness.pro.weekly`, USD 0.99 / EUR 0.99.
- Monthly subscription: `com.romerodev.repsfitness.pro.monthly`, USD 1.99 / EUR 1.99.
- Annual subscription: `com.romerodev.repsfitness.pro.annual`, USD 8.99 / EUR 8.99.
- Lifetime IAP: `com.romerodev.repsfitness.pro.lifetime`, EUR 19.99.

## Open ASO Risks

- App Store primary locale is `es-ES`; `en-US` now exists in ASC and matches the local canonical files.
- Screenshots are still pending.
- App Review contact details are pending: first name, last name, email and phone.
- Subscription App Review screenshots are pending.
- Lifetime IAP review metadata/screenshots are pending.
- App Privacy details cannot be fully verified through public ASC API; confirm manually or with ASC web privacy tools before submission.
- Firebase config is now present for `com.romerodev.repsfitness`; Analytics is enabled and Crashlytics loads in runtime.
- The previous ASC app `6775740629` still exists because Apple does not expose app-record deletion through the public App Store Connect API, and the available `asc web apps` command set has no delete operation.

## ASC Validation Findings

Latest command:

`asc validate --app 6775801149 --version 1.0.0 --platform IOS --output json --pretty`

Result:

- 5 blocking errors.
- 10 warnings.
- 1 info.

Blocking errors:

- Review contact first name missing.
- Review contact last name missing.
- Review contact email missing.
- Review contact phone missing.
- App Store screenshots missing.

Warnings:

- Subscription promotional images are missing for weekly, monthly and annual.
- Subscription App Review screenshots are missing for weekly, monthly and annual.
- Weekly, monthly and annual subscriptions are still `MISSING_METADATA` until review screenshots/assets are completed.
- Lifetime IAP is still `MISSING_METADATA` until required review metadata/assets are completed.

The previous product IDs should be left behind with the previous app. The new app now uses `com.romerodev...` product IDs.

Info:

- App Privacy publish state cannot be fully verified through the public ASC API. Confirm at `https://appstoreconnect.apple.com/apps/6775801149/appPrivacy`.
