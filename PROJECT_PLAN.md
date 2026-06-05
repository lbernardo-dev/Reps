# Reps - Plan de Proyecto

## 1. Objetivo

Crear una app iOS nativa llamada Reps para registrar y visualizar el progreso de entrenamiento en gimnasio o casa. La app debe permitir crear planes, programar entrenamientos, definir metas, registrar series con peso/repeticiones/duracion, consultar progreso general y progreso por ejercicio, hacer seguimiento de peso y talla corporal, integrarse con Apple Health, y funcionar en ingles y espanol desde la primera version.

## 2. Referencias de diseno analizadas

Fuente: `Diseños/stitch_pulse_fitness`

Pantallas principales disponibles:
- `welcome_brand_energy_variant`: bienvenida con marca Pulse y CTA principal.
- `profile_setup`: onboarding de ubicacion, objetivo y nivel.
- `today_s_training_refined`: pantalla Today con entrenamiento del dia, racha, semana, ultimo entrenamiento y meta activa.
- `training_plans_refined`: lista de planes, plan activo, avance semanal y FAB para crear.
- `create_plan_basic_info`: primer paso de creacion de plan.
- `create_plan_review`: revision y activacion del plan.
- `workout_detail`: detalle de rutina y CTA para iniciar.
- `refined_active_workout`: registro activo con timer, descanso, series, steppers, completar set y siguiente ejercicio.
- `fitness_insights_refined`: dashboard de progreso con stats, consistencia, PR, peso corporal y distribucion muscular.
- `exercise_progress_refined`: detalle de progreso por ejercicio.
- `workout_calendar`: calendario mensual con entrenamientos programados/completados.
- `exercises`: biblioteca de ejercicios.
- `your_goals`: gestion de metas.
- `profile_settings`: perfil, unidades, idioma, notificaciones y ajustes.

Sistema visual:
- Estilo iOS nativo, limpio y de alta legibilidad.
- Color primario verde: acciones, progreso y estados completados.
- Acento naranja: descanso, logros y alertas positivas.
- Fondo gris claro tipo grouped iOS, tarjetas blancas, sombras muy sutiles.
- Navegacion principal con tab bar: Today, Plans, Progress, Calendar, Profile.
- Controles clave: tarjetas, listas agrupadas, segmented controls, progress bars, charts, sheets y botones grandes.

## 3. Alcance MVP

El MVP debe cubrir el flujo completo de valor:
1. Configurar perfil inicial.
2. Crear o activar un plan.
3. Ver el entrenamiento del dia.
4. Ejecutar y registrar un entrenamiento con series.
5. Guardar historial.
6. Visualizar progreso general y por ejercicio.
7. Cambiar idioma y unidades.
8. Registrar peso y talla corporal.
9. Conectar Apple Health para leer y escribir peso/talla, y dejar preparada la integracion de workouts.

Fuera del MVP inicial:
- Sincronizacion en la nube.
- Compartir entrenamientos.
- IA para generar planes.
- Watch app.
- Suscripciones o paywall.
- Fotos de progreso reales, salvo placeholder/modelo preparado.

## 3.1 Pendientes Pro añadidos

- Perfil como hub de valor: avatar editable, metricas corporales editables sin duplicidad, indices corporales utiles y explicados.
- Galeria de fotos de progreso con timeline visual para comparar evolucion.
- Tarjetas de fidelizacion de gimnasios con QR/barcode y registro historico de visitas/locales.
- Biblioteca de ejercicios con imagenes e instrucciones precisas apoyada en fuentes publicas verificables. Fuente offline preferente: `free-exercise-db` por licencia CC0/public-domain; `wger` puede evaluarse si se implementan atribucion y cumplimiento de licencia.

## 4. Stack propuesto

