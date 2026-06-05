# Auditoria de localizacion - Reps

Fecha: 2026-06-05

## Veredicto

La app no esta FULL localizada en ingles y espanol usando String Catalogs.

Aunque el proyecto declara `en` y `es` como regiones conocidas y existe `Reps/Resources/Localizable.xcstrings`, la localizacion esta incompleta y mezclada con traducciones manuales en Swift. Hay riesgo alto de que usuarios en ingles vean textos en espanol, que widgets/watch no resuelvan traducciones, y que textos user-facing queden fuera del flujo de Xcode String Catalogs.

## Evidencia cuantitativa

Catalogo `Reps/Resources/Localizable.xcstrings`:

- `sourceLanguage`: `en`
- Claves totales: 516
- Claves con localizacion `en`: 31
- Claves con localizacion `es`: 252
- Claves sin localizacion `en`: 485
- Claves sin localizacion `es`: 264
- Claves `stale`: 245
- Estados `en`: 31 `new`, 485 missing
- Estados `es`: 252 `translated`, 264 missing
- Claves en espanol sin traduccion inglesa detectadas: 100+
- Claves con "traduccion" inglesa que sigue en espanol detectadas: 12+

Codigo Swift:

- Lineas con literales en espanol detectadas: 826
- Lineas con literales en espanol en contexto UI/API user-facing: 362
- Lineas con logica manual `preferredLanguage.hasPrefix("es")` o ternarios `isSpanish ?`: 199
- `String(localized:)` usado con texto fuente en espanol: 8 lineas

Targets:

- Solo hay un catalogo: `Reps/Resources/Localizable.xcstrings`
- El catalogo esta incluido en recursos del target principal `Reps`
- No aparece incluido en recursos de `RepsWidgets` ni `RepsWatch Watch App`

## Hallazgos criticos

### 1. El catalogo tiene fuente inglesa, pero muchas claves fuente estan en espanol

Archivo: `Reps/Resources/Localizable.xcstrings`

El catalogo declara:

```json
"sourceLanguage" : "en"
```

Pero hay claves fuente como:

- `¿Permitir a Reps conectarse a Spotify?`
- `¿Tienes un evento objetivo?`
- `%@ días por semana`
- `Cerrar`
- `Calculadora de Discos`

Con `sourceLanguage = en`, esas claves son tratadas como texto fuente ingles. Si no tienen una localizacion `en`, el usuario ingles vera directamente espanol. Esto invalida el requisito de app completamente localizada en ingles y espanol.

### 2. Cobertura incompleta del catalogo

Archivo: `Reps/Resources/Localizable.xcstrings`

La mitad del catalogo no tiene espanol y casi todo el catalogo no tiene localizacion inglesa explicita. Esto no seria grave si todas las claves fuente fueran ingles correcto, pero actualmente muchas son espanol. Ademas, 245 claves estan `stale`, lo que indica que el catalogo contiene entradas que Xcode ya no considera vigentes o que requieren limpieza/revision.

### 3. Widgets y watch app tienen textos localizables, pero el catalogo no esta en sus recursos

Archivos:

- `Reps.xcodeproj/project.pbxproj`
- `RepsWidgets/RepsWorkoutWidget.swift`
- `RepsWidgets/RepsStreakWidget.swift`
- `RepsWidgets/RepsBatteryWidget.swift`
- `RepsWatch/WatchWorkoutView.swift`
- `RepsShared/RepsWidgetConfigurationIntent.swift`

El `pbxproj` incluye `Localizable.xcstrings in Resources` solo en el build phase de recursos del target principal. Los targets `RepsWidgets` y `RepsWatch Watch App` no incluyen ese recurso.

Ejemplos de textos afectados:

- `.configurationDisplayName("Reps Entrenamiento")`
- `.description("Entreno activo, progreso, calorías y estado físico.")`
- `Text("Serie hecha")`
- `Text("Sin sesión activa")`
- `LocalizedStringResource = "Configuración del Widget"`
- `DisplayRepresentation(stringLiteral: "Azul")`

### 4. Hay un sistema paralelo de localizacion manual fuera de String Catalogs

Archivos representativos:

- `Reps/App/RepsApp.swift`
- `Reps/Models/Models.swift`
- `Reps/DesignSystem/PulseTheme.swift`
- `Reps/Features/Today/TodayView.swift`
- `Reps/Features/Exercises/ExerciseLibraryView.swift`
- `Reps/DesignSystem/QuickMenuProgressionChart.swift`

La app fuerza el locale desde estado interno:

```swift
.environment(\.locale, Locale(identifier: store.userProfile.preferredLanguage))
```

Y el perfil arranca con:

```swift
var preferredLanguage = "es"
```

Tambien existen funciones como `RepsText.exerciseName(_:language:)`, `RepsText.muscle(_:language:)`, `RepsText.equipment(_:language:)` y muchos ternarios `isSpanish ? "..." : "..."`.

