# Auditoría de flujos pre-release — StreakReps (2026-07-18)

Alcance: 4 targets (Reps ~85k líneas, RepsWatch, RepsWidgets, RepsShared), flujos funcionales y técnicos: arranque, onboarding, Today, workout activo, planes, progreso, social, monetización, Watch, widgets, Live Activity, persistencia, localización y readiness de App Store.

Verificación ejecutada en esta sesión: `xcodebuild build` **BUILD SUCCEEDED**, suite de tests **91/91 passed**, `Scripts/verify-localization.mjs` ejecutado, URLs legales comprobadas por HTTP (todas 200).

Este informe **continúa** la `AUDITORIA_PRE_LANZAMIENTO_2026-07-13.md`: sus dos P0 (push capability y borrado de cuenta social) están confirmados como corregidos en el código actual (`aps-environment` presente en `Reps/Reps.entitlements`; `SocialService.deleteAccount` en `SocialService.swift:1310` cableado desde `AppStore.swift:4767`).

## Veredicto

La base es sólida y publicable a corto plazo: el bucle central (onboarding → Hoy → entrenar → registrar → resumen → progreso/racha) está completo y bien construido, la persistencia reconcilia por id, la recuperación de sesiones HealthKit existe en iPhone y Watch, y no hay TODOs ni pantallas a medias. Pero hay **1 bloqueante nuevo (privacidad ASC)** y **5 temas de alta prioridad** que degradan la primera impresión o producen incoherencias visibles.

---

## P0 — Bloqueante

### 1. Etiqueta de privacidad "Data Not Collected" contradice lo que la app hace

`.asc/privacy-data-not-collected.json` declara `DATA_NOT_COLLECTED` como cuestionario de App Privacy. La app integra **Firebase Analytics + Crashlytics** (telemetría activa en `TelemetryService`, eventos y user properties), **RevenueCat** (compras), **perfiles sociales públicos en CloudKit** (username, bio, ubicación, fotos, posts), **HealthKit** y **ubicación**. Publicar con esa etiqueta es una infracción directa de la política de privacy labels (causa de rechazo y de retirada posterior).

**Acción:** regenerar el cuestionario App Privacy real (Analytics/Crash Data/Purchases/Health & Fitness/Location/User Content/Identifiers, con vínculo a identidad donde aplique — el perfil social vincula) y alinearlo con `RepsShared/PrivacyInfo.xcprivacy`, que ya fue ampliado el 13-07 y ahora contradice este JSON.

---

## P1 — Alta prioridad (antes de release)

### 2. Banner promocional VitalsPath no descartable para usuarios free

`VitalsPathPromotionBanner.swift:27-31` + `RootView.swift`: cada 90–240 s hay un 38 % de probabilidad de mostrar un banner de promoción cruzada durante **30 s**; los botones de cierre ("ocultar ahora" / "para siempre") solo existen si `isPremium` (`VitalsPathPromotionBanner.swift:104`; `dismissCurrentPromotion` en RootView con `guard store.hasProAccess`). Un usuario free nuevo ve un anuncio flotante recurrente que solo puede arrastrar, no cerrar, desde la primera sesión.

**Riesgo:** reviews negativas inmediatas, sensación de adware, y fricción en App Review (interferencia con el uso de la app). **Acción:** permitir cerrar la instancia actual a todos (mantener "ocultar para siempre" como perk Pro si se quiere), o bajar drásticamente la frecuencia y no mostrarlo en la primera semana de uso.

### 3. El menú rápido "+" destruye y reconstruye todo el TabView

`RootView.swift:360-369` (`activeTabSurface`): cuando `isQuickMenuExpanded || presentedQuickAction != nil`, el `tabShell` completo se sustituye por un fondo plano. Cada apertura del quick menu o de una quick action desmonta TodayView (6.3k líneas), PlansView, etc.: se pierde el scroll y el estado de navegación interna de las pestañas y se paga la reconstrucción completa del árbol al volver.

**Acción:** verificar en dispositivo; si el objetivo era rendimiento, usar `.opacity`/`allowsHitTesting` o `zIndex` para mantener el TabView vivo detrás del overlay.

### 4. Watch: el cronómetro no descuenta las pausas (fuerza, intervalos y sesiones dirigidas por iPhone)

`WatchWorkoutModel.startTimer()` calcula `elapsedSeconds = Int(Date().timeIntervalSince(startedAt))` sin restar `accumulatedPausedSeconds`; solo el camino standalone-route lo corrige (`updateStandaloneSnapshotIfNeeded`). En fuerza/intervalos el tiempo mostrado sigue corriendo en pausa, mientras que los resúmenes guardados (`makeStrengthSummary`, `makeIntervalSummary`) sí descuentan pausas → el usuario ve un tiempo y se guarda otro.

**Acción:** restar `currentPausedSeconds` en el tick del timer para todos los modos.

