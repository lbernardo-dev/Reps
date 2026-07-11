# Plan de accion de auditoria StreakReps

Fecha: 2026-07-09  
Objetivo: mejorar rendimiento real, fluidez percibida, claridad funcional y valor de producto sin romper datos, rachas, historico, Watch, widgets, Live Activities ni monetizacion.

## Principios de ejecucion

- No cambiar modelo de datos sin tests y estrategia de migracion.
- No tocar calculo de rachas sin pruebas de zona horaria, backdated workouts y cambio de dia.
- No refactorizar `AppStore` de golpe.
- Medir antes/despues en flujos centrales.
- Priorizar el loop: abrir app -> empezar -> registrar set -> terminar -> ver progreso -> volver manana.

## Fase 1 - Correcciones criticas P0/P1

### 1. Instrumentacion minima

Alcance:
- Añadir signposts a `commitPendingSave`, `SwiftDataPersistence.save`, `finishWorkout`, `publishActiveWorkoutStatus`, rebuild de Progreso/Calendario/Catalogo.
- Crear escenarios reproducibles con datasets grandes.

Validacion:
- Build Debug y Release-like.
- Time Profiler, SwiftUI Instrument, File Activity.

Riesgo: bajo.  
Valor: convierte hipotesis en evidencia.

### 2. Render models para Progreso

Alcance:
- Extraer `ProgressDashboardRenderModel`.
- Precalcular `heroMetrics`, series diarias, trends, week charts, summaries por rango.
- Rebuild solo cuando cambien sesiones/salud/cardio/goals/rango.

Archivos candidatos:
- [ProgressView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Progress/ProgressView.swift:5)
- [ProgressModels.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Progress/Components/ProgressModels.swift:1)

Riesgo: bajo-medio.  
Valor: alto en dashboards e historial.

### 3. Index mensual para Calendario

Alcance:
- `CalendarMonthRenderModel` con sesiones/programadas/volumen por dia.
- Evitar filtros repetidos por celda.

Archivo:
- [CalendarView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Calendar/CalendarView.swift:4)

Riesgo: bajo.  
Valor: alto con historico grande.

### 4. Modelo local para entrenamiento activo

Alcance:
- Introducir `ActiveWorkoutSessionModel` como owner de drafts durante la sesion.
- Publicar snapshots ligeros cada 5 s y en eventos clave para Watch/Live Activity.
- Checkpoint en background, set completado importante, cambios estructurales y finish.

Archivos:
- [ActiveWorkoutView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Workout/ActiveWorkoutView.swift:12)
- [AppStore.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/App/AppStore.swift:89)

Riesgo: alto.  
Mitigacion: tests de recuperacion, background, Watch, Live Activity.

## Fase 2 - Fluidez y percepcion premium

### 1. Set completion feedback

Alcance:
- Confirmacion local "Serie registrada".
- Undo visible y temporizado.
- Progreso animado estable.

Riesgo: bajo.

### 2. Workout summary como recompensa central

Alcance:
- Ordenar resumen por logro, racha, PR/volumen, siguiente accion.
- Evitar que paywall interrumpa antes de reconocer el progreso.

Riesgo: medio por monetizacion.

### 3. Estados loading/refreshing/stale

Alcance:
- Crear patron comun de `LoadState`.
- Aplicar a catalogo, HealthKit, social, progreso avanzado.

Riesgo: bajo.

### 4. Reemplazar reset de tabs por reset controlado

Alcance:
- Sustituir `.id(UUID())` por scroll-to-top / pop-to-root.
- Mantener identidad estable de pantallas grandes.

Riesgo: medio.

## Fase 3 - Conexion funcional

### 1. Goals conectados a entrenamiento

Alcance:
- Objetivos diarios/semanales visibles en Hoy y Progreso.
- Al terminar workout, mostrar avance especifico del objetivo.

Riesgo: bajo.

### 2. Rachas con recuperacion responsable

Alcance:
- Estado de riesgo, recuperacion y continuidad semanal.
- Evitar castigo visual por perder un dia.

