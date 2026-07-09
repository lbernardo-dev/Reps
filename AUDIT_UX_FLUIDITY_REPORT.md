# Auditoria de fluidez visual y experiencia de StreakReps

Fecha: 2026-07-09  
Estado: auditoria estatica. No se ha validado con grabaciones ni pruebas de usuario.

## Resumen ejecutivo

StreakReps ya tiene una base visual rica: `PulseTheme`, tarjetas, graficos, haptics, Live Activities, widgets, Watch, overlays de logros, botones de accion rapida y estados vacios. La oportunidad principal no es "poner mas animaciones", sino hacer que los momentos centrales se sientan conectados:

- Registrar una serie.
- Completar un ejercicio.
- Terminar un workout.
- Mantener una racha.
- Ver progreso accionable.
- Volver despues de fallar.

La app corre el riesgo de sentirse muy completa pero densa. Para una app fitness/habitos, el valor debe aparecer en menos de un minuto y las recompensas deben reforzar progreso, no decorar.

## Evidencia y criterios

Confirmado por evidencia en codigo:

- Hay feedback haptico y visual al completar sets: `SetRow` anima check/estado y `ActiveWorkoutView` usa `.sensoryFeedback(.success, trigger: completedSets)` ([ActiveWorkoutView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Workout/ActiveWorkoutView.swift:319)).
- Hay empty states en calendario, progreso, catalogo y workout libre.
- Hay Live Activity con acciones de entrenamiento y metricas de ruta/fuerza ([RepsWorkoutLiveActivity.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/RepsWidgets/RepsWorkoutLiveActivity.swift:4)).
- Hay overlay de logros y motor de achievements ([AchievementEngine.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Services/AchievementEngine.swift:1)).
- Hay paywall contextual mediante `PaywallSource` y `ProductFeature` ([Monetization.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Models/Monetization.swift:25)).

Hipotesis pendiente de validacion:

- La densidad de Hoy y Progreso puede ocultar el CTA principal para usuarios principiantes.
- Algunas recompensas pueden sentirse tardias porque el valor emocional aparece al final, no durante el flujo.
- La mezcla de muchas cards/graficos puede transmitir potencia, pero tambien carga cognitiva.

## Hallazgos priorizados

### P1 - La accion central "registrar set" necesita un bucle de recompensa mas claro

Area: entrenamiento activo / microinteracciones  
Archivo: [ActiveWorkoutView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Workout/ActiveWorkoutView.swift:242), [ActiveWorkoutSetRowComponents.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Workout/Components/ActiveWorkoutSetRowComponents.swift:32)

Descripcion: existe feedback de check, escala, haptic y progreso. Falta un cierre visual mas fuerte pero sutil para "esta serie avanzo tu entrenamiento": incremento de anillo, cambio de proxima accion y mini confirmacion local.

Impacto usuario: completar una serie puede sentirse funcional, no necesariamente satisfactorio.  
Propuesta: al marcar set, usar una confirmacion compacta en `ActiveWorkoutCommandCard`: "Serie 2 registrada", progreso +1, descanso listo; mantener visible undo durante unos segundos.  
Complejidad: media.  
Riesgo: bajo si se limita al estado visual local.  
Validacion: grabar tap-to-feedback y comparar claridad con usuarios.

### P1 - Finalizar workout debe ser el momento de mayor recompensa

Area: resumen / retencion  
Archivo: [ActiveWorkoutView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Workout/ActiveWorkoutView.swift:607), [AppStore.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/App/AppStore.swift:1121), [RootView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/App/RootView.swift:113)

Descripcion: al finalizar se genera sesion, se presenta summary y se actualizan logros, PR, streak y possible paywall. Falta garantizar que resumen, racha, PR, volumen y "volver manana" aparezcan como una narrativa unica.

Impacto usuario: el cierre puede sentirse como "guardado" en vez de "progreso logrado".  
Propuesta: `WorkoutSummaryView` debe mostrar en orden: 1) logro primario, 2) racha/consistencia, 3) volumen o PR, 4) siguiente entrenamiento recomendado, 5) accion secundaria compartir/guardar.  
Complejidad: media.  
Riesgo: bajo-medio por paywall/summary existente.  
Validacion: test de primer workout y quinto workout, revisar si paywall no interrumpe demasiado pronto.

### P1 - Hoy tiene mucho valor, pero el foco principal puede diluirse

Area: dashboard / activacion  
Archivo: [TodayView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Today/TodayView.swift:295)

Descripcion: Hoy mezcla readiness, weather, outdoor intelligence, workout, recomendaciones, senales, wellness, plan y shortcuts. Es potente, pero puede perder jerarquia para el usuario que solo quiere entrenar rapido.

Impacto usuario: principiantes pueden no entender cual es el siguiente paso.  
Propuesta: establecer una jerarquia fija: "Continuar/Empezar" siempre como primer bloque util, despues readiness y recomendaciones. En modo no iniciado, mostrar CTA persistente de 1 tap.  
Complejidad: media.  
Riesgo: medio por rediseño de dashboard.  
Validacion: tiempo hasta primer workout registrado en onboarding/primer uso.

### P2 - Estados de carga existen, pero no hay modelo visual uniforme por seccion

Area: perceived performance / loading states  
Archivo: [ExerciseLibraryView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Exercises/ExerciseLibraryView.swift:251), [RepsLoadingView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/DesignSystem/RepsLoadingView.swift:1)