### 5. Idioma mixto en Widgets, Live Activity y Watch cuando idioma de app ≠ idioma del sistema

Los strings resueltos con `localizedString()` siguen la preferencia de idioma de la app (snapshot), pero los `Text("clave")` (LocalizedStringKey) resuelven con el locale del sistema. Casos localizados: `RepsStreakWidget.swift` ("streak", "weekly_consistency", `day_singular`/`days_plural`, "when_you_have_an_active_plan…"), `RepsBatteryWidget` ("recovery_battery"), `RepsWorkoutLiveActivity.swift:94,109,239` ("Time", "Distance", "rest"), `WatchWorkoutView.swift:612` (`Text("PAUSED")`). Un usuario con iPhone en inglés y app en español verá widgets bilingües.

**Acción:** unificar todo a `localizedString()` (o `Text(verbatim:)`) en los 3 targets de extensión.

### 6. iPad habilitado sin ninguna adaptación

`TARGETED_DEVICE_FAMILY: "1,2"` con orientaciones landscape para iPad declaradas, pero **cero** usos de `horizontalSizeClass`/idiom en todo el código. La app se lanzará en iPad con layout de iPhone estirado, exigirá screenshots de iPad en ASC y expone la review a un dispositivo no probado.

**Acción recomendada para v1:** `TARGETED_DEVICE_FAMILY: "1"` (solo iPhone). Alternativa: QA completo en iPad Pro 13" antes de enviar.

### 7. CloudKit Production: índices de queries sociales sin verificar (arrastrado de auditoría anterior)

`SocialService` consulta `SocialProfile`, `SocialFollow`, `WorkoutPost`, etc. en la base pública. Los índices creados en Development **no se despliegan solos** a Production. Si faltan, el feed social falla en producción aunque funcione en desarrollo.

**Acción:** desplegar schema a Production en CloudKit Dashboard y probar el flujo social completo con un build TestFlight (que además valida push APNs en entorno production).

---

## P2 — Calidad (planificable, no bloquea)

8. **Prompts de permisos sin contexto en la primera sesión.** El clima de TodayView lanza `requestWhenInUseAuthorization` al renderizar la pestaña Hoy sin gesto del usuario (`TodayView.swift:4587-4589`), y el prompt de notificaciones salta al arrancar si `remindersEnabled` (`RepsApp.swift:197-201`). Un usuario recién salido del onboarding puede comer 2 prompts seguidos. Mover ubicación a un tap en la tarjeta de clima y pre-explicar notificaciones.
9. **Claves de localización que viven solo en el fallback de código.** `evolucion_cardio/fuerza/core`, `resting_label`, `active_set_label`, `trends_and_distance`, etc. existen en `localizedFallbacks` (en/es) de `WorkoutShared.swift` pero no en el catálogo — funciona, pero es el anti-patrón que el linter señala y una tercera lengua futura los perdería. Migrarlas al catálogo. También: `.value("Duración", …)` en ejes de charts (`ProgressView.swift:1688,1695` — visible en Audio Graphs/accesibilidad) y `"\(preset.rounds) rondas"` hardcodeado en `WatchWorkoutView.swift:513`.
10. **Catálogo con ~4.400 entradas stale** (incluye basura de extracción tipo `", Int(pace) % 60))/km"` como clave y 1.900 pares en==es). La limpieza se descartó deliberadamente el 13-07 por riesgo; revalidar tras la v1 con un script que solo elimine claves no referenciadas ni presentes en fallbacks.
11. **Watch: `startWorkout(configuration:)` sin guard reentrante** — un doble arranque rápido (p. ej. `startWatchApp` + tap del usuario) puede crear dos `HKWorkoutSession` (el flag `isStartingLocalSession` solo protege el camino de snapshots). Añadir el mismo flag aquí.
12. **Watch: `send(command:)`/`WatchCommandRouter` usan `updateApplicationContext` como fallback**, lo que sobreescribe el application context completo y podría pisar un summary pendiente enviado por el mismo canal. Usar `transferUserInfo` para comandos no urgentes.
13. **ActiveWorkoutView se re-renderiza entero cada segundo** (`Timer.publish(every: 1)` en la raíz, `ActiveWorkoutView.swift:83,261`). Hay trabajo de perf previo, pero conviene aislar el tick en subvistas (cronómetro/descanso) y perfilar con Instruments en un entreno de 10+ ejercicios.
14. **God files:** `TodayView.swift` (6.356 líneas) y `AppStore.swift` (5.834). No es bug, pero castiga compilación incremental y revisión. Trocear post-release.
15. **Cobertura de tests desequilibrada:** 91/91 pasan pero en un solo archivo y sin UI tests; los flujos de más riesgo de release (paywall/compra, onboarding completo, deep links de notificaciones) no tienen cobertura automatizada. Mínimo: smoke UI test de onboarding→primer plan y paywall (sandbox).

