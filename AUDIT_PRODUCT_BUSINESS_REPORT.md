# Auditoria de producto y negocio de StreakReps

Informe producido por el subagente `FitnessProductBusinessAuditor`.

## Resumen ejecutivo

StreakRep ya tiene una base funcional amplia: onboarding personalizado, Today, workout activo, planes, progreso, goals, calendario, logros, notificaciones, social, widgets, Watch y Live Activity. La mayor fisura de producto no es ausencia de features, sino conexion entre momentos de valor: el onboarding genera un plan, pero para usuarios free no lo activa; Goals existen, pero su progreso parece manual; y algunos paywalls pierden contexto al delegarse a RevenueCatUI.

Prioridad: reducir friccion hasta el primer workout util, convertir despues de valor demostrado y cerrar loops de retencion con objetivos autocalculados.

## Arquitectura funcional detectada

- Shell principal: `Today`, `Entrenar`, `Progreso`, `Ejercicios`, `Perfil`; calendario como sheet y quick actions en [RootView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/App/RootView.swift:223).
- Estado central: `AppStore` gestiona perfil, monetizacion, planes, sesiones, goals, social, widgets, Watch y Live Activity en [AppStore.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/App/AppStore.swift:26).
- Onboarding: recoge objetivo, experiencia, agenda, equipamiento, metricas y musculos foco; genera plan local en [ProfileSetupView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Onboarding/ProfileSetupView.swift:742).
- Monetizacion: RevenueCat, features Pro y gates por fuente en [Monetization.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Models/Monetization.swift:30).
- Retencion: in-app inbox, reminders, streak at risk, weekly recap, deload, PR y goal reached en [NotificationEngine.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Services/NotificationEngine.swift:24).
- Ecosistema Apple: widgets, Watch, Live Activity y App Intents conectados por snapshot compartido en [WorkoutShared.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/RepsShared/WorkoutShared.swift:303).

## Hallazgos priorizados

### P0

No se ha encontrado un bloqueo critico confirmado que impida usar la app de forma global.

### P1 - Onboarding genera plan pero no lo activa para usuarios free

Confirmado por evidencia en codigo: `makeResult()` devuelve `activatePlan: store.monetization.hasProAccess` y `completeOnboarding` llama `addPlan(plan, activate: result.activatePlan && monetization.hasProAccess)` en [ProfileSetupView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Onboarding/ProfileSetupView.swift:742) y [AppStore.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/App/AppStore.swift:909). En la pantalla ready hay boton Pro y `continue free` en [ProfileSetupView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Onboarding/ProfileSetupView.swift:625).

Hipotesis pendiente de validacion: usuarios free terminan onboarding esperando entrenar con su plan, pero aterrizan sin plan activo y deben descubrir como activarlo.

Mejora UX/producto recomendada: activar automaticamente el primer plan generado como beneficio free, o cambiar copy a "guardar plan y activarlo desde Entrenar" con CTA directo. Impacto alto en activacion. Complejidad media. Validar tasa de primer workout en D0/D1.

### P1 - Paywall contextual definido pero no usado visualmente

Confirmado por evidencia en codigo: `PaywallView.body` renderiza `RevenueCatUI.PaywallView` directamente en [PaywallView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Monetization/PaywallView.swift:30). Las secciones nativas `paywallHero`, timeline, planes y CTA existen pero quedan fuera del body en [PaywallView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Monetization/PaywallView.swift:68). `PaywallSource` si tiene titulos/subtitulos contextuales en [Monetization.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Models/Monetization.swift:209).

Hipotesis pendiente de validacion: la conversion baja porque todas las fuentes parecen el mismo paywall remoto.

Mejora UX/producto recomendada: mantener RevenueCat para compra, pero envolverlo con header/preview contextual por fuente: onboarding plan, analytics, Watch, programas, backups. Impacto alto. Complejidad media. Validar paywall CTR, purchase completion y dismiss reason por source.

### P1 - Goals existen pero el progreso parece manual

Confirmado por evidencia en codigo: `Goal` usa `current/target` para `progress` en [Models.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Models/Models.swift:800). `addGoal/updateGoal` solo persisten el objeto en [AppStore.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/App/AppStore.swift:2815). El motor celebra goals solo si `goal.current >= goal.target` en [NotificationEngine.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Services/NotificationEngine.swift:145).

Hipotesis pendiente de validacion: usuarios no actualizan goals manualmente y el feature no retiene.

Mejora UX/producto recomendada: goals derivados por tipo: sesiones/semana, volumen, PR, peso, pasos, agua. Impacto alto. Complejidad media. Validar creacion de goals, goal completion y retorno semanal.

### P1 - `Mark as done` desde notificacion puede inflar cumplimiento sin sesion

