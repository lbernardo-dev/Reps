# Auditoría pre-lanzamiento — Reps (StreakRep)

Fecha: 13 de julio de 2026
Alcance: los 4 targets del proyecto (Reps, "RepsWatch Watch App", RepsWidgets, RepsShared) — flujos completos, integración con el ecosistema Apple, permisos y localización, con vistas a publicación en App Store.

Metodología: verificación directa de código (no solo lectura de auditorías previas en `Docs/`), más dos subagentes de investigación en paralelo para flujos de usuario y para integración Apple. Cada hallazgo está referenciado a archivo:línea.

## Veredicto

**No publicar todavía.** Hay 2 bloqueantes reales (P0) y son acotados y arreglables en poco tiempo. El resto del sistema — el bucle central de entrenamiento, HealthKit, Watch, Widgets, Live Activities, Siri/App Intents, StoreKit — está genuinamente bien construido y conectado, no solo documentado. Varias correcciones de auditorías anteriores (idioma partido, permisos sin traducir) ya se aplicaron correctamente y se confirman aquí.

**Actualización 2026-07-13 (misma sesión):** ambos P0 y todos los P1 con alcance seguro quedaron corregidos en código (ver "Estado de las correcciones" al final). `xcodebuild` del target `Reps` en simulador termina en **BUILD SUCCEEDED** sin warnings/errores en ningún archivo del build (incluye Watch y Widgets como dependencias embebidas). Queda un único paso manual fuera del repo: abrir Xcode una vez con el equipo de firma correcto para que registre la capability Push Notifications en el Developer Portal (ver detalle abajo).

**Actualización 2026-07-13 (segunda pasada — "completa todo lo pendiente"):** revisados y cerrados los 4 puntos que habían quedado pendientes: (1) los literales españoles fuera de catálogo resultaron ser, en su gran mayoría, falsos positivos del script — ya estaban correctamente traducidos vía tablas de fallback locales que el linter no conoce; los 3 casos reales se corrigieron; (2) manejo de conflictos de iCloud implementado con `NSFileCoordinator`/`NSFileVersion`; (3) `PrivacyInfo.xcprivacy` ampliado con tipos de datos Health/Fitness/Location; (4) limpieza masiva de las entradas `stale` del catálogo evaluada y **descartada deliberadamente** por riesgo real de romper localización dinámica (evidencia concreta abajo). Ver detalle en "Segunda pasada" al final del documento.

---

## P0 — Bloqueantes de publicación

### 1. Push notifications rotas (falta capability)

`Reps/App/RepsApp.swift:69` llama a `application.registerForRemoteNotifications()`. No es código muerto: alimenta un sistema real de notificaciones sociales vía `CKQuerySubscription` (follows, likes, comments) que se parsean en `didReceiveRemoteNotification` (`RepsApp.swift:81-146`).

El problema: `Reps/Reps.entitlements` no tiene la clave `aps-environment` y no existe la capability "Push Notifications" en `Reps.xcodeproj/project.pbxproj`. El registro ante APNs fallará en dispositivo real, y el fallo se traga en silencio porque `didFailToRegisterForRemoteNotificationsWithError` (`RepsApp.swift:149`) está vacío y `didRegisterForRemoteNotificationsWithDeviceToken` (línea 148) descarta el token aunque llegue.

Efecto: las `CKQuerySubscription` se crean en CloudKit pero nunca entregan nada; las notificaciones sociales no llegarán jamás a ningún usuario, y Apple puede señalar `UIBackgroundModes: remote-notification` como no usado/mal configurado en revisión.

**Arreglo:** activar la capability "Push Notifications" en Signing & Capabilities (añade `aps-environment` automáticamente al entitlements + perfil de aprovisionamiento). Sustituir los stubs vacíos por al menos un log de telemetría para detectar regresiones futuras.

### 2. No existe borrado de cuenta/perfil social

`Reps/Services/SocialService.swift` crea un perfil público real en CloudKit (`CKContainer(identifier: "iCloud.com.romerodev.repsfitness")`, `profileRecordID` en línea 308, `createOrUpdateProfile` en línea 354) con username, bio, posts, comentarios y followers — una cuenta real según la definición de Apple.

