# Reps - Backlog

Estados sugeridos: `[ ]` pendiente, `[~]` en progreso, `[x]` completado, `[!]` bloqueado.

## Descubrimiento

- [x] T-001 Analizar pantallas de Stitch en `Diseños/stitch_pulse_fitness`.
- [x] T-002 Extraer sistema visual, navegacion y flujos principales.
- [x] T-003 Definir alcance MVP y fases de implementacion.

## Fase 0 - Proyecto base

- [x] T-010 Confirmar nombre final de app, bundle id, target minimo iOS y persistencia.
- [x] T-011 Crear proyecto iOS nativo desde cero.
- [x] T-012 Configurar estructura de carpetas: App, DesignSystem, Models, Services, Features, Resources.
- [x] T-013 Configurar localizacion ingles/espanol con String Catalog.
- [x] T-014 Configurar assets base: icono temporal, colores y placeholders.
- [x] T-015 Agregar seed data inicial de ejercicios, planes y sesiones.
- [x] T-016 Crear build inicial y verificar en simulador.
- [x] T-017 Configurar HealthKit capability y permisos para peso/talla.

## Fase 1 - Design system

- [x] T-020 Implementar tokens de color basados en los disenos.
- [x] T-021 Implementar tipografia y helpers de espaciado.
- [x] T-022 Crear `PulsePrimaryButton` y `PulseSecondaryButton`.
- [x] T-023 Crear `PulseCard`, `StatCard` y `ProgressBar`.
- [x] T-024 Crear rows reutilizables para ejercicios, planes y settings.
- [x] T-025 Crear componentes de segmented control, chips y empty states.
- [x] T-026 Crear previews en ingles y espanol.

## Fase 2 - Datos y dominio

- [x] T-030 Implementar `UserProfile`.
- [x] T-031 Implementar `Exercise`.
- [x] T-032 Implementar `WorkoutPlan`, `WorkoutDay` y `WorkoutExercise`.
- [x] T-033 Implementar `ScheduledWorkout`.
- [x] T-034 Implementar `WorkoutSession`, `ExerciseLog` y `SetLog`.
- [x] T-035 Implementar `Goal` y `BodyMetric`.
- [x] T-036 Implementar conversion kg/lb.
- [x] T-037 Implementar calculos de volumen, PR, streak, completion y estimated 1RM.
- [x] T-038 Agregar tests unitarios de calculos.
- [x] T-039 Implementar `HealthKitService` para leer/escribir peso y talla.
- [x] T-039A Migrar persistencia completa del modelo a SwiftData con migracion desde JSON legacy.

## Fase 3 - Navegacion y onboarding

- [x] T-040 Crear app shell con `TabView`: Today, Plans, Progress, Calendar, Profile.
- [x] T-041 Implementar Welcome.
- [x] T-042 Implementar selector de idioma.
- [x] T-043 Implementar perfil de entrenamiento: ubicacion, objetivo y nivel.
- [x] T-044 Implementar selector de dias semanales.
- [x] T-045 Persistir preferencias y marcar onboarding completo.
- [x] T-046 Validar layouts en ingles y espanol.

## Fase 4 - Planes y plan builder

- [x] T-050 Implementar pantalla Plans.
- [x] T-051 Implementar active plan card y lista de planes.
- [x] T-052 Implementar detalle de plan/rutina.
- [x] T-053 Implementar Create Plan Step 1: Basic Info.
- [x] T-054 Implementar Step 2: Schedule.
- [x] T-055 Implementar Step 3: Workouts y ejercicios.
- [x] T-056 Implementar Step 4: Review & Save.
- [x] T-057 Activar plan y generar calendario inicial.
- [x] T-058 Implementar editar/desactivar plan.

## Fase 5 - Today y calendario

- [x] T-060 Implementar Today con entrenamiento del dia.
- [x] T-061 Implementar card de racha.
- [x] T-062 Implementar card de avance semanal.
- [x] T-063 Implementar ultimo entrenamiento.
- [x] T-064 Implementar meta activa.
- [x] T-065 Implementar empty state sin entrenamiento.
- [x] T-066 Implementar calendario mensual.
- [x] T-067 Implementar detalle de dia.
- [x] T-068 Implementar programar/reprogramar entrenamiento.

## Fase 6 - Workout activo