Confirmado por evidencia en codigo: `markScheduledWorkoutCompleted` solo cambia `ScheduledWorkout.status = .completed` en [AppStore.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/App/AppStore.swift:354); no crea `WorkoutSession`.

Hipotesis pendiente de validacion: el calendario/plan muestra adherencia, pero progreso/carga/volumen no reflejan entrenamiento real.

Mejora UX/producto recomendada: renombrar a "Marcar plan como hecho" o abrir "log rapido" con duracion/esfuerzo minimo. Impacto medio-alto. Riesgo bajo. Validar discrepancia scheduled completed vs sessions.

### P2 - Today tiene mucho valor, pero compite con la accion principal

Confirmado por evidencia en codigo: Today carga readiness, weather, insights, workout, recommended workout, senales, wellness widgets, plan y shortcuts en [TodayView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Today/TodayView.swift:295). Si no hay plan activo, se genera recomendado en [TodayView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Today/TodayView.swift:459).

Hipotesis pendiente de validacion: usuarios nuevos no identifican rapido "que hago ahora".

Mejora UX/producto recomendada: modo first-week con una unica CTA dominante: "Entrena hoy", "activar plan guardado" o "empezar recomendado". Validar first workout completion.

### P2 - Social es potente pero dependiente de cold start e iCloud

Confirmado por evidencia en codigo: social requiere iCloud disponible y username en [SocialOnboardingView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Social/SocialOnboardingView.swift:25). Hay feed, friends, challenges y discover en [SocialHubView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Social/SocialHubView.swift:36).

Hipotesis pendiente de validacion: activacion social temprana sin amigos produce vacio.

Mejora UX/producto recomendada: pedir social despues del primer logro/workout compartible, con invitacion y preview. No bloquear valor core por iCloud. Complejidad media.

### P2 - Gamificacion amplia, pero falta ajuste responsable por recuperacion

Confirmado por evidencia en codigo: logros por streak, sesiones, volumen, PR, cardio, fotos e hidratacion en [AchievementEngine.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Services/AchievementEngine.swift:52); XP por sesiones, PR, volumen y streak en [GamificationEngine.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Services/GamificationEngine.swift:33).

Hipotesis pendiente de validacion: streak/XP puede incentivar entrenar cuando la bateria recomienda recuperacion.

Mejora UX/producto recomendada: añadir logros de descanso, deload, movilidad y consistencia saludable. Validar retencion sin aumentar sobreentrenamiento.

### P3 - Copy hardcoded/multilingue disperso

Confirmado por evidencia en codigo: alertas en espanol literal en [TodayView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Today/TodayView.swift:422), "Crear plan Pro" en [PlansView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Plans/PlansView.swift:523), textos ingleses en Program Library en [ProgramLibraryView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Plans/ProgramLibraryView.swift:237).

Hipotesis pendiente de validacion: afecta confianza, ASO/localizacion y percepcion premium.

Mejora UX/producto recomendada: extraer strings y revisar tono por idioma. Complejidad baja.

## Respuestas breves al brief

- Fisuras funcionales: plan onboarding no activo en free; goals sin auto-sync; mark done sin sesion.
- Funciones incompletas o mal conectadas: paywall contextual no usado; social notification comenta que no enruta al hub social en [NotificationService.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Services/NotificationService.swift:451).
- Carencias de mercado: falta un "coach loop" mas simple: hoy toca esto, hazlo, aprende del resultado, ajusta manana.
- Adopcion: reducir onboarding-to-first-workout.
- Retencion: convertir goals y calendario en loops automaticos, no manuales.
- Gamificacion responsable: premiar recuperacion y consistencia sostenible.
- Conversion premium: pedir Pro tras preview real de plan/analytics/Watch, no como bloqueo generico.

## Roadmap funcional priorizado

1. 0-2 semanas: activar primer plan free o CTA directa post-onboarding; instrumentar funnel onboarding -> first workout.
2. 0-2 semanas: paywall contextual por source y telemetria real de CTA/purchase/dismiss.
3. 2-4 semanas: goals autocalculados por sesiones, volumen, PR, peso, pasos y agua.
4. 2-4 semanas: separar "mark done" de "log workout" en notificaciones/calendario.
5. 4-6 semanas: first-week Today mode y nudges de activacion.
6. 6-8 semanas: gamificacion responsable y social onboarding post-logro.

## Oportunidades premium

- Pro Analytics: insights accionables con preview personalizada tras 3-5 workouts.
- Pro Programs: bloques de entrenamiento activables, periodizacion y deload.
- Pro Watch: logging desde Watch, gym pass y workout offline, ya bloqueado por `hasWatchAccess`.
- Pro Progression: auto-progression, RPE/RIR/tempo y ajustes de carga.
- Pro Backup/Export: seguridad de historial y restauracion.
- Pro Share: receipt gallery, share cards y comparativas visuales.