Riesgo: medio si se toca calculo; bajo si solo es UI sobre calculo existente.

### 3. Insights accionables

Alcance:
- Cada insight debe terminar en accion: entrenar, descansar, ajustar peso, crear plan, revisar ejercicio.

Riesgo: bajo.

## Fase 4 - Funciones de adopcion y conversion

### 1. Activacion en menos de un minuto

Alcance:
- Primer uso: elegir objetivo/equipo -> empezar rutina recomendada -> registrar primera serie.
- Demo data opcional o workout de prueba.

Riesgo: medio.

### 2. Premium contextual

Alcance:
- Mostrar preview antes del bloqueo: analytics avanzadas, progression, backup, Watch.
- No bloquear logging ni progreso basico.

Riesgo: bajo-medio.

### 3. Retorno tras abandono

Alcance:
- "Vuelve con una sesion corta", "recupera la semana", "no pasa nada por fallar".

Riesgo: bajo.

## Fase 5 - Optimizacion continua

### Metricas tecnicas

- Tap-to-feedback al completar set.
- Tiempo a primera pantalla util.
- Tiempo a primer workout iniciado.
- Tiempo de abrir Progreso con dataset grande.
- Duracion de `commitPendingSave`.
- Hitches por pantalla.

### Metricas de producto

- Onboarding completion.
- Primer workout registrado.
- D1/D7 retention.
- Sesiones por usuario activo.
- Uso de quick log.
- Conversion por paywall source.
- Recovery after missed day.

### Escenarios de validacion implementados

Usar Instruments con build Release-like cuando sea posible; Simulator solo sirve como comparativa local.

1. Entreno activo
   - Abrir una rutina, iniciar sesion, completar 5 series, deshacer una serie, finalizar.
   - Signposts: `workout.publishStatus`, `workout.finish`, `appStore.commitPendingSave`, `swiftData.save`.
   - Criterio: feedback visual inmediato al completar serie; no debe aparecer el paywall antes del resumen.

2. Progreso con historico grande
   - Abrir Progreso, cambiar rango, entrar en carga, abrir detalle de volumen.
   - Signposts: `progress.renderModel`, `progress.dailyVolumeSeries`, `progress.heroMetrics`, `progress.trendMetrics`, `progress.workload`, `progress.competitiveSummary`.
   - Criterio: el coste pesado debe concentrarse en `progress.renderModel`, no repetirse por cada subvista.

3. Calendario con meses poblados
   - Cambiar entre meses y seleccionar dias con y sin sesiones.
   - Signposts: `calendar.monthRenderModel`, `calendar.changeMonth`.
   - Criterio: no debe haber filtros repetidos por celda; volumen maximo mensual se calcula una vez por mes.

4. Catalogo
   - Buscar por texto, alternar musculos/filtros/equipo.
   - Signposts: `exerciseLibrary.searchIndex`, `exerciseLibrary.filteredExercises`, `exerciseLibrary.groupedExercises`.
   - Criterio: `searchIndex` debe reconstruirse solo cuando cambie el catalogo, no en cada tecla.

5. Adopcion y retorno
   - Usuario sin sesiones: Hoy debe mostrar una accion directa para empezar.
   - Usuario con varios dias sin entrenar: Hoy debe mostrar recuperacion sin penalizacion visual.
   - Criterio: el CTA central inicia entrenamiento sin pasar por paywall.

## Orden recomendado de implementacion

1. Signposts y datasets de rendimiento.
2. Render model de Progreso.
3. Calendar index.
4. Catalog search index.
5. Workout summary reward flow.
6. Active workout local model.
7. Foreground task prioritization.
8. Premium previews y roadmap funcional.

## No hacer todavia

- Migrar SwiftData a CloudKit automatico sin estrategia de conflictos.
- Cambiar reglas de racha sin tests especificos.
- Reescribir `AppStore` completo.
- Añadir animaciones pesadas para ocultar costes reales.
- Bloquear funciones centrales gratuitas detras de Pro.
