# Propuesta de refactor del onboarding de Reps

Fecha: 2026-06-24

## Objetivo

Redisenar el onboarding para que se sienta mas profesional, completo, atractivo y fluido sin tirar lo valioso que ya existe. La direccion recomendada es conservar la capacidad diferencial de Reps de generar un plan real y mostrarlo con anatomia/musculo/progreso, pero reorganizar el flujo para reducir friccion, mejorar ritmo visual y separar mejor responsabilidades de producto, UI y dominio.

Inputs usados:

- Codigo actual: `Reps/Features/Onboarding/ProfileSetupView.swift`, `WelcomeView.swift`, `OnboardingResult.swift`, `AppStore.swift`, `RootView.swift`, `HealthKitService.swift`, `PermissionService.swift`.
- Documento inicial: `/Users/romerosoft/Downloads/alcanceinicial.md`.
- Benchmark visual: capturas y video adjuntos de GymHub.
- Contexto del proyecto: `PROJECT_PLAN.md` y `ADVANCED_SCOPE_AUDIT.md`.

## Resumen ejecutivo

El onboarding actual no esta mal planteado: ya tiene una promesa fuerte, genera un plan real, usa MuscleMap, calcula una vista previa y persiste perfil, metrica corporal y plan activo. Eso es mas sustancial que el flujo de la competencia, que vende muy bien la personalizacion pero en las capturas parece mezclar demasiadas areas: training, nutricion, recovery, Apple Health y notificaciones.

El principal problema de Reps es la composicion: `ProfileSetupView.swift` concentra 2.116 lineas con estado, navegacion, pantallas, componentes, catalogo de equipamiento, generacion, forecast, paywall y permisos. El usuario ve menos pasos que la competencia, pero cada paso carga muchas decisiones. Eso crea densidad cognitiva y hace que el flujo parezca mas tecnico que premium.

La propuesta es pasar a un onboarding de 8 pantallas base:

1. Bienvenida / propuesta de valor.
2. Demo breve de valor.
3. Objetivo principal.
4. Experiencia.
5. Frecuencia y duracion.
6. Lugar/equipamiento.
7. Baseline corporal minimo.
8. Generacion y plan listo.

Y mover a onboarding progresivo:

- Notificaciones.
- Apple Health.
- Evento objetivo.
- Seleccion avanzada de musculos.
- Equipamiento avanzado.
- Paywall explicativo.
- Nutricion, recovery y biomarcadores.

## Auditoria del onboarding actual

### 1. Entrada y splash

Codigo relevante:

- `WelcomeView.swift` muestra `RepsLoadingView` durante 2,6 s antes de entrar a `ProfileSetupView`.
- `RootView.swift` bloquea la interfaz principal hasta `userProfile.onboardingCompleted`.

Hallazgo:

- La app arranca con una pantalla de carga emocional, no con una pantalla de valor o marca accionable.
- La competencia abre con hero de marca y CTA claro. Esto reduce incertidumbre y da control inmediato.

Impacto:

- Una espera fija al primer arranque puede sentirse como latencia artificial.
- El usuario todavia no sabe que recibira antes de esperar.

Recomendacion:

- Mantener `RepsLoadingView` como microtransicion de 600-900 ms o usarlo solo durante la generacion real del plan.
- Convertir la primera pantalla visible en un hero de marca con CTA: "Crear mi plan" y accion secundaria "Entrar / ya tengo cuenta" si aplica.

Prioridad: alta.

### 2. Orquestacion demasiado concentrada

Codigo relevante:

- `ProfileSetupView.swift` declara estado local para perfil, step, sexo, edad, altura, peso, duracion, musculos, generacion, evento objetivo y plan cacheado.
- `OnboardingStep` tiene 10 casos: presentation, sex, metrics, goal, training, focus, generating, plan, notifications, paywall.

Hallazgo:

- Un solo `View` controla pantallas, estado, reglas de avance, componentes y transformacion a `OnboardingResult`.
- El archivo ya tiene subviews internas, pero no separa la responsabilidad del flujo.