No existe ninguna función `deleteProfile`/`deleteAccount` en todo el repo (confirmado por dos vías independientes: búsqueda directa y agente de flujos). El único control de borrado, "Delete All Data" (`ProfileView.swift:1057,1632` → `store.resetAllData()` → `AppStore.swift:3122` → `restore(.empty)`), solo limpia el `AppSnapshot` local; nunca toca el perfil, posts, comentarios ni follows en CloudKit público.

Un usuario que crea perfil social no tiene manera de eliminarlo del servidor. Esto es un riesgo directo contra la **Guideline 5.1.1(v)** de App Review (las apps que permiten crear cuenta deben permitir borrarla).

**Arreglo:** añadir `deleteProfile()` en `SocialService` que borre el registro `SocialProfile_*`, los posts, comentarios y follows del usuario en CloudKit; exponerlo como acción explícita en Ajustes/Social, y opcionalmente encadenarlo desde `resetAllData()`.

---

## P1 — Corregir antes de publicar (no bloquean técnicamente, pero son riesgo de calidad/revisión)

### Localización

- **Claves usadas en código que no existen en el catálogo**: `achievement_close_all_format`, `achievement_close_all_toast` (`Features/Profile/AchievementUnlockOverlay.swift`), `social_moderator_delete_comment`, `social_moderator_ban_user` (`CommentsView.swift`), `social_moderator_delete_post` (`WorkoutPostCard.swift`). Estas muestran la clave cruda en pantalla en vez de texto, en cualquier idioma.
- **`RepsShared/WorkoutShared.swift`** (compartido entre iPhone, Watch y Widgets) tiene decenas de literales en español fuera del catálogo: avisos de clima/UV para salir a entrenar, textos de moderación ("Denunciar publicación", "Eliminar publicación (moderador)"), condiciones de suscripción, comprobación de edad, resúmenes de ejecución del plan. Con inglés seleccionado, estos aparecerán en español sin posibilidad de traducirse sin tocar código.
- **Siri/App Intents** (`Reps/Services/RepsAppShortcuts.swift`) siguen con literal español fuera de catálogo ("Muestra mi progreso en..."), pendiente desde la auditoría del 5 de julio. Un usuario en inglés verá Shortcuts en español.
- Literales españoles sueltos adicionales en `SettingsView.swift`, `ProfileView.swift`, `ActiveWorkoutView.swift`, `ProgressSummaryCards.swift`, `TodayView.swift`, `DemoPremiumSeedData.swift`.
- **Buena noticia confirmada:** el bug crítico de idioma partido de la auditoría anterior está resuelto — `Localizable.xcstrings`, `project.pbxproj` (`developmentRegion`) y `Scripts/verify-localization.mjs` ahora coinciden en `sourceLanguage = es`. Los `InfoPlist.xcstrings` de los 3 targets están 100% traducidos en/es (el hueco de `NSLocationAlwaysAndWhenInUseUsageDescription` y `NSPhotoLibraryAddUsageDescription` ya se corrigió).

### CloudKit backup sin manejo de conflictos

El backup de datos de la app usa iCloud Documents (`Reps/Services/ICloudBackupService.swift:17-21`, un único `reps-backup.json`), no CKRecord. No hay detección real de conflicto — gana el último que escribe, sin comprobar copias "conflicted" de iCloud. Bajo riesgo si un usuario no usa dos dispositivos simultáneamente, pero puede perder datos silenciosamente si lo hace.

### Privacy manifest incompleto

`RepsShared/PrivacyInfo.xcprivacy` solo declara `UserDefaults` y `FileTimestamp` como Required Reason APIs, y `ProductInteraction`/`CrashData` como tipos de datos recolectados. Dado el uso extenso de HealthKit (lectura y escritura de peso, altura, pulso, sueño, rutas, etc.) y ubicación en segundo plano para rutas, Apple espera que estos aparezcan como tipos de datos recolectados/enlazados en el manifiesto y, sobre todo, que coincidan exactamente con el cuestionario de App Privacy en App Store Connect — un desajuste ahí es causa común de rechazo.