---

## Fortalezas confirmadas (no tocar)

- Persistencia SwiftData con reconciliación por id + debounce 500 ms + flush al backgroundear; fallback en memoria con alerta al usuario.
- Recuperación de sesiones HealthKit tras terminación en iPhone y Watch; descarte de workouts vacíos (<60 s sin datos) para no ensuciar Salud; protección contra doble sesión por ráfaga de snapshots.
- Live Activity con `Text(timerInterval:)` auto-actualizable y `staleDate`; widgets con timelines razonables y recarga dirigida desde la app.
- Clima con caché en disco + fallback MET Norway con atribución — buen diseño frente a cuota de WeatherKit.
- Social con report/block, age gate y borrado de cuenta CloudKit (5.1.1(v) cubierta).
- Paywall con close/restore/código promocional/links legales; URLs legales en producción (verificadas 200 hoy).
- Sin `try!`, sin force-unwraps significativos, 2 `fatalError` justificados, sin TODOs pendientes.

## Estado de las correcciones (misma sesión, 2026-07-18)

Aplicado y verificado (build iOS **SUCCEEDED**, build watchOS **SUCCEEDED**, tests **91/91**, `verify-localization.mjs` **passed** — solo queda el aviso conocido de entradas stale):

- **P0 privacidad**: eliminado `.asc/privacy-data-not-collected.json`; nueva declaración real en `.asc/privacy-declaration.json` (Crashlytics/Analytics/RevenueCat no vinculados; perfil social CloudKit vinculado; ubicación para clima no vinculada; HealthKit/rutas no se declaran por quedarse en dispositivo/iCloud privado). Instrucciones y racional en `.asc/PRIVACY_DECLARATION_NOTES.md`. **Paso manual pendiente**: `asc web privacy plan/apply/publish` (requiere sesión web con 2FA) y validar tokens contra `asc web privacy catalog`.
- **Banner VitalsPath**: la X y "ocultar ahora" disponibles para todos; "ocultar para siempre" queda como perk Pro; además ya no aparece hasta que el usuario tiene al menos un entreno completado.
- **Quick menu**: el TabView permanece montado (se eliminó el swap por fondo plano); scroll y navegación de pestañas se conservan.
- **Watch cronómetro**: el tick descuenta `currentPausedSeconds` en todos los modos; añadida contabilidad de pausa también en el camino dirigido por snapshots del iPhone.
- **Watch robustez**: guard reentrante en `startWorkout(configuration:)`; comandos en cola vía `transferUserInfo` (ya no pisan el application context); además `didReceiveUserInfo` en iPhone ahora enruta por el handler completo — antes los `logSet`/comandos en cola se descartaban en silencio.
- **Idioma mixto**: todos los `Text("clave")`/`LocalizedStringKey` de widgets, Live Activity y Watch resuelven ahora vía `localizedString()` (idioma de la app); corregidas 5 claves con inglés sin traducir (PAUSA→PAUSED, CINTA→TREADMILL, RUTA→ROUTE, ACTIVO→ACTIVE, ACTUALIZANDO→UPDATING).
- **Catálogo**: las 105+ claves que solo vivían en `localizedFallbacks` migradas al catálogo (en+es); ejes de charts `"Fecha"`/`"Duración"` localizados con `date_2`/`duration_label`.
- **iPad desactivado**: `TARGETED_DEVICE_FAMILY: "1"` + eliminadas orientaciones de iPad; proyecto regenerado con xcodegen.
- **Permiso de ubicación contextual**: el clima de Hoy ya no dispara el diálogo del sistema al renderizar; muestra una tarjeta con botón "Activar ubicación" (nueva fase `locationPermissionNeeded`, claves `weather_location_permission_prompt` / `weather_enable_location`).

Pendiente (no automatizable desde el repo): publicar App Privacy vía `asc web privacy`, desplegar schema CloudKit a Production y el pase TestFlight de social/push. P2 restantes: refactor del tick de ActiveWorkoutView, god files, limpieza de entradas stale del catálogo, UI tests.

## Orden de ataque sugerido

| # | Acción | Esfuerzo |
|---|--------|----------|
| 1 | Rehacer App Privacy en ASC (sustituir `privacy-data-not-collected.json`) | 1-2 h |
| 2 | Banner VitalsPath cerrable para free / bajar frecuencia | 30 min |
| 3 | Fix cronómetro-pausa del Watch | 30 min |
| 4 | Quick menu sin destruir TabView | 1-2 h |
| 5 | Unificar localización en widgets/LA/Watch (`Text(key)` → `localizedString`) | 1 h |
| 6 | Decidir iPhone-only vs QA iPad | 15 min / 1 día |
| 7 | Desplegar schema CloudKit a Production + TestFlight social/push | 2 h |
| 8 | P2 en lotes tras la primera build de TestFlight | — |
