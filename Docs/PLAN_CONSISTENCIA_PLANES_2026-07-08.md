# Plan de ejecucion - Consistencia de planes en Reps

Fecha: 2026-07-08  
Ambito: iOS app, tabs Hoy / Entrenar-Plan / Progreso / Calendario / detalles de entrenamiento  
Objetivo: eliminar la confusion actual entre plan recomendado, plan activo y plan guardado, sin perder funciones, sin romper limites Free/Pro y elevando la seccion de plan activo con datos reales.

---

## 1. Diagnostico ejecutivo

El problema no es falta de funcionalidad. La app ya tiene planes, rutinas, calendario, progreso, musica, recomendaciones, HealthKit, Training Battery, SmartProgressionAdvisor y graficas. El problema es que hoy hay varias "voces" compitiendo:

- `PlansView` muestra `RecommendedWorkoutCard` aunque `hasActivePlan == true` (`Reps/Features/Plans/PlansView.swift:114-129`). Esto contradice la regla deseada: con plan seleccionado no debe verse plan recomendado en ninguna vista.
- `TodayView` ya aplica la regla correcta para recomendado: `if let rec = recommendedWorkout, !hasActivePlan` (`Reps/Features/Today/TodayView.swift:307-320`). Esa logica debe convertirse en politica compartida.
- `activateRecommendedWorkoutPlan` crea un plan nuevo con `bypassPlanLimit: true` (`Reps/App/AppStore.swift:2270-2283`). Eso evita los limites Free/Pro y puede crear un plan recomendado aunque el usuario free no deberia poder acumular planes.
- `deactivatePlan` no deja `activePlan = .empty` cuando no hay reemplazo; solo borra programaciones (`Reps/App/AppStore.swift:2590-2600`). Para el usuario, "desactivar todos los planes" debe producir estado sin plan activo.
- `WorkoutPlan.completion` parece ser un valor persistido, pero no se actualiza al finalizar entrenos. Las pantallas muestran `store.activePlan.completion` como si fuera verdad (`TodayView.swift:1529-1534`, `PlansView.swift:566-569`). Para un plan activo, el resumen debe derivarse de sesiones reales, no de un campo potencialmente obsoleto.

Conclusion: necesitamos una unica fuente de verdad para el estado del plan, una politica de visibilidad comun, y un resumen de ejecucion calculado desde datos reales.

---

## 2. Principios de producto, mercado y psicologia

### Mercado

Las apps fuertes de fuerza no ganan solo por tener mas pantallas. Ganan porque reducen decision fatigue y convierten datos en accion:

- Fitbod posiciona su valor en planes personalizados que se actualizan con cuerpo, recuperacion y progreso; tambien usa historial y recuperacion para recomendar musculos o sesiones. Referencia: https://fitbod.me/
- Strong compite desde claridad operacional: planificar, registrar y visualizar progreso sin estorbar durante el entreno. Referencia: https://www.strong.app/
- ACSM describe que mHealth y wearables ya empujan planes personalizados con variables como actividad diaria, sueno, estado de animo y peso corporal. Referencia: https://acsm.org/personalized-fitness-mobile-technology/
- La investigacion reciente sobre adherencia en fitness apps apunta a que feedback de progreso, objetivos personalizados, sensacion de competencia y control percibido favorecen persistencia. Referencia: https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2026.1752995/full

### Psicologia de uso

Reglas que deben guiar esta reforma:

- Una accion primaria por momento: si hay plan activo, la app debe decir "sigue tu plan", no "quizas otro plan".
- Competencia percibida: el usuario se siente capaz cuando ve avance real, adherencia, volumen y mejoras, no una promesa estimada permanente.
- Autonomia sin caos: permitir cambiar el dia, pausar o desactivar un plan, pero sin convertir cada pantalla en un marketplace de alternativas.
- Confianza: distinguir siempre "estimado" de "real". Con plan activo, las graficas principales deben ser reales; las proyecciones pueden quedar como ayuda secundaria o previa a activar.
- Compromiso: cuando el usuario selecciona un plan, ese plan pasa a ser "el contrato". Las recomendaciones deben ayudar a ejecutarlo, no competir contra el.