- [x] T-070 Implementar Workout Detail.
- [x] T-071 Implementar inicio de workout session.
- [x] T-072 Implementar timer general.
- [x] T-073 Implementar rest timer con skip.
- [x] T-074 Implementar tabla/lista de sets.
- [x] T-075 Implementar steppers de peso y reps.
- [x] T-076 Implementar completar set.
- [x] T-077 Implementar agregar set.
- [x] T-078 Implementar notas por ejercicio.
- [x] T-079 Implementar siguiente ejercicio.
- [x] T-080 Implementar Finish Workout y persistencia.
- [x] T-081 Implementar resumen post-workout.

## Fase 7 - Progreso y metas

- [x] T-090 Implementar Progress dashboard.
- [x] T-091 Implementar stats: total workouts, volumen y PRs.
- [x] T-092 Implementar grafica de consistencia.
- [x] T-093 Implementar Bench Press Max / meta destacada.
- [x] T-094 Implementar body weight metrics.
- [x] T-094A Implementar height metric y seguimiento historico de talla.
- [x] T-095 Implementar distribucion por grupo muscular.
- [x] T-096 Implementar Exercise Progress.
- [x] T-097 Implementar toggles Weight, Reps, Volume y 1RM.
- [x] T-098 Implementar historial de sesiones por ejercicio.
- [x] T-099 Implementar Goals list y create/edit goal.

## Fase 8 - Biblioteca y perfil

- [x] T-110 Implementar Exercise Library.
- [x] T-111 Implementar busqueda.
- [x] T-112 Implementar filtros por musculo, equipo, dificultad y ubicacion.
- [x] T-113 Implementar Exercise Detail.
- [x] T-114 Implementar Add Custom Exercise.
- [x] T-115 Implementar Profile Settings.
- [x] T-116 Implementar cambio kg/lb.
- [x] T-117 Implementar cambio ingles/espanol.
- [x] T-118 Implementar preferencias de notificaciones.
- [x] T-119 Implementar conectar/desconectar Apple Health.

## Fase 9 - Calidad

- [x] T-130 Revisar accesibilidad: VoiceOver labels, Dynamic Type y touch targets.
- [x] T-131 Revisar contraste y estados light/dark si aplica.
- [x] T-132 Revisar localizacion completa EN/ES.
- [x] T-133 Probar flujo completo: onboarding -> plan -> workout -> progress.
- [x] T-134 Agregar tests de persistencia y dominio.
- [x] T-135 Build en simulador.
- [x] T-136 Preparar checklist de release interno.

## Auditoria avanzada

- [x] T-200 Analizar especificacion funcional avanzada y contrastarla con el estado actual.
- [x] T-201 Crear matriz de cobertura avanzada en `ADVANCED_SCOPE_AUDIT.md`.
- [x] T-202 Corregir backlog MVP para no marcar como completas funciones que solo existen en version basica.

## Fase A1 - Consolidacion UX/localizacion

- [x] T-210 Simplificar navegacion de Plan y bibliotecas.
- [x] T-211 Eliminar mezcla visible de ingles/espanol en rutas principales.
- [ ] T-212 Auditar todas las pantallas con capturas en iPhone pequeno/grande.
- [ ] T-213 Corregir padding horizontal inconsistente en listas, forms y subflujos.
- [x] T-214 Centralizar nombres de tabs, rutas y acciones principales.
- [ ] T-215 Aislar cadenas restantes en `Localizable.xcstrings`.

## Fase A2 - Modelo de datos avanzado

- [x] T-220 Extender `UserProfile` con nombre, fecha nacimiento, sexo, unidades distancia, equipamiento y preferencias avanzadas.
- [x] T-221 Extender `Exercise` con aliases, tipo, secundarios, modalidad, entorno, dificultad, errores, video, tags y metadata de fuente.
- [x] T-222 Extender `WorkoutPlan` y `WorkoutExercise` con objetivo, nivel, descanso, prioridad, cues y configuracion de progresion.
- [x] T-223 Extender `WorkoutSession` con inicio/fin, origen, ubicacion, contexto, RPE sesion y energia.
- [x] T-224 Extender `SetLog` con tipo de serie, RPE/RIR, tempo, descanso real, PR y notas.
- [x] T-225 Crear `CardioLog`.
- [x] T-226 Crear/expandir metricas de bienestar: medidas, fotos, sueno, fatiga, estres y molestias.
- [x] T-227 Implementar migracion SwiftData para los nuevos campos sin perder datos.