Impacto:

- Cualquier cambio de orden, branching o experimento A/B obliga a tocar el archivo mas grande.
- Es dificil medir abandono por paso porque el flujo no tiene una entidad propia de pantalla/route.
- La pantalla `paywall` existe en el enum y en UI, pero el flujo normal no parece alcanzarla desde notifications, lo que sugiere deuda o estado muerto.

Recomendacion:

- Extraer un `OnboardingDraft` como fuente de verdad del formulario.
- Extraer `OnboardingRoute`/`OnboardingStep` con metadatos: id, categoria, esOpcional, requiereSeleccion, CTA.
- Extraer `OnboardingCoordinatorView` para navegacion y `OnboardingScaffold` para layout.
- Mantener `OnboardingPlanBuilder` como servicio de dominio y cubrirlo con tests.

Prioridad: alta.

### 3. Pantallas con demasiadas decisiones

Ejemplos:

- `metricsStep` pide edad, altura y peso en una sola pantalla y muestra una recomendacion por BMI.
- `goalStep` combina objetivo principal con evento objetivo.
- `trainingStep` combina lugar, frecuencia, duracion y equipamiento.
- `equipmentStep` muestra catalogo avanzado por categorias.
- `planStep` muestra el plan completo, dias y ejercicios con muchos detalles tecnicos.

Hallazgo:

- El usuario no siempre tiene una unica decision por pantalla.
- Algunas pantallas ya parecen pantallas de ajustes avanzados, no onboarding.

Impacto:

- Mas carga cognitiva.
- Mas scroll.
- Menor sensacion premium, porque la UI parece configuracion densa.

Recomendacion:

- Llevar el onboarding base a una decision principal por pantalla.
- Usar pantallas compactas y visuales para capturar lo minimo que cambia el primer plan.
- Dejar detalles tecnicos para el plan activo y perfil, no para el embudo inicial.

Prioridad: alta.

### 4. Buen diferencial desaprovechado

Codigo relevante:

- `OnboardingPlanBuilder.makePlan(...)` crea un plan real.
- `generatingStep` usa `RepsLoadingView`, MuscleMap y resumen de sets/rest/semanas.
- `planStep` muestra ejercicios generados.

Hallazgo:

- Reps tiene algo que el benchmark solo simula parcialmente: puede crear un plan real y persistirlo.
- Pero la presentacion del resultado se vuelve muy detallada muy pronto.

Impacto:

- El usuario podria salir con una sensacion de valor mas fuerte si ve un resumen accionable y un CTA de primer entrenamiento.
- Mostrar todos los ejercicios antes de entrar puede parecer revision larga y frenar activacion.

Recomendacion:

- Mantener la generacion del plan como momento central.
- Cambiar la pantalla final a "Tu primer entreno esta listo" con:
  - dias/semana,
  - duracion estimada,
  - split principal,
  - 3 ejercicios destacados,
  - CTA: "Empezar primer entreno" o "Ir a Today".
- Dejar "Ver plan completo" como accion secundaria.

Prioridad: alta.

### 5. Permisos y paywall en el embudo

Codigo relevante:

- `notificationsStep` pide notificaciones antes de terminar.
- `enableRemindersAndFinish()` solicita permiso del sistema y finaliza onboarding.
- `HealthKitService.requestAuthorization()` existe, pero HealthKit se pide desde Profile, no desde onboarding.
- `paywallStep` existe como vista interna y hay CTA de beneficios Pro en plan.

Hallazgo:

- Notificaciones se piden con preprompt de beneficios, lo cual es bueno, pero siguen bloqueando antes de llegar a la experiencia principal.
- HealthKit esta mejor ubicado fuera del onboarding inicial.
- El paywall aparece como concepto dentro del onboarding, pero su flujo no esta limpio.

Impacto:

- Permisos y monetizacion pueden diluir el "aha moment".
- El usuario todavia no ha hecho su primer entreno cuando se le pide compromiso adicional.

Recomendacion:

- Completar onboarding al aceptar/ver el plan.
- Mover notificaciones a un nudge contextual despues de elegir o programar primer entreno.
- Mantener Apple Health como post-onboarding just-in-time: al importar entrenos, guardar sesion, leer peso o mostrar datos de recuperacion.
- Sacar `paywallStep` del enum base. El paywall debe ser modal/feature gate contextual, no un paso fantasma.

Prioridad: media-alta.

## Lectura del benchmark de la competencia

### Separacion de responsabilidades del flujo

El benchmark divide claramente:

1. Marca y promesa aspiracional.
2. Prueba de valor mediante pantallas de producto.
3. Captura de perfil personal.
4. Configuracion de training.
5. Lifestyle/nutricion/recovery.
6. Permisos.
7. Generacion de plan.
8. Entrada a home.

La separacion es buena, pero el alcance es demasiado amplio para una v1 centrada en entrenamiento.

### Componentes observados

- Hero oscuro con logo grande, fondo atmosferico y CTA blanco.
- Header consistente con back circular y barra de progreso horizontal.
- Option cards grandes con icono, titulo, descripcion y borde de seleccion.
- Chips de seleccion multiple para equipamiento.
- Selectores numericos tipo ruler/stepper.
- Pantallas de permiso con icono central, bullets y CTA principal.
- Pantalla de generacion con checklist de tareas.
- Mockups del producto para explicar valor antes de pedir datos.
- Bottom CTA fijo y muy visible.

### Fortalezas del benchmark

- Percepcion premium.
- Ritmo visual con mucho aire.
- Una decision clara por pantalla.
- Microcopy orientado a beneficio: "We'll build workouts you can actually do".
- Componentes coherentes y repetibles.
- Sensacion de avance constante gracias a progreso visible.

### Debilidades del benchmark

- Demasiado largo.
- Mezcla entrenamiento, nutricion, hidratacion, sueno, HealthKit y notificaciones.
- Pide muchos datos personales antes de valor final.
- La autorizacion de HealthKit parece demasiado amplia para una app centrada en training.
- Puede prometer mas de lo que una v1 enfocada en fuerza necesita entregar.

## Principio rector de la nueva version

El onboarding no debe construir el perfil perfecto. Debe llevar al usuario a su primer valor:

"Tengo un plan inicial adaptado a mi objetivo, mi tiempo y mi equipamiento, y se cual es mi primer entreno."

Indicador de activacion recomendado:

- Activacion primaria: usuario crea plan y llega a pantalla Today con primer entrenamiento listo.
- Activacion fuerte: usuario inicia o completa su primer entrenamiento.
- Activacion secundaria: usuario programa recordatorio o conecta Apple Health despues del primer valor.

Objetivo de duracion:

- 60-90 segundos para el flujo base.
- 8 pantallas base.
- Maximo 1 pantalla con scroll largo.
- Todas las pantallas con CTA fijo.

## Flujo propuesto v1

### Pantalla 0. Hero / bienvenida

Objetivo:

- Presentar marca y promesa sin friccion.

Copy sugerido:

- Titulo: "Entrena con un plan que progresa contigo"
- Subtitulo: "Reps crea tu rutina inicial, registra tus series y te muestra donde estas avanzando."
- CTA: "Crear mi plan"
- Secundario: "Ya tengo cuenta" si existe login.

Componentes:

- Logo/lockup de Reps.
- Fondo oscuro con glow sutil usando `PulseTheme`.
- CTA tipo capsula, preferiblemente usando `PrimaryButton`.

Decision:

- Sustituir espera fija de `WelcomeView` por hero inmediato.

### Pantalla 1. Demo breve de valor

Objetivo:

- Antes de pedir datos, explicar que hara Reps.

Copy sugerido:

- Titulo: "Del plan al progreso"
- Subtitulo: "Te damos un primer bloque de entrenamiento y convertimos cada sesion en datos utiles."

Contenido:

- 3 mini signals: "Plan", "Registro", "Musculo".
- Mini MuscleMap o tarjeta de plan resumida.

