# Auditoria de rendimiento de StreakReps

Fecha: 2026-07-09  
Estado: auditoria estatica + build Debug de simulador correcta. No se ha ejecutado Instruments ni profiling en dispositivo real.

## Resumen ejecutivo

StreakReps ya contiene una arquitectura funcional amplia: entrenamiento activo, HealthKit, Watch, widgets, Live Activities, RevenueCat, CloudKit social, iCloud backup, planes, progreso, calendario, logros y gamificacion. El mayor riesgo de rendimiento no es una pantalla aislada, sino la combinacion de:

- `AppStore` como estado global `@Observable @MainActor` con muchas colecciones de dominio mutables.
- Persistencia SwiftData basada en snapshots/reconciliacion, ejecutada desde main actor.
- Dashboards SwiftUI que calculan filtros, agrupaciones, tendencias y graficos desde computed properties leidas por `body`.
- Entrenamiento activo que muta `activeWorkoutDrafts` en el store global para cada interaccion sensible.

El proyecto compila correctamente con XcodeBuildMCP en simulador iPhone 17 Pro, Debug, esquema `Reps`. Esto valida salud de build, no rendimiento runtime.

## Arquitectura detectada

- App principal: [RepsApp.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/App/RepsApp.swift:145), [RootView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/App/RootView.swift:67).
- Estado global: [AppStore.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/App/AppStore.swift:11), `@Observable @MainActor`.
- Persistencia: [SwiftDataPersistence.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Persistence/SwiftDataPersistence.swift:25), SwiftData sin CloudKit (`cloudKitDatabase: .none`).
- Modelos persistidos: [SwiftDataModels.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Persistence/SwiftDataModels.swift:1).
- Pantallas centrales: [TodayView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Today/TodayView.swift:3), [ActiveWorkoutView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Workout/ActiveWorkoutView.swift:12), [ProgressView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Progress/ProgressView.swift:5), [ExerciseLibraryView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Exercises/ExerciseLibraryView.swift:7), [CalendarView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Calendar/CalendarView.swift:4).
- Integraciones: HealthKit en [HealthKitService.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Health/HealthKitService.swift:1), iCloud backup en [ICloudBackupService.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Services/ICloudBackupService.swift:3), RevenueCat en [Monetization.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Models/Monetization.swift:1), Watch en [WatchWorkoutModel.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/RepsWatch/WatchWorkoutModel.swift:78), Live Activity en [RepsWorkoutLiveActivity.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/RepsWidgets/RepsWorkoutLiveActivity.swift:4).

## Separacion de evidencia

Confirmado por evidencia en codigo:

- `AppStore` concentra arrays de sesiones, ejercicios, planes, salud, objetivos, social y estado de workout, con `didSet` persistente en muchas propiedades ([AppStore.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/App/AppStore.swift:45)).
- `activeWorkoutDrafts` se persiste en scope `.profile` en cada cambio ([AppStore.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/App/AppStore.swift:106)).
- SwiftData guarda snapshots por scope en main actor y compara cambios mediante JSON encoding ([SwiftDataPersistence.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Persistence/SwiftDataPersistence.swift:163), [SwiftDataPersistence.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Persistence/SwiftDataPersistence.swift:332)).
- `ProgressDashboardView`, `TodayView`, `CalendarView` y `ExerciseLibraryView` derivan colecciones y metricas desde computed properties en el camino de render.

Problemas probables que requieren medicion:

- Hitches al completar sets cuando la sesion tiene muchos ejercicios o historial grande.
- Entrada a Progreso/Hoy con historial denso.
- Foreground tras HealthKit sync si coincide con reconstruccion de dashboards.
- Escrituras SwiftData perceptibles en background flush o al finalizar workout con imagen de recibo.

Hipotesis pendiente de validacion:

- En dispositivo antiguo, los graficos de Progreso y MuscleMap podrian ser el principal coste visible, por encima de la persistencia.
- El `TabView` con `.id(UUID())` puede ser percibido como reset util, pero puede penalizar retencion de scroll/estado.

## Hallazgos priorizados

### P1 - Estado global demasiado amplio en `AppStore`

Area: SwiftUI rendering / arquitectura de estado  
Archivo: [AppStore.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/App/AppStore.swift:45)  
Evidencia: colecciones grandes (`workoutSessions`, `exercises`, `health`, `goals`, `activeWorkoutDrafts`, social) viven en un unico `@Observable @MainActor`.

Impacto para usuario: cambios pequeños, como marcar una serie o actualizar salud, pueden invalidar vistas que leen el store global si sus dependencias no estan bien acotadas.  
Impacto tecnico: reduce localidad de cambios y hace dificil razonar que pantalla se recalcula.  
Propuesta: introducir stores/modelos de render por dominio (`WorkoutSessionStore`, `ProgressDashboardModel`, `ExerciseCatalogModel`, `ActiveWorkoutSessionModel`) sin migrar datos todavia. Mantener `AppStore` como orquestador y facade.  
Complejidad: alta.  
Riesgo: medio si se hace por fases; alto si se refactoriza de golpe.  
Validacion: SwiftUI Instrument para `Today`, `Progress`, `ActiveWorkout`; signposts al mutar `activeWorkoutDrafts` y al refrescar `health`.

