# Auditoria profunda de localizacion - Reps

Fecha: 2026-07-05

## Veredicto

La localizacion no es consistente ni fiable. La app puede mostrar claves sin resolver, textos en espanol con ingles seleccionado, textos en ingles con espanol seleccionado y contenido mezclado dentro de una misma pantalla.

El problema no es una unica traduccion faltante. Hay cuatro causas raiz:

1. Estrategia de idioma fuente incoherente entre proyecto, catalogos y script de verificacion.
2. Catalogo principal sobredimensionado y contaminado por entradas `stale`, fragmentos de codigo y claves no user-facing.
3. Dos sistemas de localizacion conviviendo: String Catalogs y switches/estado manual por `preferredLanguage`.
4. Textos resueltos demasiado pronto o fuera del borde UI, especialmente en App Intents, Watch/widgets, modelos compartidos, snapshots y formateadores.

## Evidencia cuantitativa actual

### Reps/Resources/Localizable.xcstrings

- `sourceLanguage`: `en`
- Entradas totales: 7.070
- Entradas `stale`: 6.408
- Claves sin `en`: 68
- Claves sin `es`: 75
- Entradas `en` con estado distinto de `translated`: 7
- Claves que parecen estar en espanol aunque el catalogo declara fuente inglesa: 992
- Valores ingleses que todavia parecen contener espanol: 46
- Valores espanoles iguales al ingles o probablemente no traducidos: 2.679
- Claves vacias o no user-facing detectadas: al menos 2 directas, mas muchas de puntuacion/formato.

Ejemplos de contaminacion:

- Claves espanolas como `¡Excelente constancia!`, `¿Cuál es tu objetivo principal?`, `¿Permitir a Reps conectarse a Spotify?`.
- Fragmentos de codigo o interpolaciones como `) : (isSpanish ? `, `\\(store.displayedWeight.unit)`, `\\($0.exercise.name): \\($0.notes)`.
- Separadores o formatos como `—`, `·`, `%@`, `/%@`, `%.0f kg`, varios sin `en` o sin `es`.

### InfoPlist

- `Reps/Resources/InfoPlist.xcstrings`: `sourceLanguage = es`, 12 claves.
- Faltan traducciones inglesas para:
  - `NSLocationAlwaysAndWhenInUseUsageDescription`
  - `NSPhotoLibraryAddUsageDescription`
- Esas dos entradas estan en estado `new` en espanol.
- `RepsWidgets/InfoPlist.xcstrings`: completo para las 2 claves existentes.
- `RepsWatch/InfoPlist.xcstrings`: completo para las 6 claves existentes.

### Codigo Swift

- Usos de `localizedString(...)`: 1.648
- Usos de `localizedFormat(...)`: 233
- Usos directos de `String(localized:)`: 4
- Usos de `LocalizedStringResource`: 10
- Usos de `Text(verbatim:)`: 25
- Usos de `NSLocalizedString`: 0
- Senales de logica manual por idioma (`preferredLanguage`, `hasPrefix("es")`, `isSpanish`): 107
- Literales espanoles detectados en Swift: 162
- Literales espanoles no presentes como clave en el catalogo principal: 27

Archivos con mayor deuda detectada:

- `Reps/DesignSystem/PulseTheme.swift`
- `Reps/Services/FitnessMetrics.swift`
- `Reps/Features/Exercises/ExerciseLibraryView.swift`
- `Reps/Features/Workout/ActiveWorkoutView.swift`
- `Reps/Features/Progress/Components/ProgressSummaryCards.swift`
- `Reps/Services/RepsAppShortcuts.swift`
- `RepsWatch/WatchWorkoutView.swift`

## Hallazgos criticos

### 1. El idioma fuente esta partido entre `en` y `es`

El catalogo principal declara `sourceLanguage = en` en `Reps/Resources/Localizable.xcstrings:2`.

Pero el proyecto declara `developmentRegion = es` en `Reps.xcodeproj/project.pbxproj:970`, los catalogos InfoPlist declaran `sourceLanguage = es`, y el script `Scripts/verify-localization.mjs:76-79` espera que todos los catalogos tengan `sourceLanguage = es`.

Esto hace que no haya una verdad unica para responder: "si falta una traduccion, cual idioma debe verse como fallback?". En la practica, unas rutas caen a ingles, otras a espanol y otras muestran la clave.

### 2. El catalogo principal esta dominado por entradas `stale`

6.408 de 7.070 entradas estan `stale`. Eso significa que el catalogo ya no refleja limpiamente el codigo actual.

Ademas, hay claves que nunca deberian ser traducibles: puntuacion, numeros, ids, URLs, fragmentos de interpolacion, CSV de ejemplo y expresiones internas. Este ruido hace dificil detectar lo importante y puede provocar que Xcode resuelva claves inesperadas.

### 3. Se fuerza espanol como idioma activo por defecto

`RepsShared/WorkoutShared.swift:17` inicia `RepsLocalization.activeLanguage` en `"es"`.