CTA:

- "Empezar"

Conservar del actual:

- La idea de `presentationStep`, pero con menos copy y menos densidad.

### Pantalla 2. Objetivo principal

Objetivo:

- Capturar el input que mas cambia reps, descansos y foco.

Opciones:

- Ganar musculo.
- Perder grasa.
- Fuerza.
- Volver a ser constante.

Copy:

- Titulo: "Cual es tu objetivo principal?"
- Subtitulo: "Ajustaremos volumen, reps y enfoque del plan."

Componentes:

- `OnboardingOptionCard` grande.

Conservar:

- `UserProfile.MainGoal`.

Mover:

- Evento objetivo sale de esta pantalla y pasa a post-onboarding o plan settings.

### Pantalla 3. Experiencia

Objetivo:

- Ajustar volumen inicial, complejidad y progresion.

Opciones:

- Principiante: "Menos de 1 ano entrenando de forma constante".
- Intermedio: "1-3 anos".
- Avanzado: "3+ anos".

Copy:

- Titulo: "Que experiencia tienes?"
- Subtitulo: "Esto evita que el plan empiece demasiado facil o demasiado agresivo."

Conservar:

- `UserProfile.Experience`.

### Pantalla 4. Frecuencia y duracion

Objetivo:

- Saber cuanto puede entrenar realmente el usuario.

Inputs:

- Frecuencia: 2-6 dias/semana.
- Duracion: 30, 45, 60, 75, 90 min.

Copy:

- Titulo: "Cuanto puedes entrenar?"
- Subtitulo: "Construiremos algo que puedas cumplir, no solo algo ideal."

Componentes:

- Segmented pills grandes.
- El numero seleccionado debe tener gran jerarquia visual, como el benchmark.

Conservar:

- `weeklyTrainingDays`.
- `sessionLengthMinutes`.

### Pantalla 5. Lugar y equipamiento

Objetivo:

- Evitar ejercicios que el usuario no puede hacer.

Estructura:

- Primero elegir preset:
  - Gimnasio completo.
  - Casa con material.
  - Minimo / peso corporal.
- Luego mostrar chips editables:
  - Barra, mancuernas, banco, maquinas, poleas, bandas, peso corporal, cardio.

Copy:

- Titulo: "Donde entrenas?"
- Subtitulo: "Solo usaremos ejercicios compatibles con tu setup."

Componentes:

- Option cards para preset.
- Chips de seleccion multiple para equipamiento.
- Accion secundaria: "Editar todo el equipamiento".

Cambios frente al actual:

- No mostrar el catalogo completo por categorias en onboarding base.
- Guardar preset y chips en `availableEquipment`.
- Dejar el catalogo avanzado para Perfil > Equipamiento.

### Pantalla 6. Baseline corporal minimo

Objetivo:

- Obtener datos que realmente alimentan cargas iniciales y metricas.

Inputs:

- Altura.
- Peso.
- Edad opcional o compacto.

Copy:

- Titulo: "Tu punto de partida"
- Subtitulo: "Nos ayuda a estimar cargas iniciales y progreso corporal."

CTA:

- "Continuar"
- Secundario: "Completar despues" si no es estrictamente necesario.

Cambios frente al actual:

- No meter una recomendacion BMI larga aqui.
- Si se muestra insight, que sea una frase corta: "Lo usaremos para ajustar el primer bloque."

Sobre genero/sexo:

- No abrir con sexo como paso obligatorio.
- Si MuscleMap necesita anatomia, pedirlo como preferencia de mapa:
  - "Mapa A"
  - "Mapa B"
  - "Prefiero no decirlo"
- Si se guarda `sex`, incluir `other` y opcion de omitir para alinear con `UserProfile.Sex`.

### Pantalla 7. Foco muscular opcional

Objetivo:

- Aprovechar el diferencial visual de Reps sin bloquear.

Decision:

- Hacerla opcional o mostrarla como "Quieres priorizar algo?"

Copy:

- Titulo: "Quieres priorizar alguna zona?"
- Subtitulo: "Si no eliges nada, crearemos un plan equilibrado."

CTA:

- "Continuar"
- Secundario: "Plan equilibrado"

Componentes:

- MuscleMap + chips.

Conservar:

- `OnboardingBodyPair`.
- `focusMuscles`.

### Pantalla 8. Generacion del plan

Objetivo:

- Convertir respuestas en sensacion de inteligencia y valor.

Copy:

- Titulo: "Creando tu primer bloque"
- Subtitulo: "Ajustando volumen, ejercicios y recuperacion."

Checklist:

- Guardando tu perfil.
- Filtrando ejercicios por equipo.
- Ajustando volumen semanal.
- Preparando tu primer entreno.

Regla:

- La generacion puede durar 1,5-2,2 s si es simulada.
- Si el plan ya esta listo, no alargar mas de lo necesario.

Conservar:

- `cachedPlan`.
- `OnboardingPlanBuilder.makePlan`.
- `RepsLoadingView`, pero con mensajes mas concretos.

### Pantalla 9. Plan listo / primer valor

Objetivo:

- Cerrar onboarding con una accion clara, no con una revision exhaustiva.

Copy:

- Titulo: "Tu primer entreno esta listo"
- Subtitulo: "Empieza con un plan de \(days) dias por semana, adaptado a tu objetivo y equipo."

Contenido:

- Resumen:
  - dias/semana,
  - duracion,
  - semanas,
  - foco principal.
- Top 3 ejercicios del primer dia.
- Mini MuscleMap o heatmap.

CTA:

- Principal: "Ir a mi primer entreno"
- Secundario: "Ver plan completo"

Resultado:

- Al tocar principal, `completeOnboarding(result:)` persiste perfil, metrica y plan, y navega a Today o WorkoutDetail del primer dia.

Cambios frente al actual:

- No listar todos los dias y ejercicios en onboarding.
- No pedir notificaciones antes de terminar.

## Que conservar, simplificar, mover o eliminar

| Elemento actual | Decision | Motivo |
| --- | --- | --- |
| `OnboardingPlanBuilder` | Conservar | Es el valor real del onboarding. |
| `RepsLoadingView` | Conservar y reutilizar | Buen componente para generacion, no como espera fija inicial. |
| `presentationStep` | Simplificar | Buena promesa, demasiado densa para primera pantalla. |
| `sexStep` | Mover/replantear | Solo debe pedirse si afecta mapa/calculos; incluir opcion no binaria/omitir. |
| `metricsStep` | Simplificar | Altura/peso/edad utiles, pero sin insight BMI largo. |
| `goalStep` | Conservar | Input esencial. |
| `targetEventCard` | Mover | Es especifico y no necesario para primer valor. |
| `trainingStep` | Dividir | Lugar, dias, duracion y equipo son demasiadas decisiones juntas. |
| `equipmentStep` | Simplificar | Catalogo avanzado abruma. Usar preset + chips base. |
| `focusStep` | Conservar como opcional | Diferencial visual fuerte, pero no debe bloquear. |
| `generatingStep` | Conservar | Buen cierre emocional si refleja trabajo real. |
| `planStep` | Simplificar | Debe vender primer valor, no auditar todo el plan. |
| `notificationsStep` | Mover | Mejor pedir tras ver primer entreno o programar recordatorio. |
| `paywallStep` | Eliminar del flujo base | Debe ser modal/feature gate, no step interno no claro. |

## Arquitectura propuesta

### Nuevos tipos sugeridos

`OnboardingDraft`

- Responsabilidad: guardar inputs del flujo antes de persistir.
- Campos: goal, experience, weeklyTrainingDays, sessionLengthMinutes, trainingLocation, equipmentPreset, availableEquipment, age, heightCm, weightKg, bodyMapPreference, focusMuscles.
- Metodo: `makeResult(planBuilder:) -> OnboardingResult`.

`OnboardingFlow`