### P1 - Persistencia SwiftData sigue en main actor y escala con colecciones

Area: SwiftData / main thread  
Archivo: [SwiftDataPersistence.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Persistence/SwiftDataPersistence.swift:25), [AppStore.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/App/AppStore.swift:3138)  
Evidencia: `SwiftDataPersistence` es `@MainActor`; `commitPendingSave()` llama `persistence.save(currentSnapshot, scopes:)`; reconciliacion hace fetch completo por tipo y comparacion JSON.

Impacto para usuario: riesgo de pausas al guardar sesiones, editar planes grandes, sincronizar biblioteca o flush en background.  
Impacto tecnico: el comentario ya reconoce que el borrado total previo bloqueaba main actor; la reconciliacion reduce impacto, pero no elimina fetch/encode/save en main actor.  
Propuesta: mover persistencia a actor dedicado con `ModelContainer` propio o cola serial, guardar deltas explicitos por entidad y persistir `activeWorkoutStatus` de forma ligera. Mantener migracion compatible.  
Complejidad: alta.  
Riesgo: alto por datos existentes; requiere tests de snapshot/migracion.  
Validacion: File Activity + Time Profiler + signposts `save(scope:)`, `commitPendingSave`, `context.save`.

### P1 - Progreso calcula demasiadas metricas durante render

Area: SwiftUI body cost / analytics  
Archivo: [ProgressView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Progress/ProgressView.swift:861), [ProgressView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Progress/ProgressView.swift:895), [ProgressView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Progress/ProgressView.swift:1071)  
Evidencia: `dailyVolumeSeries`, `heroMetrics`, `stepsWeekData`, `distanceWeekData`, `trendMetrics`, `competitiveSummary`, `workload`, `exercisesWithHistory` filtran, agrupan, ordenan y recorren sesiones/salud desde computed properties.

Impacto para usuario: entrada a Progreso y cambios de rango/seccion pueden sentirse pesados con historial real.  
Impacto tecnico: cada lectura de `body` puede repetir pipelines O(n) sobre historial.  
Propuesta: crear `ProgressDashboardRenderModel` con series precomputadas por rango (`week`, `month`, `year`), invalidado solo cuando cambian sesiones/salud/cardio/goals/range. Preparar series fuera del render path; usar signposts.  
Complejidad: media-alta.  
Riesgo: bajo si se mantienen modelos de dominio intactos.  
Validacion: SwiftUI Instrument y Time Profiler en escenarios: abrir Progreso, cambiar rango, abrir MuscleMap, abrir historico.

### P1 - Entrenamiento activo muta drafts globales en la ruta mas sensible

Area: active workout / fluidez de logging  
Archivo: [ActiveWorkoutView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Workout/ActiveWorkoutView.swift:73), [ActiveWorkoutView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Workout/ActiveWorkoutView.swift:1994), [ActiveWorkoutView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Workout/ActiveWorkoutView.swift:2182)  
Evidencia: `exerciseDrafts` es un proxy a `store.activeWorkoutDrafts`; bindings y operaciones de add/delete/move/set escriben en `store.activeWorkoutDrafts`.

Impacto para usuario: marcar repeticiones debe ser instantaneo; cualquier invalidacion o guardado percibido aqui reduce calidad central del producto.  
Impacto tecnico: el estado de interaccion de una pantalla hot path vive en store global y activa persistencia debounced.  
Propuesta: introducir `ActiveWorkoutSessionModel` local `@StateObject/@Observable`, publicar snapshots ligeros cada 5 s para Watch/Live Activity y commitear drafts al store solo en checkpoints, background y finish.  
Complejidad: alta.  
Riesgo: alto si se rompe recuperacion de workout activo; requiere tests para background, Watch, Live Activity y cierre inesperado.  
Validacion: UI test "start workout -> complete 20 sets -> background -> resume -> finish"; signposts tap-to-checkmark y persistence flush.

### P1 - Calendario recalcula por dia repetidamente

Area: calendario / listas  
Archivo: [CalendarView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Calendar/CalendarView.swift:78), [CalendarView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Calendar/CalendarView.swift:375)  
Evidencia: por cada celda se llama `loggedWorkouts(on:)`, `scheduledWorkouts(on:)`, `sessionVolumeKg(on:)` y `maxDayVolume`, cada una basada en filtros sobre arrays globales.

Impacto para usuario: cambiar mes o seleccionar dia puede degradarse con cientos de sesiones.  
Impacto tecnico: trabajo repetido O(dias * sesiones) en body.  
Propuesta: construir `CalendarMonthRenderModel` con diccionarios `[day: sessions]`, `[day: scheduled]`, `[day: volume]` al cambiar `visibleMonth`, `selectedDate` o data base.  
Complejidad: media.  
Riesgo: bajo.  
Validacion: Time Profiler al cambiar mes con dataset sintetico de 2 anos.

### P2 - Catalogo de ejercicios filtra y agrupa desde body