---

## 3. Modelo mental canonico

Definir estos conceptos y no mezclarlos:

| Concepto | Fuente | Significado | Donde aparece |
|---|---|---|---|
| Plan recomendado | Generado transitoriamente desde perfil, bateria, musculos infraentrenados y contexto | Sugerencia para empezar cuando no hay plan activo | Solo sin plan activo |
| Plan activo / seleccionado | `AppStore.activePlan` con `days.isEmpty == false` | El plan que gobierna Hoy, calendario, widgets, detalles y progreso | Todas las vistas que hablen de plan |
| Plan guardado | `AppStore.plans` | Plan disponible para activar o editar | Entrenar/Plan y selector explicito |
| Entreno del dia | Programado de hoy o `activePlan.normalizedActiveDay` | Sesion concreta que toca hacer | Hoy, calendario, ActiveWorkout |
| Entreno libre | `WorkoutDay.freeWorkout` | Registro sin plan | Hoy/Quick actions, nunca como plan seleccionado |

Regla de oro:

> Si `activePlan.days.isEmpty == false`, no se renderiza ningun bloque de "Entreno recomendado" ni "Plan recomendado" en ninguna vista principal o detalle.

---

## 4. Reglas de estado

Crear un selector central, no repetir `!store.activePlan.days.isEmpty` por todas partes.

Propuesta:

```swift
enum TrainingPlanState: Equatable {
    case noActivePlan(savedPlans: Int)
    case active(plan: WorkoutPlan)
}

extension AppStore {
    var trainingPlanState: TrainingPlanState {
        activePlan.days.isEmpty
            ? .noActivePlan(savedPlans: plans.count)
            : .active(plan: activePlan)
    }

    var hasActiveTrainingPlan: Bool {
        if case .active = trainingPlanState { return true }
        return false
    }
}
```

Invariantes:

- `activePlan.days.isEmpty == true` significa sin plan activo.
- Desactivar un plan no activa otro automaticamente. Cambiar de plan debe ser una accion explicita.
- `plans` puede contener planes guardados, pero ninguno es "seleccionado" hasta `activatePlan`.
- `scheduledWorkouts` no debe conservar sesiones programadas de un plan desactivado salvo completadas/historicas.
- Las pantallas no deben inferir el plan actual desde `plans.first`.

---

## 5. Politica Free / Pro

Mantener el contrato actual de producto:

- Free:
  - Puede registrar entrenos.
  - Puede usar libreria de ejercicios.
  - Puede crear y usar un plan propio mientras no acumule multiples planes.
  - Puede ver recomendacion cuando no hay plan activo.
  - No debe saltarse limites mediante `bypassPlanLimit`.
- Pro:
  - Puede activar programas del catalogo.
  - Puede guardar y gestionar multiples planes.
  - Puede acceder a analytics avanzados donde ya aplique el feature gate.

Cambio especifico:

- `activateRecommendedWorkoutPlan` no debe usar `bypassPlanLimit: true` por defecto.
- Si Free no tiene planes guardados: puede activar el recomendado como su primer plan.
- Si Free tiene un plan guardado inactivo: mostrar dos opciones claras:
  - "Activar plan guardado" si quiere seguir con lo que ya creo.
  - "Reemplazar por recomendado" con confirmacion destructiva, o paywall si se decide que conservar ambos es Pro.
- Si Free tiene plan activo: no aparece recomendado; para cambiar debe desactivar, reemplazar o pasar por el flujo Pro segun limite.
- Si Pro no tiene plan activo: puede activar recomendado y guardarlo como plan nuevo.

Esto evita que el usuario free sienta que la app promete algo que luego no puede mantener.

---

## 6. Datos reales para el plan activo

Crear un servicio pequeno y testeable: `PlanExecutionAnalyzer`.

Entrada:

- `activePlan`
- `workoutSessions`
- `scheduledWorkouts`
- `bodyMetrics`
- `health`
- `userProfile`
- `now`

Salida:

```swift
struct PlanExecutionSummary: Equatable {
    let planID: UUID
    let planName: String
    let currentWeek: Int
    let totalWeeks: Int
    let daysPerWeek: Int
    let completedThisWeek: Int
    let scheduledThisWeek: Int
    let adherence: Double
    let totalCompletedSessions: Int
    let planProgress: Double
    let targetWeeklySets: Int
    let actualWeeklySets: Int
    let volumeThisWeekKg: Double
    let volumeDeltaVsPreviousWeek: Double?
    let estimatedOneRepMaxTrend: TrendDirection
    let loadState: PlanLoadState
    let nextWorkout: WorkoutDay?
    let lastCompletedWorkoutDate: Date?
    let weeklyPoints: [PlanWeekPoint]
    let muscleTargetPoints: [MuscleTargetPoint]
    let stalledExercises: [AnalyticsEngine.ExerciseStall]
}
```

Calculos:

- Adherencia semanal: completados esta semana / `activePlan.daysPerWeek`.
- Progreso del bloque: sesiones completadas atribuibles al plan / sesiones esperadas hasta la semana actual, acotado a 0...1.
- Volumen real: `FitnessMetrics.totalVolumeKg(for:)`.
- Target vs real por musculo: reutilizar `AnalyticsEngine.competitiveSummary`.
- Evolucion: series semanales de sesiones, volumen, sets y 1RM estimado.
- Riesgo / involucion: carga aguda vs cronica (`workloadSummary`), fatiga, descenso de volumen, estancamientos.

### Atribucion de sesiones al plan

Hoy `WorkoutSession` guarda `workoutTitle` y `origin`, pero no `planID` ni `workoutDayID`. Para datos fiables:

1. Anadir campos opcionales migrables:

```swift
var sourcePlanID: UUID?
var sourceWorkoutDayID: UUID?
```

2. Al iniciar/terminar `ActiveWorkoutView`, pasar el `activePlan.id` y `workout.id` cuando el workout pertenece al plan activo.
3. Para historico antiguo, fallback por titulo + fecha + ejercicios, marcado internamente como inferido.
4. Las graficas deben poder distinguir datos confirmados de datos inferidos si hace falta.

Sin esta atribucion, se pueden pintar datos reales, pero no suficientemente consistentes cuando dos planes tienen dias con el mismo titulo.

---

## 7. Cambios por pantalla

### 7.1 Hoy

Estado sin plan activo:

- Hero de entrenamiento puede seguir diciendo "Elige tu proximo movimiento".
- Mostrar `RecommendedWorkoutCard` como puente a crear/activar plan.
- CTA: "Usar este plan" o "Empezar hoy", con confirmacion adaptada a Free/Pro.

Estado con plan activo:

- Mantener `dashboardWorkoutCard` como sesion del dia.
- No mostrar `RecommendedWorkoutCard`.
- El bloque `planPreview` debe dejar de usar `activePlan.completion` persistido y usar `PlanExecutionSummary`.
- Copy recomendado:
  - Titulo: nombre del plan activo.
  - Estado: "2/3 sesiones esta semana", "Volumen +12% vs semana pasada", "Carga estable" o "Baja intensidad recomendada".
  - CTA secundaria: "Ver ejecucion del plan".

### 7.2 Entrenar / Plan

Estado sin plan activo:

- Mostrar una sola seccion superior: "Plan recomendado para empezar".
- Debajo: planes guardados, programas, rutinas, libreria y herramientas.
- Si hay planes guardados inactivos, priorizar "Activar un plan guardado" antes que crear otro.

Estado con plan activo:

- Eliminar la tarjeta de recomendado de `PlansView`.
- Reemplazar `ActivePlanCommandCard` por `ActivePlanExecutionCard`.
- Mantener `PlanMusicCard`, training days, librerias y herramientas.
- `discoveryBanner` pasa a ser pequeno y claramente secundario: "Explorar programas" sin prometer cambiar el plan.