- Plataforma: iOS nativo.
- UI: SwiftUI.
- Arquitectura: MVVM ligera con servicios de dominio.
- Persistencia local: SwiftData si el target minimo lo permite; Core Data si se decide soportar versiones mas antiguas.
- Graficas: Swift Charts.
- Localizacion: String Catalog (`Localizable.xcstrings`) con ingles y espanol.
- Estado simple de ajustes: `AppStorage`.
- Testing: Swift Testing o XCTest segun plantilla final.

Decision pendiente antes de scaffolding:
- Nombre final de app: `Reps`.
- Bundle ID: `com.romerodev.repsfitness`.
- Target minimo de iOS: iOS 17+ propuesto para SwiftUI moderno, SwiftData opcional y HealthKit async.
- SwiftData vs Core Data.

## 5. Arquitectura funcional

### Capas

- `App`: entry point, configuracion de persistencia, localizacion y theme.
- `DesignSystem`: colores, tipografia, iconos, botones, tarjetas, inputs, chips, barras de progreso.
- `Models`: entidades persistentes y enums.
- `Repositories`: acceso a datos y queries reutilizables.
- `Services`: calculos de progreso, volumen, rachas, PRs, calendario y unidades.
- `Health`: autorizacion Apple Health, lectura/escritura de peso y talla, y capa futura para workouts.
- `Features`: pantallas por dominio.
- `Resources`: assets, strings, seed data y previews.

### Features

- `Onboarding`
- `Today`
- `Plans`
- `PlanBuilder`
- `Workout`
- `Exercises`
- `Progress`
- `Calendar`
- `Goals`
- `Profile`

## 6. Modelo de datos inicial

Entidades principales:

- `UserProfile`
  - name, preferredLanguage, units, trainingLocation, mainGoal, experienceLevel, weeklyTrainingDays, onboardingCompleted.
- `Exercise`
  - name, localizedNameKey, primaryMuscles, secondaryMuscles, equipment, difficulty, location, trackingType, instructions.
- `WorkoutPlan`
  - name, goal, location, daysPerWeek, status, startDate, endDate, currentWeek.
- `WorkoutDay`
  - plan, weekday, title, order, exercises.
- `WorkoutExercise`
  - exercise, order, targetSets, targetRepsMin, targetRepsMax, targetWeight, targetDuration, restSeconds.
- `ScheduledWorkout`
  - date, workoutDay, status, completedSession.
- `WorkoutSession`
  - workoutDay, startedAt, endedAt, duration, notes, status.
- `ExerciseLog`
  - session, exercise, order, notes.
- `SetLog`
  - exerciseLog, setNumber, weight, reps, duration, distance, completed, perceivedEffort.
- `Goal`
  - type, title, targetValue, currentValue, unit, deadline, linkedExercise, status.
- `BodyMetric`
  - date, bodyWeight, height, measurements, source, notes.

Enums:
- Training location: gym, home, both.
- Main goal: buildMuscle, loseFat, getStronger, stayActive, endurance, custom.
- Experience: beginner, intermediate, advanced.
- Units: metric, imperial.
- Health source: manual, appleHealth.
- Tracking type: weightReps, repsOnly, duration, distance, bodyweight.
- Workout status: scheduled, completed, missed, skipped.

## 7. Flujos principales

### Onboarding

Welcome -> Language -> Training profile -> Weekly days -> Finish -> Today.

Criterios:
- El usuario puede completar onboarding en menos de 1 minuto.
- Todos los textos existen en ingles y espanol.
- Se guarda `onboardingCompleted`.

### Crear plan

Plans -> Add -> Basic Info -> Schedule -> Workouts/Exercises -> Review -> Activate.

Criterios:
- Puede crearse un plan custom minimo con nombre, objetivo, dias y ejercicios.
- La pantalla Review muestra dias, ejercicios y rangos de reps.
- Al activar, se genera calendario inicial.

### Entrenar

Today/Workout Detail -> Start Workout -> Active Workout -> Finish -> Summary -> Progress actualizado.