Descripcion: hay `RepsLoadingView` y mensajes de sincronizacion de catalogo, pero no se ve un patron unico para loading, refreshing, stale, empty y failed por seccion.

Impacto usuario: algunas esperas pueden sentirse como contenido vacio o cambios bruscos.  
Propuesta: definir `SectionLoadState`: loading initial, loaded, empty actionable, refreshing stale, failed retry. Aplicarlo a catalogo, social, progreso avanzado y HealthKit.  
Complejidad: media.  
Riesgo: bajo.  
Validacion: UI tests de estados y screenshots.

### P2 - Calendario muestra datos, pero la racha podria ser mas emocional

Area: streak / calendario  
Archivo: [CalendarView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Calendar/CalendarView.swift:285)

Descripcion: calendario muestra racha, sesiones, volumen y puntos por dia. Falta una capa motivacional para riesgo de perder racha, recuperacion y continuidad semanal.

Impacto usuario: la racha puede verse como numero, no como compromiso.  
Propuesta: añadir estados: "racha segura hoy", "te falta 1 sesion esta semana", "puedes recuperar manana", sin castigar al usuario.  
Complejidad: baja-media.  
Riesgo: bajo.  
Validacion: feedback cualitativo y tasa de retorno al dia siguiente.

### P2 - Progreso es rico, pero puede parecer dashboard pesado

Area: estadisticas / claridad  
Archivo: [ProgressView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Progress/ProgressView.swift:45)

Descripcion: hay anillos, tendencias, tarjetas, load, cardio, body, muscles, insights. Falta una lectura simple: "que mejoro", "que hacer ahora", "por que importa".

Impacto usuario: las estadisticas pueden motivar menos si exigen interpretacion.  
Propuesta: cada bloque principal debe terminar con una accion: progresar peso, descansar, repetir rutina, trabajar grupo rezagado, crear objetivo.  
Complejidad: media.  
Riesgo: bajo.  
Validacion: test de comprension: usuario explica en 10 s que hacer despues de ver Progreso.

### P2 - Watch Pro lock puede reducir percepcion de valor si aparece antes del beneficio

Area: Apple Watch / monetizacion  
Archivo: [WatchWorkoutView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/RepsWatch/WatchWorkoutView.swift:65)

Descripcion: Watch muestra lock si no hay acceso. Es correcto para feature Pro, pero conviene que el iPhone muestre antes el valor concreto de Watch.

Impacto usuario: bloqueo temprano puede sentirse como "esta roto" si no se explica en la app principal.  
Propuesta: en iPhone, tarjeta Pro Watch con preview de logging rapido, ruta, pulso y Live Activity; desde Watch, copy breve + instruccion "activalo en iPhone".  
Complejidad: baja-media.  
Riesgo: bajo.  
Validacion: conversion y soporte.

### P3 - Microcopy mixto y textos genericos

Area: copy / localizacion  
Archivos: multiples vistas contienen strings literales en espanol/ingles junto a keys localizadas. Ejemplos: [TodayView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Today/TodayView.swift:303), [ActiveWorkoutView.swift](/Users/romerosoft/Work/DESARROLLO/SWIFT/Reps/Reps/Features/Workout/ActiveWorkoutView.swift:1462)

Impacto usuario: inconsistencia de tono y localizacion.  
Propuesta: normalizar microcopy para acciones centrales: empezar, registrar, descanso, progreso, racha, recuperar.  
Complejidad: baja.  
Riesgo: bajo.  
Validacion: snapshot de ES/EN.

## Animaciones recomendadas

- Completar serie: check + mini pulse del progreso + undo visible, max 250 ms.
- Completar ejercicio: transicion hacia siguiente ejercicio con direccion y haptic `.success`.
- Descanso terminado: cambio de color y haptic; no modal si el usuario esta activo.
- Finalizar workout: resumen con staged reveal: sesion guardada, progreso, racha, PR.
- Alcanzar objetivo: badge compacto, no pantalla completa salvo milestone importante.
- Cambiar filtros: crossfade de resultados + contador estable, sin saltos.
- Empty states: aparecer con opacity/move ligero y CTA claro.

## Microinteracciones recomendadas

- Tap inmediato en CTA principal con estado pressed.
- `saving/synced` discreto para workout activo y backup Pro.
- Haptic diferenciado: selection para navegacion, light para set normal, success para ejercicio completo/PR, warning para terminar.
- Indicador de riesgo de racha con tono amable, no culpabilizante.
- Skeletons por seccion donde el contenido es predecible.
- Refresh stale: mantener datos visibles con etiqueta "Actualizando".

## Normalizacion visual

- Consolidar botones principales: empezar, completar, finalizar, crear.
- Consolidar tarjetas metricas: valor, delta, accion recomendada.
- Limitar tarjetas anidadas; mantener densidad de herramienta operativa.
- Asegurar Dynamic Type en cards densas y Watch.
- Revisar modo oscuro con gradients/glass y contraste de textos secundarios.

## Validacion de fluidez

- Grabaciones: tap set -> feedback, finish workout -> summary, abrir Progreso, cambiar filtro catalogo.
- UI tests: empty/loading/error/refreshing por seccion.
- SwiftUI/Animation Hitches: ActiveWorkout, Progress, Calendar.
- Usuarios: 5 principiantes deben registrar un primer workout en menos de 60 s.