Contenido de `ActivePlanExecutionCard`:

- Header: nombre, ubicacion, semana actual/total, dias/semana.
- Anillo: progreso real del bloque, no `plan.completion` persistido.
- Tres metricas:
  - Adherencia: `2/3 esta semana`.
  - Volumen: `6.240 kg`, delta vs semana anterior.
  - Sets objetivo: `34/42`.
- Estado visual:
  - Verde: en linea.
  - Cian: recuperado / carga estable.
  - Naranja: falta una sesion o volumen bajo.
  - Rojo: sobrecarga, fatiga o semana muy por debajo.
- Mini chart real: volumen o adherencia por semana.
- CTA principal: "Empezar siguiente sesion".
- CTA secundaria: "Ver detalle de ejecucion".
- Menu: cambiar dia, editar plan, desactivar plan.

### 7.3 Detalle de plan

`PlanDetailSheet` hoy muestra metadata, musculos y dias. Debe convertirse en una vista de ejecucion cuando el plan esta activo.

Secciones:

1. Resumen ejecutivo:
   - Semana actual / total.
   - Adherencia.
   - Progreso de bloque.
   - Carga.
2. Graficas reales:
   - Adherencia por semana.
   - Volumen semanal.
   - Sets objetivo vs real por grupo muscular.
   - 1RM estimado de los principales ejercicios si hay datos.
3. Diagnostico:
   - Musculos infraentrenados.
   - Ejercicios estancados.
   - Sesiones perdidas o saltadas.
4. Dias del plan:
   - Cada dia muestra ultimo completado, volumen ultimo, mejor set y estado.
5. Acciones:
   - Empezar siguiente.
   - Cambiar dia de hoy.
   - Editar.
   - Desactivar.

Para planes guardados inactivos, la vista puede seguir siendo una preview estructural con CTA de activar; no debe fingir ejecucion real.

### 7.4 WorkoutDetailView

Hoy siempre muestra `projectionCard` con progresion estimada.

Nueva regla:

- Si el workout pertenece al plan activo y hay datos: mostrar "Ejecucion real de este dia".
  - Ultima vez realizado.
  - Volumen ultimo vs anterior.
  - Sets completados vs objetivo.
  - Mejores ejercicios y recomendaciones reales.
- Si pertenece al plan activo pero no hay datos: mostrar una card educativa de "Primer registro de este dia", no una promesa de mejora.
- Si no hay plan activo y viene desde recomendado / preview: la proyeccion estimada puede aparecer, pero rotulada claramente como estimacion.

### 7.5 Calendario

- Usar `PlanExecutionSummary` para el contador semanal, no calculos locales divergentes.
- Los entrenos programados deben derivar del plan activo y borrarse al desactivar.
- Si no hay plan activo, calendario muestra sesiones programadas manuales y entrenos libres, no objetivo de plan.

### 7.6 Progreso

- Mantener la separacion: Progreso contiene analitica amplia.
- Anadir modulo "Plan activo" solo si hay active plan, usando el mismo `PlanExecutionSummary`.
- No duplicar copy de recomendado.
- Analytics avanzadas siguen respetando `advancedAnalytics`.

### 7.7 Widgets / Watch / Live Activity

- `sharedWorkoutSnapshot` ya deriva `nextWorkoutDayName` solo si `activePlan.days` no esta vacio. Mantener esa regla.
- Si se anaden `sourcePlanID` / `sourceWorkoutDayID`, publicar tambien nombre del plan activo para continuidad.
- Sin plan activo, widget no debe sugerir que hay siguiente dia de plan.

---

## 8. Cambios tecnicos por fases

### Fase 0 - Hotfix de coherencia visible

Objetivo: eliminar la confusion de las capturas sin rehacer arquitectura.

Tareas:

- En `PlansView`, renderizar `RecommendedWorkoutCard` solo cuando `!hasActivePlan`.
- En `buildRecommendedWorkoutIfNeeded`, no construir recomendado si hay plan activo.
- En `deactivatePlan`, guardar el plan en `plans`, poner `activePlan = .empty` y borrar programaciones pendientes.
- Revisar `deletePlan`: si borra el activo, decidir explicitamente entre `activePlan = .empty` o activar reemplazo solo si la accion del usuario fue "cambiar".
- Quitar `bypassPlanLimit` de recomendado o limitarlo a un caso controlado y testeado.
- Limpiar textos de alert: "Se seleccionara como plan activo" solo si realmente cumple limites.

Criterio de salida:

- Con plan activo, ninguna vista muestra "Entreno recomendado".
- Sin plan activo, Entrenar/Plan muestra recomendado.
- Desactivar el ultimo plan deja la app en estado sin plan.

### Fase 1 - Fuente de verdad de estado

Tareas:

- Anadir `trainingPlanState` y `hasActiveTrainingPlan` en `AppStore`.
- Reemplazar checks locales por el selector central.
- Crear tests para transiciones:
  - fresh install Free sin plan.
  - Free con plan activo.
  - Free con plan desactivado y planes guardados.
  - Pro con multiples planes.
  - entreno activo durante cambio/desactivacion.

Criterio de salida:

- Una sola politica de estado consumida por Hoy, Plan, Calendario, Progreso y widgets.

### Fase 2 - PlanExecutionAnalyzer

Tareas:

- Crear modelos `PlanExecutionSummary`, `PlanWeekPoint`, `PlanLoadState`, `TrendDirection`.
- Implementar calculos con `FitnessMetrics` y `AnalyticsEngine`.
- Usar datos reales por semana.
- Dejar de depender de `WorkoutPlan.completion` para UI.
- Opcional pero recomendado: anadir `sourcePlanID` y `sourceWorkoutDayID` a `WorkoutSession`.

Criterio de salida:

- El mismo resumen aparece identico en Hoy, Entrenar/Plan y Progreso.
- Las graficas de plan activo no usan datos inventados.

### Fase 3 - UI de plan activo

Tareas:

- Crear `ActivePlanExecutionCard`.
- Crear `PlanExecutionDetailView` o ampliar `PlanDetailSheet` con modo activo/inactivo.
- Crear charts reutilizables:
  - `PlanAdherenceChart`
  - `PlanVolumeTrendChart`
  - `PlanTargetVsActualChart`
  - `PlanPrimaryLiftTrendChart`
- Mantener `PlanMusicCard`, `PlanDayRow`, librerias, tools y program library.
- Usar colores semanticos, no solo lima:
  - Verde: adherencia/progreso.
  - Cian: recuperacion/estado estable.
  - Naranja: accion pendiente.
  - Rojo: riesgo o involucion.
  - Lima: identidad de marca y CTA principal.

Criterio de salida:

- La seccion "plan seleccionado" se percibe como tablero real de ejecucion.
- La vista detalle responde a "voy bien o mal con este plan?" en menos de 10 segundos.

### Fase 4 - Recomendado como onboarding continuo

Tareas:

- Renombrar conceptualmente la card a "Plan recomendado para empezar" cuando no hay plan.
- Ajustar CTA segun Free/Pro.
- Guardar recomendado solo tras confirmacion clara.
- Si el usuario solo quiere entrenar hoy sin adoptar plan, ofrecer "Empezar como entreno libre" sin activar plan.

Criterio de salida:

- Recomendado no crea planes fantasma.
- Free no salta limites.
- El usuario entiende si esta empezando una sesion o adoptando un plan.

### Fase 5 - Barrido de consistencia

Tareas:

- Buscar `RecommendedWorkoutCard`, `recommendedWorkout`, `activePlan.completion`, `plans.first`, `daysPerWeek` y `weeklyCompletion` en vistas.
- Sustituir calculos locales por `PlanExecutionSummary` cuando hablen de plan activo.
- Revisar strings ES/EN:
  - "Plan activo" / "Plan seleccionado" deben significar lo mismo.
  - "Recomendado" solo en estado sin plan.
  - "Estimado" solo para proyecciones no reales.