Criterios:
- Registrar un set requiere pocos taps.
- Se puede modificar peso y reps con steppers.
- El descanso se puede iniciar/saltar.
- Al finalizar se persisten session, exercise logs y set logs.

### Progreso

Progress -> Exercise Progress -> History.

Criterios:
- Dashboard muestra workouts totales, volumen, PRs, consistencia, peso corporal y distribucion muscular.
- Ejercicio individual muestra peso, reps, volumen y estimated 1RM cuando aplica.
- El usuario puede ver peso corporal y talla, guardarlos manualmente y sincronizarlos con Apple Health cuando conceda permisos.

## 8. Fases de implementacion

### Fase 0 - Preparacion del proyecto

Resultado: proyecto iOS creado, compila y tiene estructura base.

Tareas:
- Crear proyecto iOS nativo.
- Configurar SwiftUI, persistencia local, assets y localizacion.
- Configurar HealthKit capability, entitlements y usage descriptions.
- Definir target minimo y bundle id.
- Crear estructura de carpetas.
- Agregar seed data inicial de ejercicios y planes.

### Fase 1 - Design system

Resultado: componentes reutilizables listos para montar pantallas.

Tareas:
- Tokens de color y tipografia basados en Stitch.
- Componentes: primary button, secondary button, card, stat card, progress bar, segmented control, empty state, list row, tab item.
- Soporte light/dark si se decide incluirlo desde el MVP.
- Previews de componentes en ingles y espanol.

### Fase 2 - Datos y dominio

Resultado: modelos, persistencia y calculos core funcionando.

Tareas:
- Implementar modelos.
- Implementar persistencia completa con SwiftData para perfil, ejercicios, planes, calendario, sesiones, metas, metricas corporales y estado de HealthKit.
- Migrar datos legacy desde `store.json` cuando exista una instalacion previa.
- Implementar `HealthKitService` para disponibilidad, autorizacion, lectura y escritura de body mass y height.
- Implementar conversion kg/lb.
- Calcular volumen, PR, streak, consistency, weekly completion y estimated 1RM.
- Tests unitarios de calculos y round-trip de persistencia.

### Fase 3 - Navegacion y onboarding

Resultado: usuario puede entrar, configurar perfil y llegar a Today.

Tareas:
- App shell con TabView.
- Onboarding multi-step.
- Language selector.
- Guardar preferencias.
- Bloquear tabs hasta completar onboarding si aplica.

### Fase 4 - Planes y builder

Resultado: usuario puede crear, revisar y activar planes.

Tareas:
- Plans list.
- Active plan card.
- Plan detail.
- Create plan flow.
- Exercise picker integrado.
- Review & Save.
- Generacion de schedule.

### Fase 5 - Today y calendario

Resultado: usuario ve que toca hoy y puede gestionar fechas.

Tareas:
- Today screen.
- Empty states.
- Weekly completion.
- Last workout.
- Active goal card.
- Calendar mensual.
- Detalle de dia, programar y reprogramar.

### Fase 6 - Workout activo

Resultado: registro de entrenamiento completo y persistente.

Tareas:
- Workout detail.
- Active workout timer.
- Rest timer.
- Set rows con steppers.
- Add set.
- Complete set.
- Notes.
- Next exercise card.
- Finish workout.
- Workout summary.

### Fase 7 - Progreso y metas

Resultado: metricas utiles con graficas y metas.

Tareas:
- Progress dashboard.
- Exercise progress detail.
- Historial por ejercicio.
- Goals list.
- Create/edit goal.
- Body metrics.
- Height metrics.
- Apple Health sync para peso y talla.
- Charts y estados sin datos.

### Fase 8 - Biblioteca y perfil

Resultado: ejercicios y ajustes operativos.

Tareas:
- Exercise library.
- Search y filtros.
- Exercise detail.
- Add custom exercise.
- Profile settings.
- Units kg/lb.
- Idioma ingles/espanol.
- Conectar Apple Health.
- Notifications placeholder o implementacion local basica.