## Fase A3 - Logging avanzado

- [x] T-230 Crear entrenamiento libre accesible desde Home.
- [x] T-231 Permitir anadir ejercicios ad hoc durante una sesion activa.
- [x] T-232 Mostrar/ocultar campos avanzados segun preferencias.
- [x] T-233 Registrar tipo de serie.
- [x] T-234 Registrar RPE o RIR por serie.
- [x] T-235 Registrar tempo por serie.
- [x] T-236 Calcular descanso real previo automaticamente.
- [x] T-237 Detectar y mostrar PR por set.
- [x] T-238 Capturar RPE global, energia y notas en resumen final.

## Fase A4 - Analitica avanzada

- [x] T-240 Crear `AnalyticsEngine` puro y testeable.
- [x] T-241 Implementar rangos 7/30/90 dias.
- [x] T-242 Calcular volumen efectivo excluyendo warm-ups.
- [x] T-243 Calcular series efectivas por grupo muscular.
- [x] T-244 Crear distribucion de intensidad por RPE/RIR.
- [x] T-245 Calcular carga de sesion.
- [x] T-246 Calcular ACWR agudo/cronico.
- [x] T-247 Calcular indice de fatiga estimada.
- [x] T-248 Reestructurar Progreso en tabs: General, Ejercicios, Musculos, Cuerpo, Carga/Fatiga.

## Fase A5 - Motor de progresion

- [x] T-250 Crear `ProgressionEngine` puro y testeable.
- [x] T-251 Implementar progresion lineal simple.
- [x] T-252 Implementar doble progresion.
- [x] T-253 Implementar progresion por RPE/RIR objetivo.
- [x] T-254 Implementar progresion por %1RM/Training Max.
- [x] T-255 Implementar redondeo por incremento de discos.
- [x] T-256 Detectar estancamientos.
- [x] T-257 Proponer deload local o global.
- [x] T-258 Mostrar sugerencias en proxima sesion con explicacion simple.

## Fase A6 - Casa/gimnasio avanzado

- [x] T-260 Crear selector de equipamiento en onboarding/perfil.
- [x] T-261 Aplicar filtro global por equipamiento disponible.
- [x] T-262 Crear `ExerciseSubstitutionService`.
- [x] T-263 Anadir boton Sustituir en rutina y sesion activa.
- [x] T-264 Crear rutinas sugeridas por equipamiento.

## Fase A7 - Cardio, bienestar y HealthKit profundo

- [x] T-270 Crear flujo de registro cardio manual.
- [x] T-271 Crear historial y graficas cardio.
- [x] T-272 Importar entrenos de Apple Health/Watch.
- [x] T-273 Leer FC media/max y calorias cuando haya permisos.
- [x] T-274 Crear flujo de sueno/fatiga/estres/molestias.

## Fase A8 - Producto, datos y social

- [x] T-280 Exportar CSV basico.
- [x] T-281 Importar CSV disenado.
- [x] T-282 Borrar todos los datos desde ajustes.
- [x] T-283 Disenar sync iCloud/CloudKit o backend.
- [x] T-284 Generar imagen compartible de entrenamiento/PR sin datos sensibles.
- [x] T-285 Definir modelo free vs PRO y feature flags.

## Fase A9 - Perfil Pro y activos visuales

- [x] T-290 Perfeccionar Perfil como hub de valor: avatar editable, identidad y resumen corporal claro.
- [x] T-291 Eliminar duplicidad de campos peso/altura y permitir editar directamente las metricas destacadas.
- [x] T-292 Crear galeria de fotos de progreso fisico con timeline, fecha, peso y preview atractivo.
- [x] T-293 Calcular IMC, metabolismo basal, calorias de deficit, volumen y recomposicion.
- [x] T-294 Crear tarjetas de fidelizacion de gimnasios con QR/barcode y preview.
- [x] T-295 Registrar visitas a gimnasios/locales y mostrarlas en timeline.
- [x] T-296 Revisar recursos publicos de maquinas/ejercicios: `free-exercise-db` CC0 como fuente offline principal; `wger` solo con atribucion/licencia compatible; evitar datasets comerciales sin licencia.
- [x] T-297 Enlazar imagenes/instrucciones precisas de ejercicios tambien desde fichas de progreso por ejercicio.