Criterio de salida:

- No queda ninguna pantalla con un concepto de plan divergente.

---

## 9. Tests necesarios

### Unit tests

- `deactivatePlan_whenLastActivePlan_setsActivePlanEmpty`.
- `deactivatePlan_withSavedPlans_doesNotAutoActivateReplacement`.
- `activateRecommendedWorkout_freeNoPlans_createsOneActivePlan`.
- `activateRecommendedWorkout_freeExistingPlan_requiresReplaceOrPaywall`.
- `plansViewVisibility_activePlan_hidesRecommended`.
- `todayVisibility_noActivePlan_showsRecommended`.
- `planExecutionSummary_usesCompletedSessionsAndTargets`.
- `planExecutionSummary_ignoresFreeWorkoutUnlessAttributed`.
- `deleteActivePlan_clearsScheduleOrExplicitlyReplaces`.

### Snapshot / UI tests

Estados minimos en iPhone 17 Pro:

- Free fresh install sin plan: recomendado visible en Entrenar/Plan.
- Free con plan activo: recomendado oculto en Hoy y Entrenar/Plan; plan activo visible.
- Free con plan desactivado: recomendado visible, planes guardados visibles como inactivos.
- Pro con multiples planes: solo activo se muestra como seleccionado; otros como guardados.
- Plan con datos reales: charts con volumen/adherencia.
- Plan sin datos: estado vacio educativo, sin graficas falsas.

### Regresion de monetizacion

- Activar programa de catalogo sin Pro sigue abriendo paywall.
- Crear segundo plan en Free sigue abriendo paywall o reemplazo explicito.
- Advanced analytics sigue gated donde ya estaba.
- Libreria de ejercicios y rutinas libres no se degradan.

---

## 10. Criterios de aceptacion de producto

- Si hay plan activo, el usuario ve siempre el mismo plan en Hoy, Entrenar/Plan, Calendario, Progreso, detalles, Watch y widgets.
- Si no hay plan activo, el recomendado aparece como ayuda para empezar, no como dato historico.
- Desactivar plan significa quedar sin plan activo.
- El plan activo muestra ejecucion real: adherencia, volumen, sets, carga, evolucion e involucion.
- Las proyecciones estimadas no se mezclan con datos reales.
- Free y Pro mantienen limites claros.
- No se pierde:
  - Musica del plan.
  - Training days.
  - Program library.
  - Workout library.
  - Tools.
  - Progreso.
  - SmartProgressionAdvisor.
  - Calendario.
  - Entreno libre.

---

## 11. Riesgos y mitigaciones

| Riesgo | Mitigacion |
|---|---|
| Sesiones antiguas sin planID producen datos ambiguos | Fallback por titulo/ejercicios y etiqueta interna de inferido |
| Cambiar desactivacion puede sorprender a usuarios con multiples planes | Copy claro: "Desactivar deja sin plan activo"; accion separada "Cambiar plan" |
| Free percibe bloqueo agresivo | Permitir reemplazar plan recomendado por el plan guardado existente, con confirmacion |
| Graficas vacias en usuarios nuevos | Estados vacios utiles: "Completa 1 sesion para ver evolucion real" |
| Demasiada analitica en Hoy | Hoy solo resumen; detalle vive en Plan/Progreso |
| Colores rompen lenguaje visual | Mantener lima como marca/CTA y usar semanticos solo para estado |

---

## 12. Orden recomendado de implementacion

1. Fase 0: hotfix de visibilidad + desactivacion real.
2. Fase 1: selector central `trainingPlanState`.
3. Fase 2: `PlanExecutionAnalyzer` con tests.
4. Fase 3: `ActivePlanExecutionCard` y detalle con graficas reales.
5. Fase 4: recomendado como onboarding sin plan, con limites Free/Pro.
6. Fase 5: barrido de consistencia y snapshots.

Este orden permite enviar una correccion rapida primero y despues elevar el producto sin bloquearse en una reforma grande.