`Reps/Models/Models.swift:58-63` hace que instalaciones nuevas usen `UserProfile.deviceDefaultLanguage`, que devuelve `"es"`.

`Reps/App/RepsApp.swift:140-143` inyecta el locale de SwiftUI y actualiza `RepsLocalization` desde `store.userProfile.preferredLanguage`.

Esto implica que la app no sigue automaticamente el idioma del sistema en instalaciones nuevas. Si el usuario espera ingles por dispositivo, parte de la app ya nace en espanol antes de que intervenga el selector.

### 4. Conviven String Catalogs y traducciones manuales

`Reps/DesignSystem/PulseTheme.swift:763-863` contiene `RepsText`, con switches manuales para ejercicios, musculos y equipamiento. `Reps/Features/Exercises/ExerciseLibraryView.swift:404-456` duplica parte de esa logica en `ExerciseTextLocalizer`.

Estos textos no se gestionan como String Catalogs, no tienen estados de traduccion, no se exportan para revision, no cubren pluralizacion y no comparten reglas de fallback con `localizedString`.

### 5. App Intents siguen con literales espanoles

`Reps/Services/RepsAppShortcuts.swift:9-55` contiene titulos, descripciones, frases y dialogos en espanol directamente:

- `Empezar entreno libre`
- `Consultar racha`
- `Llevas ... días de racha`
- `Empieza un entreno en ...`

En App Intents se deberia usar `LocalizedStringResource` con claves canonicas y traducciones completas, no frases espanolas incrustadas.

### 6. Hay textos espanoles fuera del catalogo

Ejemplos detectados:

- `Reps/Features/Progress/Components/ProgressSummaryCards.swift:25`: `Configura Health o registra una sesión`
- `Reps/Features/Progress/Components/ProgressSummaryCards.swift:28`: `Sesión registrada hoy`
- `Reps/Features/Workout/ActiveWorkoutExerciseOrderComponents.swift:95`: `Eliminar ejercicio`
- `Reps/Features/Workout/Components/ActiveWorkoutSetListComponents.swift:78`: `¿Eliminar serie?`
- `RepsWatch/WatchWorkoutView.swift:1379`: `Añadir 250 ml de agua`

Si estos literales llegan a UI, no se pueden traducir al ingles salvo que el codigo cambie.

### 7. Algunas fechas y numeros no son plenamente locale-aware

Hay uso frecuente de `DateFormatter.dateFormat` y `String(format:)`. Algunos son tecnicos, pero otros son user-facing.

Ejemplos:

- `Reps/Features/Progress/WorkoutHistoryView.swift:92-95` fuerza `Locale(identifier: "es")` para agrupar meses.
- `Reps/DesignSystem/WorkoutReceiptView.swift:193-201` usa formatos fijos `dd MMM yyyy` y `HH:mm`, y toma `en_us` desde el catalogo.

Esto puede producir meses en espanol con ingles seleccionado o formatos horarios no esperados por el usuario.

### 8. El verificador existe, pero no representa un contrato estable

`Scripts/verify-localization.mjs` falla actualmente porque espera `sourceLanguage = es` mientras `Localizable.xcstrings` tiene `en`.

Tambien valida que todo literal espanol este presente como clave, pero no distingue bien texto user-facing de datos, fixtures, filtros, identificadores o contenido tecnico. Es util como senal, pero aun no es una puerta de calidad fiable.

## Plan integral de correccion

### Fase 0 - Congelar criterio de localizacion

Decidir una estrategia y aplicarla a todos los targets:

- Opcion recomendada para esta app: `sourceLanguage = es`, porque el proyecto ya tiene `developmentRegion = es`, los InfoPlist ya estan en `es`, el script espera `es` y gran parte del copy actual nacio en espanol.
- Alternativa valida: migrar todo a `sourceLanguage = en`, pero exige reescribir claves fuente espanolas y cambiar proyecto/script/InfoPlist.

Resultado esperado:

- `developmentRegion`, todos los `.xcstrings`, verificadores y defaults de app quedan alineados.
- Se documenta la politica: idioma fuente, idiomas soportados, fallback, y si la app debe seguir idioma del sistema o preferencia interna.

### Fase 1 - Corregir fallos visibles de mayor impacto

1. Completar `InfoPlist.xcstrings` del target principal:
   - `NSLocationAlwaysAndWhenInUseUsageDescription`
   - `NSPhotoLibraryAddUsageDescription`
2. Localizar App Intents en `Reps/Services/RepsAppShortcuts.swift`.
3. Eliminar `Locale(identifier: "es")` en vistas user-facing.
4. Revisar `Text(verbatim:)`: conservarlo solo para usernames, codigos, unidades tecnicas o contenido que no debe traducirse.
5. Cambiar literales espanoles fuera del catalogo por claves localizadas.

### Fase 2 - Sanear `Localizable.xcstrings`

1. Eliminar entradas `stale` tras una pasada de extraccion limpia en Xcode.
2. Eliminar claves no user-facing:
   - puntuacion suelta
   - numeros
   - URLs
   - fragmentos de codigo
   - formatos internos
   - snapshots/fixtures