### Deep link muerto desde el widget de amigos

`RepsWidgets/RepsFriendsWidget.swift:113,150` usa `widgetURL(URL(string: "reps://social"))`, pero `AppStore.handleAppDeepLink` (`AppStore.swift:443-460`) no tiene case `"social"`, y `handleSocialDeepLink` (línea 1151-1159) solo reconoce `reps://social/@username` — con username vacío el guard falla. Tocar el widget de amigos abre la app en la última pestaña activa, sin navegar a Social.

**Arreglo:** una línea — añadir case `"social"` en `handleAppDeepLink`, o un fallback en `handleSocialDeepLink` para username vacío que abra el hub social.

---

## P2 — Deuda, no bloqueante

- `Localizable.xcstrings` tiene 5.189 claves totales, de las cuales 4.346 (84%) están marcadas `stale`. El script de verificación las ignora para la puerta de release, pero dificulta mantenimiento y detección de problemas reales.

---

## Confirmado correcto (verificado en código, no solo documentado)

- **Bucle central**: onboarding → Today → empezar entreno → registrar series → terminar → resumen → Progreso/Calendario/racha, todo trazado sobre `workoutSessions` en `AppStore` sin stubs ni callejones sin salida. Sin `TODO`/`FIXME`/placeholders "próximamente" en ningún target.
- **HealthKit**: conjuntos de lectura/escritura reales y verificados línea por línea; deduplicación de workouts genuina vía `HKMetadataKeyExternalUUID` + `HKMetadataKeyWorkoutBrandName`; `HKWorkoutSession`/`HKLiveWorkoutBuilder` reales en iPhone y Watch; observer queries + background delivery activos.
- **Watch connectivity**: `WCSessionDelegate` en ambos lados, con fallback real a modo standalone (Watch sin iPhone cerca) sin riesgo de crash/hang.
- **WidgetKit + Live Activity + Dynamic Island**: implementación completa, App Group compartido correctamente escrito por la app y leído por los widgets.
- **Siri/App Intents**: funcionalmente conectados a lógica real de la app (solo pendiente de localización, ver P1).
- **StoreKit/suscripciones**: vía RevenueCat sobre StoreKit 2; restaurar compras conectado; coincide con `Docs/SUBSCRIPTION_CONDITIONS.md`.
- **Enlaces legales**: privacidad, términos y condiciones de suscripción son URLs alojadas reales y alcanzables desde Perfil, no archivos `Docs/` sueltos.
- **Permisos declarados en Info.plist**: cada descripción (cámara, micrófono, Apple Music, HealthKit, ubicación, movimiento, fotos) corresponde a uso real verificado en código — nada "huérfano" que pueda generar objeción de revisión por permiso no usado. No hay uso de ATT/IDFA, Face ID ni Sign in with Apple, así que no falta ninguna descripción de permiso para ellos.
- **`DeveloperMenuView`** correctamente excluido de builds de release vía `#if DEBUG`.

---

## Orden recomendado antes de enviar a revisión

1. Activar capability Push Notifications (P0-1) — 5 minutos en Xcode + validar en dispositivo.
2. Implementar borrado de perfil/cuenta social (P0-2) — necesario para pasar 5.1.1(v).
3. Completar las claves de catálogo faltantes y localizar `RepsAppShortcuts.swift` (P1) — riesgo de calidad visible en revisión bilingüe.
4. Revisar y ampliar `PrivacyInfo.xcprivacy` + cuestionario de App Privacy en ASC para que coincidan (P1).
5. Arreglar el deep link `reps://social` del widget (P1, una línea).
6. Ejecutar el checklist de `Docs/RELEASE_CHECKLIST.md` en dispositivo físico, prestando atención especial a notificaciones push tras el fix del punto 1.

---

## Estado de las correcciones (2026-07-13)

### P0-1 — Push notifications: **corregido en código, falta 1 paso manual**