Area: exercise library / search  
Archivo: [ExerciseLibraryView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Exercises/ExerciseLibraryView.swift:35), [ExerciseLibraryView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Exercises/ExerciseLibraryView.swift:68), [ExerciseLibraryView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Exercises/ExerciseLibraryView.swift:257)  
Evidencia: `filteredExercises` y `groupedExercises` se recalculan en el render path. Hay una mitigacion ya presente: primero se aplican filtros baratos antes de construir el texto searchable.

Impacto para usuario: busqueda puede tener hitches con 800+ ejercicios y media.  
Impacto tecnico: trabajo repetido durante typing y cambios de filtros.  
Propuesta: cachear `ExerciseSearchIndex` por ejercicio; debounced search; render model agrupado por filtros.  
Complejidad: media.  
Riesgo: bajo.  
Validacion: medir typing latency y frame hitches en busqueda.

### P2 - Reset de pestañas mediante `.id(UUID())`

Area: navegacion / identidad SwiftUI  
Archivo: [RootView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/App/RootView.swift:77), [RootView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/App/RootView.swift:223)  
Evidencia: cada pestaña principal se renderiza con `.id(resetID)` y `reset(_:)` asigna UUID nuevo al tocar la pestaña activa.

Impacto para usuario: reset visible de scroll/estado y reconstruccion de pantallas grandes. Puede ser util como "volver arriba", pero costoso.  
Impacto tecnico: identidad inestable deliberada; invalida subarbol completo.  
Propuesta: reemplazar por acciones de scroll-to-top/navigate-root por tab, conservando identidad estable.  
Complejidad: media.  
Riesgo: medio por navegacion.  
Validacion: comparar memoria/reconstrucciones con SwiftUI Instrument al retocar tabs.

### P2 - Foreground lanza varias tareas de refresco simultaneas

Area: cold/warm foreground  
Archivo: [AppStore.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/App/AppStore.swift:246), [AppStore.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/App/AppStore.swift:278)  
Evidencia: foreground sincroniza widgets, notificaciones, HealthKit, eventos de actividad, StoreKit, iCloud entitlement y social ping.

Impacto para usuario: posible sensacion de "primer segundo cargado" al volver a la app.  
Impacto tecnico: mezcla tareas necesarias para UI con tareas diferibles.  
Propuesta: separar `foregroundCritical` (drain notifications, active workout snapshot) de `foregroundDeferred` (entitlements/social/backup), con prioridad y signposts.  
Complejidad: media.  
Riesgo: bajo-medio.  
Validacion: App Launch / Hangs / signposts de foreground to first interaction.

## SwiftData y CloudKit

SwiftData:

- Confirmado: no se usa `@Query` en UI como fuente principal; se carga un snapshot completo a arrays de dominio.
- Confirmado: la configuracion SwiftData usa `cloudKitDatabase: .none`, por lo que no hay sync SwiftData/CloudKit automatico.
- Riesgo: borrar/editar historico, sesiones y planes debe proteger relaciones y datos existentes. La reconciliacion por id ayuda, pero requiere tests de regresion.

CloudKit:

- CloudKit aparece para social y para entitlement iCloud Pro, no para persistencia principal.
- iCloud backup Pro escribe snapshot JSON en iCloud Documents. Esto protege reinstalacion, pero no equivale a sync multi-device con merge/conflictos.
- Hipotesis pendiente de validacion: en dos dispositivos editando offline, la politica de snapshot puede sobrescribir datos recientes si se implementa restore manual sin merge.

## Quick wins tecnicos

1. Crear render models cacheados para `ProgressDashboardView` y `CalendarView`.
2. Debounce + index de busqueda para `ExerciseLibraryView`.
3. Sustituir `.id(UUID())` de tabs por scroll-to-top/navigation reset controlado.
4. Añadir signposts a `commitPendingSave`, `finishWorkout`, `publishActiveWorkoutStatus`, `ProgressDashboardModel.rebuild`.
5. Crear datasets de test/perf con 1.000 sesiones, 10.000 sets, 800 ejercicios.

## Cambios estructurales recomendados

1. `ActiveWorkoutSessionModel` local con checkpoints ligeros.
2. Actor de persistencia separado de main actor.
3. `ProgressAnalyticsCache` incremental por fecha/rango.
4. `CalendarIndex` derivado por mes.
5. Separar stores de dominio manteniendo `AppStore` como facade temporal.

## Riesgos principales

- Romper recuperacion de entrenamiento activo si se mueve `activeWorkoutDrafts` sin checkpoint robusto.
- Alterar rachas o historico sin tests de zona horaria y backdated workouts.
- Perder consistencia con Watch/Live Activity si se reduce frecuencia de snapshots sin contrato claro.
- Introducir caches que se desincronicen de sesiones/salud.

## Validacion recomendada

- Instruments: SwiftUI, Time Profiler, Animation Hitches, File Activity.
- Scenarios: abrir Hoy, abrir Progreso, cambiar rango, abrir Calendario, completar 20 sets, finalizar workout, background/resume, HealthKit foreground sync.
- Release-like build y dispositivo real. Simulator solo como investigacion local.