3. Completar `en` y `es` para todas las claves activas.
4. Revisar placeholders: todas las traducciones deben conservar tipos, orden y cantidad de placeholders.
5. Convertir conteos a pluralizacion real en String Catalogs:
   - series
   - ejercicios
   - dias
   - sesiones
   - calorias si aplica

### Fase 3 - Unificar la API interna de localizacion

Crear una capa pequena y unica:

- `L10n.string(_ key: L10nKey, ...)`
- `L10n.resource(_ key: L10nKey)` para App Intents, widgets y APIs que resuelven tarde.
- `L10n.format(_ key: L10nKey, _ args...)` solo donde no encaje interpolacion tipada.

Reglas:

- SwiftUI: `Text(localizedStringKey)` o `Text(L10n.string(...))` segun contexto, evitando `Text(verbatim:)` salvo contenido literal real.
- Servicios/view models: devolver claves o datos canonicos; resolver texto en la capa de presentacion.
- App Intents/widgets: `LocalizedStringResource`, no `String` ya resuelto.

### Fase 4 - Sacar traducciones de modelos y snapshots

Los modelos deben guardar valores canonicos, no texto traducido:

- Ejercicio: id canonico + nombre fuente.
- Musculo/equipamiento: enum/id canonico.
- Estado de entrenamiento: enum/id.
- Snapshot widget/watch: datos y claves, no frases finales salvo que el target vaya a resolver con el bundle correcto.

Migrar `RepsText` y `ExerciseTextLocalizer` a claves de catalogo, por ejemplo:

- `exercise.barbell_bench_press.name`
- `muscle.chest`
- `equipment.dumbbells`
- `workout.push_day.title`

### Fase 5 - Formato locale-aware

Reemplazar formatos user-facing:

- Fechas: `date.formatted(.dateTime...)` o `Text(date, format:)`.
- Numeros: `.formatted(.number...)`.
- Moneda: `.formatted(.currency(code: ...))`.
- Medidas: `Measurement` + `.formatted(.measurement(...))` cuando haya distancia, peso, volumen o temperatura.

Mantener `String(format:)` solo para:

- identificadores tecnicos
- hashes
- formatos de archivo
- tiempos deportivos tipo pace si se decide conservarlos como formato de dominio

### Fase 6 - Automatizar calidad

Actualizar `Scripts/verify-localization.mjs` para que falle por:

- `sourceLanguage` distinto del criterio elegido.
- claves activas sin `en` o sin `es`.
- estados `new` o `needs_review` en release.
- `stale` por encima de un umbral temporal, idealmente 0.
- literales espanoles user-facing fuera de catalogos.
- valores ingleses que contienen senales espanolas.
- placeholders incompatibles entre idiomas.
- App Intents con literales user-facing.

Anadir una comprobacion separada para no mezclar ruido:

- `verify-localization-catalog.mjs`
- `verify-localization-swift-literals.mjs`
- `verify-localization-placeholders.mjs`

### Fase 7 - Pruebas funcionales de idioma

Crear pruebas o ejecuciones de smoke:

1. App iOS con `-AppleLanguages (en)` y usuario `preferredLanguage = en`.
2. App iOS con `-AppleLanguages (es)` y usuario `preferredLanguage = es`.
3. Cambio de idioma dentro de Settings sin reinstalar.
4. Widget extension en ambos idiomas.
5. Watch app en ambos idiomas.
6. App Intents/Shortcuts en ambos idiomas.
7. Permisos del sistema en ambos idiomas.

Checklist visual minimo:

- Today
- Workout activo
- Biblioteca de ejercicios
- Historial/progreso
- Perfil/settings
- Paywall
- Watch workout
- Widgets

## Orden recomendado de ejecucion

1. Alinear idioma fuente: decidir `es` o `en` y corregir `Localizable.xcstrings`, `project.pbxproj`, InfoPlist y script.
2. Corregir InfoPlist faltante y App Intents.
3. Limpiar literales espanoles fuera del catalogo en las pantallas principales.
4. Sanear catalogo: borrar `stale` y no user-facing.
5. Migrar `RepsText`/`ExerciseTextLocalizer` a claves canonicas.
6. Corregir fechas/numeros user-facing.
7. Endurecer scripts y meterlos en CI.
8. Ejecutar smoke tests en iOS, Watch, widgets e intents.

## Criterio de aceptacion

La localizacion se considera estable cuando:

- El catalogo activo tiene 0 claves activas sin `en` o sin `es`.
- No quedan estados `new`/`needs_review` para release.
- No quedan entradas `stale` relevantes.
- El idioma fuente es el mismo en proyecto, catalogos y scripts.
- No hay literales espanoles user-facing fuera de catalogos.
- `preferredLanguage = en` no muestra copy espanol salvo nombres propios o contenido del usuario.
- `preferredLanguage = es` no muestra copy ingles salvo nombres propios, siglas, marcas o contenido tecnico decidido.
- Widgets, Watch, App Intents y permisos del sistema pasan el mismo smoke test bilingue.