### Fase 9 - Calidad, accesibilidad y release interno

Resultado: build estable para probar.

Tareas:
- Revisar accesibilidad: labels, Dynamic Type, contraste, touch targets.
- Revisar localizacion completa.
- Tests de flujos criticos.
- Seed/reset de datos para QA.
- Preparar icono, launch screen y metadata inicial.
- Build en simulador y checklist de bugs.

## 9. Orden recomendado para empezar

1. Scaffold del proyecto.
2. Design system minimo.
3. Modelo de datos.
4. Seed data.
5. Tab navigation.
6. Today screen estatica con seed data.
7. Plans list estatica con seed data.
8. Active workout funcional.
9. Persistencia real.
10. Progreso calculado.

La razon: el valor principal de la app es registrar entrenamientos y ver progreso. El primer milestone util debe permitir iniciar desde Today, guardar sets y ver un cambio basico en Progress.

## 10. Riesgos y decisiones

- SwiftData queda como persistencia local del MVP con target minimo iOS 17.
- La UI de Stitch usa HTML/Tailwind como referencia visual, no como codigo reutilizable directo para iOS.
- La localizacion debe estar desde el inicio para evitar rehacer layouts.
- El logging activo debe probarse en dispositivos pequenos; es la pantalla con mas riesgo de ergonomia.
- Las graficas deben empezar simples para no retrasar el flujo core.

## 11. Milestones

- M1: Proyecto compila con navegacion base y theme.
- M2: Onboarding + Today + Plans con seed data.
- M3: Crear plan y activar schedule.
- M4: Workout activo guarda sesiones reales.
- M5: Dashboard y progreso por ejercicio con datos reales.
- M6: Localizacion completa EN/ES + settings.
- M7: QA, accesibilidad y build interna.

## 12. Ampliacion avanzada

La especificacion avanzada redefine el producto mas alla del MVP. El MVP actual no debe considerarse "full power": cubre la base de registro y progreso, pero quedan pendientes datos de serie avanzados, cardio, bienestar, motor de progresion, fatiga/carga, sustituciones y PRO.

Documento de control: `ADVANCED_SCOPE_AUDIT.md`.

### Principios actualizados

- Local-first sigue siendo obligatorio.
- Las reglas de negocio deben salir de las vistas SwiftUI y vivir en servicios testeables.
- Cualquier funcionalidad avanzada debe tener estado vacio, persistencia, navegacion accesible y prueba unitaria si calcula algo.
- La UI debe priorizar la version simple por defecto y mostrar campos avanzados solo si el usuario los activa.

### Servicios de dominio objetivo

- `AnalyticsEngine`: volumen, volumen efectivo, 1RM, PRs, series efectivas, intensidad, carga, ACWR y fatiga.
- `ProgressionEngine`: progresion lineal, doble progresion, RPE/RIR, %1RM/TM, estancamiento y deload.
- `InsightsEngine`: tarjetas de coaching basadas en datos reales.
- `ExerciseSubstitutionService`: sustituciones por musculo/patron/equipamiento.

### Nuevos modulos funcionales

- Cardio manual y HealthKit workout import.
- Bienestar: sueno, fatiga, estres, molestias, medidas y fotos.
- Ajustes avanzados: RPE/RIR, campos visibles, incrementos de peso y auto-progresion.
- Export/import CSV, borrado de datos, sync y capa PRO.

### Proximos milestones avanzados

- A1: Consolidacion UX/localizacion y navegacion.
- A2: Modelo de datos avanzado con migracion SwiftData.
- A3: Logging avanzado configurable.
- A4: Analitica avanzada y tabs de Progreso.
- A5: Motor de progresion y sugerencias.
- A6: Soporte casa/gimnasio con equipamiento y sustituciones.
- A7: Cardio, bienestar y HealthKit profundo.
- A8: Export, sync, compartir y PRO.