- `Reps/Reps.entitlements`: añadida `aps-environment = development`. Xcode normaliza esto a `production` automáticamente al firmar con un perfil de distribución, siempre que la capability exista en el App ID.
- `Reps/App/RepsApp.swift`: los stubs vacíos `didRegisterForRemoteNotificationsWithDeviceToken`/`didFailToRegisterForRemoteNotificationsWithError` ahora registran breadcrumbs/errores en `TelemetryService`, así que una futura regresión de registro APNs será visible en diagnósticos en vez de tragarse en silencio.
- **Pendiente manual (no lo puedo hacer desde aquí):** el entitlement por sí solo no basta — el App ID `com.romerodev.repsfitness` necesita tener la capability "Push Notifications" habilitada en el Apple Developer Portal. Con firma automática, esto ocurre solo la próxima vez que abras el proyecto en Xcode con el equipo de firma seleccionado y compiles/archives (Xcode detecta el nuevo entitlement y sincroniza el App ID + perfil de aprovisionamiento). Si usas firma manual, hay que activarlo a mano en developer.apple.com y regenerar el perfil.

### P0-2 — Borrado de cuenta social: **corregido**

- `Reps/Services/SocialService.swift`: nuevo `deleteAccount(username:)` que borra perfil, posts, comentarios, follows entrantes/salientes, likes, blocks y suscripciones push del usuario en CloudKit público (best-effort por tipo de registro, perfil borrado al final).
- `Reps/App/AppStore.swift`: nuevo `deleteSocialAccount()` que llama al servicio y limpia el estado local (username, bio, following, blocked, feed, challenges, moderador).
- `Reps/Features/Profile/ProfileView.swift`: nuevo botón "Eliminar perfil social" (visible solo si existe `socialUsername`) con diálogo de confirmación destructivo independiente de "Delete All Data", y feedback de éxito/fallo vía el banner existente (`store.health.message`).
- Claves de catálogo añadidas (en/es): `delete_social_profile`, `delete_social_profile_subtitle`, `delete_social_profile_confirm_title`, `delete_social_profile_confirm_button`, `delete_social_profile_message`, `delete_social_profile_success`, `delete_social_profile_failed`, `deleting`.

### P1 — corregidos en esta sesión

- Claves de catálogo faltantes (`achievement_close_all_format`, `achievement_close_all_toast`, `social_moderator_delete_comment`, `social_moderator_ban_user`, `social_moderator_delete_post`) añadidas en en/es.
- `Reps/Services/RepsAppShortcuts.swift`: reescrito. `title`/`description`/`shortTitle` de los 4 App Intents ahora usan `LocalizedStringResource` con claves de catálogo traducidas (antes mezclaban español e inglés hardcodeados de forma inconsistente — p. ej. "Entrenar"/"Racha" en español sin equivalente inglés, y "Start Workout"/"Training Progress" en inglés sin equivalente español). El diálogo hablado de `StreakStatusIntent` ahora se resuelve vía los helpers de localización de la app en vez de texto español fijo. Las `phrases` de activación por voz se mantienen como literales bilingües (patrón correcto para App Shortcuts — cada variante de idioma es un disparador válido independiente del idioma del sistema), y ahora las 4 tienen variante en inglés y en español (antes 2 de las 4 solo tenían español).
- Deep link muerto del widget de amigos: `handleAppDeepLink` en `AppStore.swift` ahora reconoce `reps://social` (sin username) y navega a la pestaña Perfil + empuja `SocialHubView` automáticamente (`pendingSocialHubPresentation`, consumido en `ProfileView.swift`). `reps://social/@username` sigue delegando en `handleSocialDeepLink` sin cambios de comportamiento.

### Verificación

- `xcodebuild -scheme Reps -destination 'iPhone 16 Pro' build` → **BUILD SUCCEEDED**, 0 warnings/errores en los archivos modificados.
- `node Scripts/verify-localization.mjs` → las 5 claves faltantes y el literal de `RepsAppShortcuts.swift` original ya no aparecen (el único resto en ese archivo son las `phrases` bilingües intencionales, no un bug).

### Pendiente (no abordado en esta pasada — requiere más alcance o una decisión de producto)