- Responsabilidad: definir la secuencia de pasos por version y branch.
- Debe exponer: `steps`, `currentStep`, `progress`, `canContinue`, `next()`, `back()`.
- Permite A/B tests sin reescribir vistas.

`OnboardingStepDefinition`

- Campos: id, titleKey, category, isOptional, primaryCTAKey, secondaryCTAKey.
- Evita depender solo de `CaseIterable`.

`OnboardingPlanBuilder`

- Mantener como servicio de dominio.
- Anadir tests unitarios para:
  - dias/semana 2-6,
  - objetivo cambia reps/rest,
  - equipamiento casa/gimnasio,
  - focusMuscles afecta prioridades,
  - plan cacheado coincide con plan guardado.

### Nuevos componentes sugeridos

`OnboardingScaffold`

- Header de progreso.
- Area de contenido.
- CTA fijo inferior.
- Back button.
- Skip solo en pantallas adecuadas.

`OnboardingOptionCard`

- Icono, titulo, subtitulo, estado selected, tint.
- Reutilizable para goal, experience, preset de equipo.

`OnboardingSegmentedPills`

- Para frecuencia y duracion.

`OnboardingMetricPicker`

- Ruler/stepper compacto para altura, peso, edad.

`OnboardingEquipmentPresetView`

- Presets + chips base.

`OnboardingPlanReadyView`

- Resumen accionable del plan generado.

`OnboardingPermissionNudgeView`

- Pantallas post-onboarding para notifications/HealthKit.

### Estructura de archivos sugerida

```text
Reps/Features/Onboarding/
  OnboardingCoordinatorView.swift
  OnboardingFlow.swift
  OnboardingDraft.swift
  OnboardingResult.swift
  OnboardingPlanBuilder.swift
  Views/
    OnboardingScaffold.swift
    OnboardingHeroView.swift
    OnboardingValueDemoView.swift
    OnboardingGoalView.swift
    OnboardingExperienceView.swift
    OnboardingScheduleView.swift
    OnboardingEquipmentView.swift
    OnboardingBodyBaselineView.swift
    OnboardingFocusMusclesView.swift
    OnboardingGeneratingView.swift
    OnboardingPlanReadyView.swift
  Components/
    OnboardingOptionCard.swift
    OnboardingMetricPicker.swift
    OnboardingProgressHeader.swift
    OnboardingBottomBar.swift
    OnboardingEquipmentChip.swift
    OnboardingPermissionRow.swift
```

No hace falta introducir MVVM pesado. Para este caso encaja mejor una vista coordinadora con `@State private var draft`, mas servicios de dominio puros.

## Permisos

### Notificaciones

Mover fuera del onboarding base.

Momento recomendado:

- Despues de que el usuario vea su primer entreno o configure dias de entreno.

Preprompt:

- Titulo: "Quieres que te avisemos antes de entrenar?"
- Bullets:
  - Recordatorios segun tus dias.
  - Avisos si rompes la racha.
  - Resumen semanal.
- CTA: "Activar recordatorios"
- Secundario: "Ahora no"

### Apple Health

No pedir en onboarding base.

Momentos recomendados:

- Al importar entrenos.
- Al guardar un workout en Health.
- Al rellenar peso/altura desde Health.
- Al mostrar recovery/HRV/sueno.

Subset recomendado para v1 training:

- Workouts.
- Body mass y height si se usan.
- Active energy si se muestra.
- Heart rate y route solo si el flujo de cardio/workout lo usa de verdad.

Evitar en onboarding:

- Nutricion.
- Agua.
- Biomarcadores avanzados.
- Solicitud masiva sin contexto.

## Telemetria recomendada

Eventos:

- `onboarding_started`
- `onboarding_step_viewed`
- `onboarding_step_completed`
- `onboarding_step_back`
- `onboarding_step_skipped`
- `onboarding_plan_generated`
- `onboarding_completed`
- `onboarding_first_workout_cta_tapped`
- `onboarding_permission_nudge_viewed`
- `onboarding_permission_granted`
- `onboarding_permission_skipped`