Esto no cumple el requisito de usar catalogos para traducciones: parte de la UI puede cambiar de idioma, pero no esta en `Localizable.xcstrings`, no tiene estados de traduccion, no se exporta/importa con Xcode y no se puede auditar desde el catalogo.

### 5. Literales user-facing en servicios/modelos no estan localizados correctamente

Archivos representativos:

- `Reps/Services/PermissionService.swift`
- `Reps/Models/Models.swift`
- `RepsShared/WorkoutShared.swift`
- `Reps/App/AppStore.swift`

Ejemplos:

- `El micrófono está bloqueado. Actívalo en Ajustes -> Reps -> Micrófono.`
- `Sin entreno activo`
- `Cargada`
- `Buen momento para entrenar.`
- `Entrenamiento libre`
- `Sin plan activo`

Los modelos y snapshots compartidos almacenan textos ya localizados en espanol. Para una app bilingue, los datos persistidos/compartidos deberian guardar codigos o valores canonicos, y resolver texto localizado en el borde UI con `String(localized:)` o `LocalizedStringResource`.

### 6. Info.plist contiene permisos en espanol sin localizacion por idioma

Archivos:

- `Reps/Info.plist`
- `RepsWatch/Info.plist`

Ejemplos:

- `NSCameraUsageDescription`
- `NSMicrophoneUsageDescription`
- `NSHealthShareUsageDescription`
- `NSHealthUpdateUsageDescription`
- `NSLocationWhenInUseUsageDescription`

No hay `InfoPlist.xcstrings`, `InfoPlist.strings`, ni carpetas `.lproj`. En ingles, los prompts de permisos del sistema apareceran en espanol.

## Ficheros con mayor deuda de localizacion

Ranking por literales espanoles y logica manual de idioma:

| Fichero | Literales ES | UI ES | Ternarios/manual |
| --- | ---: | ---: | ---: |
| `Reps/Features/Profile/ProfileView.swift` | 120 | 66 | 11 |
| `Reps/Features/Plans/PlansView.swift` | 82 | 48 | 2 |
| `Reps/Features/Exercises/ExerciseLibraryView.swift` | 53 | 26 | 25 |
| `Reps/Features/Onboarding/ProfileSetupView.swift` | 82 | 18 | 0 |
| `Reps/Features/Today/TodayView.swift` | 30 | 8 | 52 |
| `Reps/Features/Workout/ActiveWorkoutView.swift` | 50 | 35 | 0 |
| `Reps/Features/Today/TrainingBatteryView.swift` | 29 | 11 | 38 |
| `RepsWatch/WatchWorkoutView.swift` | 28 | 12 | 0 |
| `RepsWidgets/RepsWorkoutWidget.swift` | 17 | 14 | 0 |

## Recomendacion de remediacion

1. Elegir una estrategia unica de idioma fuente.
   - Recomendado: mantener `sourceLanguage = en`.
   - Convertir todas las claves fuente a ingles.
   - Mover el espanol a `localizations.es`.

2. Hacer que todos los textos user-facing pasen por String Catalogs.
   - SwiftUI: literales directos en `Text`, `Button`, `Label`, `Toggle`, `Picker`, `Section`, `.navigationTitle`, etc.
   - Servicios/view models: `String(localized:)`.
   - Widgets/App Intents: `LocalizedStringResource`.
   - Evitar `isSpanish ? ... : ...` y helpers manuales tipo `RepsText` para texto visible.

3. Incluir catalogos en todos los targets que renderizan UI.
   - `Reps`
   - `RepsWidgets`
   - `RepsWatch Watch App`

4. Localizar permisos y metadata del sistema.
   - Crear `InfoPlist.xcstrings` o recursos equivalentes para `en` y `es`.
   - Cubrir todos los `NS*UsageDescription` y nombres de bundle si aplica.

5. Sacar textos localizados de modelos persistidos/snapshots.
   - Persistir IDs, enums o claves canonicas.
   - Resolver el idioma en la vista o capa de presentacion.

6. Limpiar el catalogo.
   - Eliminar o revisar las 245 claves `stale`.
   - Completar `en` y `es`.
   - Revisar placeholders y pluralizacion en `.xcstrings`.
   - Convertir cadenas con conteos (`%@ series`, `%@ ejercicios`, `días`) a plural forms reales.

7. Anadir verificacion automatica.
   - Script CI que falle si hay literales espanoles user-facing fuera de `.xcstrings`.
   - Script que falle si faltan localizaciones `en` o `es`.
   - Pruebas UI o snapshots lanzando la app con `-AppleLanguages (en)` y `-AppleLanguages (es)`.

## Estado final de auditoria

No cumple el criterio "FULL localizada en ingles y espanol usando archivos catalogos".

Bloqueadores principales:

- Catalogo con fuente `en` pero claves en espanol.
- Cobertura incompleta de `en` y `es`.
- Widgets/watch sin catalogo como recurso.
- Traducciones manuales dispersas en Swift.
- Info.plist sin localizacion por idioma.