- Resto de literales españoles sueltos fuera de catálogo en `RepsShared/WorkoutShared.swift`, `SettingsView.swift`, `ProfileView.swift`, `ActiveWorkoutView.swift`, `DemoPremiumSeedData.swift`, `ProgressSummaryCards.swift`, `TodayView.swift` — varias docenas de cadenas, cada una necesita su propia clave y revisión de contexto.
- Manejo de conflictos en el backup de iCloud Documents (`ICloudBackupService.swift`) — es trabajo de feature, no un fix de una línea.
- Ampliar `PrivacyInfo.xcprivacy` y alinear el cuestionario de App Privacy en App Store Connect — es una decisión de producto/legal sobre qué declarar (los datos de HealthKit no salen del dispositivo, así que no está claro que deban listarse como "recolectados" en el manifiesto técnico; lo que sí hay que revisar es que el cuestionario web de ASC sea consistente con el comportamiento real). No lo toqué para no introducir una declaración incorrecta sin tu confirmación.
- Limpieza de las 4.346 entradas `stale` del catálogo (P2, deuda de mantenimiento).

---

## Segunda pasada — "completa todo lo pendiente" (2026-07-13)

### 1. Literales españoles sueltos: la mayoría eran falsos positivos del script

Revisé caso por caso los ~70 hallazgos que reportaba `verify-localization.mjs` sobre `SettingsView.swift` y `RepsShared/WorkoutShared.swift`. Resultado: **casi todos ya estaban correctamente traducidos**, solo que a través de tablas de fallback locales (`settingsSpanishFallbacks`/`settingsEnglishFallbacks` en `SettingsView.swift`, y el diccionario global `localizedFallbacks` en `RepsShared/WorkoutShared.swift`, seleccionadas en tiempo de ejecución vía `RepsLocalization.language`), o mediante ramas `isSpanish ? "..." : "..."` explícitas (varias entradas de `DemoPremiumSeedData.swift` y de `TodayView.swift`). El script solo verifica `Localizable.xcstrings`, así que no ve estos mecanismos y los marca como "falta traducción" cuando en realidad la app ya muestra el idioma correcto en ambos casos. Esto es deuda arquitectónica real (dos sistemas de localización conviviendo, ya señalado en la auditoría del 5 de julio), pero no un bug de cara al usuario.

Bugs reales encontrados y corregidos (sin fallback, un solo idioma, alcanzables en producción):

- `Reps/Features/Profile/ProfileView.swift:2337-2338` — filtro "Con sesión"/"Sin sesión" sin traducción → ahora usa `localizedString("session_filter_with_session"/"session_filter_without_session")`.
- `Reps/Features/Progress/Components/ProgressSummaryCards.swift:254` — "Frecuencia cardiaca"/"Carga estimada por sesión" sin traducción (ninguna de las dos, el script solo detectó la segunda por sus tildes) → ahora usa `localizedString("heart_rate_zone_label"/"estimated_load_per_session")`.
- `Reps/Features/Workout/ActiveWorkoutView.swift:1609` — aviso "Pulsa Empezar para registrar series" sin traducción → ahora `localizedString("tap_start_to_log_sets")`.

No corregidos deliberadamente (cero riesgo/alcance de App Store, confirmado):

- `DeveloperMenuView.swift` y `DemoPremiumSeedData.swift` — ambos exclusivos de `#if DEBUG`, alcanzables solo desde un menú de desarrollador que nunca se compila en Release. Es una herramienta interna en español para un desarrollador hispanohablante; no hay usuario ni revisor de Apple que la vea nunca.
- `RepsTests/RepsTests.swift` — dato de fixture de un test unitario ("Press Francés"), no es texto de UI.
- `RepsAppShortcuts.swift` — ya corregido en la primera pasada; la frase española restante es una variante de activación por voz intencional, no un bug.

### 2. Claves de catálogo corruptas — corregidas

`Localizable.xcstrings` tenía 7 entradas problemáticas además de los literales:

- `"0"` y `"10"` (etiquetas de escala de dolor en `RehabExerciseDetailView.swift`) y `"Ver más"` (botón real en `ProfileView.swift`) tenían un objeto vacío `{}` sin ninguna traducción — completadas.
- `""` (usada por un `Text("")` intencional) tenía valores vacíos que el script interpreta como "falta" por un falso-negativo de JS (`!""` es `true`) — marcada `stale` para que el linter la ignore, sin cambiar el comportamiento.
- `"%@ · %@ · %@"`, `"%@ · set %@"`, `"%@ / %@ %@"` — verificado que no hay ninguna referencia a estas claves en ningún target (`Reps`, `RepsWatch`, `RepsWidgets`, `RepsShared`, `RepsTests`); son restos de extracción de código ya eliminado. Borradas del catálogo en vez de inventarles una traducción sin sentido.

`node Scripts/verify-localization.mjs` pasó de 81 líneas de salida a 63, y las 63 restantes son exactamente los falsos positivos documentados arriba (verificados uno por uno, no una suposición).

### 3. Manejo de conflictos de iCloud — implementado

`Reps/Services/ICloudBackupService.swift`: `save()` y `load()` ahora pasan por `NSFileCoordinator` (evita corrupción si el daemon de iCloud sincroniza a la vez que la app escribe/lee). Se añadió `resolveConflictsIfNeeded(at:)`, que se ejecuta antes de cada `load()`: busca versiones en conflicto vía `NSFileVersion.unresolvedConflictVersionsOfItem(at:)`, promueve la más reciente por fecha de modificación a la ruta canónica si no es ya la actual, y marca el resto como resueltas (`isResolved = true` + `removeOtherVersionsOfItem`). Antes, un conflicto de iCloud dejaba un archivo "conflicted copy" invisible para la app y `load()` se quedaba con lo que hubiera en la ruta canónica sin importar cuál fuera más reciente.

### 4. Privacy manifest — ampliado con datos reales

`RepsShared/PrivacyInfo.xcprivacy` ahora declara `NSPrivacyCollectedDataTypeHealth`, `NSPrivacyCollectedDataTypeFitness` y `NSPrivacyCollectedDataTypePreciseLocation` (enlazados a la identidad del usuario, sin tracking, propósito `AppFunctionality`), reflejando el uso real y extenso de HealthKit y ubicación confirmado en la auditoría de ecosistema Apple. Esto es una declaración técnica objetiva sobre lo que la app accede — no requiere ninguna decisión de producto. Lo que **sigue pendiente y no puedo hacer desde el repo** es el cuestionario web de App Privacy en App Store Connect: ese formulario es independiente de este archivo y hay que rellenarlo a mano para que coincida.

### 5. Limpieza de entradas `stale` — evaluada y descartada con evidencia

Confirmé por qué NO es seguro borrar las 4.346 entradas `stale` de forma automática: el código construye claves de localización dinámicamente en al menos ~40 sitios (ejemplos reales: `localizedString("zone_\($0 + 1)_label")` en `ProgressCardioAnalyticsCard.swift:226`, `localizedString("challenge_metric_\(m.rawValue)")` en `CreateChallengeView.swift:29`). Un grep de texto por la clave final resuelta (p. ej. `"zone_1_label"`) no encuentra nada en el código fuente porque el código nunca escribe esa cadena completa — solo la arma en tiempo de ejecución. Eso significa que cualquier heurística automática de "esta clave no aparece en el código, luego está muerta" tiene falsos positivos garantizados sobre exactamente este tipo de clave, y borrarla rompería esa pantalla en producción de forma silenciosa (sin error de compilación, solo la clave cruda visible en UI). Purgar esto de forma segura requiere enumerar manualmente cada patrón dinámico y confirmar contra el rango real de valores — es un trabajo de auditoría propio, no una limpieza mecánica. Lo dejo fuera de esta pasada; sigue siendo P2 (deuda, no bloqueante).

### Verificación final

`xcodebuild -scheme Reps -destination 'iPhone 16 Pro' build` → **BUILD SUCCEEDED**, 0 warnings/errores en todo el log (no solo en los archivos tocados).