Parametros:

- `flow_version`
- `step_id`
- `step_index`
- `step_count`
- `goal`
- `experience`
- `days_per_week`
- `equipment_preset`
- `has_focus_muscles`
- `duration_seconds`

Metricas de producto:

- Completion rate por paso.
- Tiempo total hasta plan generado.
- % que pulsa "Ir a mi primer entreno".
- % que inicia primer entreno en la primera sesion.
- % que completa primer entreno en 24 h.
- Opt-in notifications despues de primer valor.
- Opt-in Apple Health por contexto.

## Roadmap de implementacion

### Fase 1. Refactor sin cambio funcional

Objetivo:

- Reducir riesgo antes de cambiar UX.

Tareas:

- Extraer `OnboardingPlanBuilder` a archivo propio si se quiere aislar mas.
- Crear `OnboardingDraft`.
- Extraer scaffold, header, bottom bar y option card.
- Mover equipamiento/catalogos a tipos propios.
- Mantener el flujo actual mientras se verifica compilacion.

Validacion:

- Tests de `OnboardingPlanBuilder`.
- Snapshot/manual en iPhone pequeno y grande.

### Fase 2. Flujo compacto

Objetivo:

- Implementar la nueva secuencia de 8-9 pantallas.

Tareas:

- Cambiar `OnboardingStep` a flujo versionado.
- Separar training en experiencia, frecuencia/duracion y equipamiento.
- Simplificar metrics.
- Mover target event fuera del onboarding.
- Hacer focus muscles opcional.
- Sustituir plan completo por plan summary.

Validacion:

- Completar onboarding en menos de 90 s.
- Plan guardado coincide con plan preview.
- Today recibe plan activo.

### Fase 3. Onboarding progresivo

Objetivo:

- Pedir permisos y configuraciones avanzadas en contexto.

Tareas:

- Notification nudge despues de plan listo/primer workout.
- HealthKit nudge en Profile, Progress o import/save flows.
- Equipment advanced editor en Profile.
- Target event en plan settings.

Validacion:

- Usuario puede cerrar todos los nudges sin quedar bloqueado.
- No se solicita permiso del sistema sin preprompt.

### Fase 4. Pulido visual y motion

Objetivo:

- Acercar la percepcion premium del benchmark sin copiar su longitud.

Tareas:

- Hero mas aspiracional.
- Transiciones horizontales entre pasos.
- Numeros grandes en frecuencia/duracion/metricas.
- Haptics en seleccion.
- Animacion corta en plan generation.
- Respetar Reduce Motion.

Validacion:

- No hay saltos de layout con teclado.
- CTA fijo no tapa contenido.
- Scroll solo cuando el contenido lo justifica.

## Riesgos

1. Quitar demasiadas preguntas puede bajar precision del plan.
   - Mitigacion: conservar solo inputs que cambian el primer plan y pedir lo demas despues.

2. Hacer focus muscles opcional puede ocultar un diferencial visual.
   - Mitigacion: mostrarlo como pantalla opcional atractiva con "plan equilibrado" como salida rapida.

3. Mover notificaciones puede bajar opt-in inicial.
   - Mitigacion: pedirlas despues de que el usuario vea su plan y con recordatorio ligado a sus dias.

4. Sacar paywall del flujo puede reducir exposicion.
   - Mitigacion: usar paywall contextual despues del valor, no antes del primer momento de activacion.

5. Refactor grande en una pantalla critica.
   - Mitigacion: fase 1 sin cambio funcional, tests de plan builder y QA manual del flujo completo.

## Decision final recomendada

No copiar el benchmark. Usar su ejecucion visual y separacion de pantallas, pero mantener la ventaja de Reps: plan real, MuscleMap, analitica y primer entreno accionable.

La version final debe sentirse asi:

- Menos formulario, mas guia.
- Menos promesa generica, mas plan real.
- Menos permiso temprano, mas permiso en contexto.
- Menos revision tecnica, mas siguiente accion.
- Menos archivo monolitico, mas flujo modular.
