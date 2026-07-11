# Reps - Auditoria de alcance avanzado

Este documento traduce la especificacion avanzada a una lista accionable contra el estado actual de la app. La regla de lectura es estricta:

- `Hecho`: existe en la app y esta conectado al flujo principal.
- `Parcial`: existe una version basica, pero no cumple el detalle avanzado.
- `Pendiente`: no existe o no esta conectado de forma util.

## Estado actual resumido

La app ya tiene una base local-first con SwiftUI, SwiftData, HealthKit parcial, planes, calendario, biblioteca de ejercicios remota/offline, logging de fuerza, historial y analitica basica.

El producto avanzado todavia requiere ampliar el dominio. El principal gap no es solo UI: faltan campos de serie, cardio, bienestar, motor de progresion, carga/fatiga y separacion mas clara de servicios de dominio.

## Matriz de cobertura

| Area | Estado | Brecha principal |
| --- | --- | --- |
| Perfil de usuario | Parcial | Faltan alias/nombre, sexo, nacimiento, equipamiento disponible detallado y preferencias avanzadas. |
| Preferencias avanzadas | Pendiente | Mostrar/ocultar RPE/RIR, tipo de serie, tempo, incrementos de discos, auto-progresion. |
| Biblioteca de ejercicios | Parcial | Hay fuente abierta con imagen/instrucciones, pero faltan dificultad, entorno, tags, errores tipicos, secundarios persistidos y video con licencia clara. |
| Rutinas/programas | Parcial | Hay planes y dias, pero faltan objetivo/nivel por plan, descansos por ejercicio, prioridad, progresion, bloques/mesociclos y %1RM/TM. |
| Logging de fuerza | Parcial | Hay logging rapido peso/reps y rest timer, pero faltan RPE/RIR, tipo de serie, tempo, descanso real automatico, PR flag y notas por serie. |
| Historial | Parcial | Hay detalle de sesion, pero faltan filtros por tipo, ubicacion, etiqueta y PR visual por set. |
| Cardio | Pendiente | No hay entidad ni flujo dedicado para cardio, distancia, pace, HR, kcal y RPE. |
| Metricas corporales/bienestar | Parcial | Hay peso/talla y HealthKit, pero faltan medidas corporales, fotos, sueno, fatiga, estres y molestias. |
| Motor de progresion | Pendiente | No existen reglas lineal/doble/RPE/%1RM ni sugerencias de proxima sesion. |
| Estancamiento/deload | Pendiente | No hay deteccion de ejercicios estancados ni descarga planificada/dinamica. |
| Analitica global | Parcial | Hay volumen, PR, consistencia y musculos basicos; faltan 7/30/90, intensidad, distribucion RPE, ACWR, fatiga. |
| Insights/coaching | Parcial | Hay tarjetas simples, faltan insights al cerrar entreno y recomendaciones accionables aceptables. |
| Casa vs gimnasio | Parcial | Hay planes y filtros basicos; falta selector de equipamiento en perfil y sustitucion inteligente. |
| Social/compartir | Pendiente | No hay feed personal ni exportacion visual de PR/entreno. |
| Sync/backup/export | Pendiente | Local-first existe; falta iCloud/backend, CSV export/import y borrado completo de datos. |
| Monetizacion PRO | Pendiente | No hay modelo de entitlement ni separacion de funciones free/PRO. |
| Arquitectura dominio | Parcial | `FitnessMetrics` existe, pero faltan `ProgressionEngine`, `AnalyticsEngine`, `InsightsEngine` y repositorios testeables. |
| Localizacion | Parcial | Hay strings en EN/ES, pero aun hay mezcla de idioma por cadenas hardcodeadas y datos remotos en ingles. |

## Modelo de datos avanzado pendiente

### UserProfile

Anadir:

- `displayName`
- `email`
- `sex`
- `dateOfBirth`
- `heightCm`
- `currentWeightKg` como preferencia/perfil, separada del historial.
- `distanceUnit`
- `equipmentFlags`
- `showRPE`, `showRIR`, `showSetType`, `showTempo`
- `weightIncrementKg`
- `autoProgressionEnabled`

### Exercise

Anadir o persistir:

- `aliases`
- `exerciseType`
- `primaryMuscle`
- `secondaryMuscles`
- `loadModality`
- `environment`
- `difficulty`
- `commonMistakes`
- `videoURL`
- `requiredEquipment`
- `tags`
- `sourceID`, `sourceName`, `sourceLicense`, `sourceURL`

Nota: los datos remotos actuales vienen de `free-exercise-db` y estan en ingles. Para una experiencia internacional completa se necesita capa de traduccion/cache o curacion propia.

### WorkoutPlan / WorkoutDay / WorkoutExercise

Anadir:

- objetivo y nivel recomendado.
- descripcion.
- estructura ciclica vs dias concretos.
- descanso recomendado por ejercicio.
- prioridad: principal/secundario/accesorio.
- cues tecnicos.
- configuracion de progresion por ejercicio.
- bloques/mesociclos.
- `trainingMaxKg` o referencia a 1RM si aplica.

### WorkoutSession

Anadir:

- `userID`
- `startedAt`, `endedAt` separados de `date`.
- `origin`
- `location`
- `contextTag`
- `sessionRPE`
- `energyBefore`, `energyAfter`
- `estimatedCalories`
- metricas derivadas visibles: volumen efectivo, intensidad media, carga de sesion.

### SetLog

Anadir:

- `exerciseID` o referencia estable si el set se consulta fuera del `ExerciseLog`.
- `setType`
- `unit`
- `rpe`
- `rir`
- `tempo`
- `previousRestSeconds`
- `isPR`
- `notes`

### CardioLog

Crear entidad:

- tipo de actividad.
- fecha/hora.
- duracion.
- distancia.
- velocidad media.
- ritmo medio.
- FC media/max.
- calorias.
- RPE.
- notas.

### WellnessMetric

Extender `BodyMetric` o crear entidad separada:

- grasa corporal.
- medidas: cintura, pecho, brazo, muslo, cadera, gemelo, cuello.
- fotos.
- sueno horas/calidad.
- fatiga.
- estres.
- molestias/lesiones.

## Servicios de dominio necesarios

### ProgressionEngine

Responsabilidades:

- sugerir peso/reps de la siguiente sesion.
- soportar progresion lineal, doble progresion, RPE/RIR y %1RM/TM.
- redondear a incrementos configurados.
- explicar cada sugerencia con lenguaje simple.
- detectar fallo repetido y proponer mantener/bajar.
- exponer tests para exito, fallo, RPE alto, deload y redondeos.

### AnalyticsEngine

Responsabilidades:

- volumen total y efectivo.
- series efectivas por musculo.
- top set, 1RM estimada, PR por rep range.
- distribucion por RPE/RIR.
- carga de sesion.
- ACWR agudo/cronico.
- fatiga estimada.

### InsightsEngine

Responsabilidades:

- generar tarjetas de coaching en Home, Progreso y resumen final.
- detectar estancamiento.
- avisar de bajo/alto volumen por musculo.
- proponer deload o sustitucion cuando haya fatiga/molestia.

### ExerciseSubstitutionService

Responsabilidades:

- buscar alternativas por patron/musculo/equipamiento.
- priorizar ejercicios compatibles con equipamiento disponible.
- conservar intencion del ejercicio original.

## Flujos UX pendientes

1. Home: CTA unico y muy visible para empezar entrenamiento, con entrada clara a libre/rutina del dia.
2. Entrenamiento libre: crear sesion sin rutina y anadir ejercicios ad hoc.
3. Logging avanzado configurable: mostrar campos avanzados solo si el usuario los activa.
4. Resumen final: PRs, volumen, RPE sesion, energia, notas, insight.
5. Progreso por tabs: General, Ejercicios, Musculos, Cuerpo, Carga/Fatiga.
6. Cardio: alta rapida, historial y graficas.
7. Ajustes avanzados: RPE vs RIR, incrementos, auto-progresion, panels avanzados, idioma.
8. Equipamiento: selector en onboarding/perfil y filtro global.
9. Sustituir ejercicio: desde rutina y entrenamiento activo.
10. Exportar CSV y borrar datos.

## Roadmap avanzado recomendado

### A1 - Consolidacion UX/localizacion

- Revisar todas las pantallas con snapshot en iPhone pequeno y grande.
- Eliminar entradas duplicadas o ambiguas.
- Unificar idioma de UI.
- Asegurar padding horizontal constante.
- Definir nombres de tabs y rutas.

### A2 - Modelo de datos avanzado sin romper persistencia

- Introducir nuevos campos con defaults.
- Anadir migracion SwiftData.
- Crear `CardioLog` y `WellnessMetric`.
- Extender `SetLog` con RPE/RIR/tipo/tempo/descanso/PR/notas.

### A3 - Logging avanzado

- Toggle de campos avanzados.
- Tipo de serie.
- RPE/RIR por serie.
- Descanso real automatico.
- PR badge.
- Entrenamiento libre y anadir ejercicios durante sesion.

### A4 - Analitica avanzada

- `AnalyticsEngine`.
- 7/30/90 dias.
- volumen efectivo.
- series por musculo.
- distribucion RPE/RIR.
- ACWR y fatiga.

### A5 - Motor de progresion

- `ProgressionEngine` puro y testeado.
- progresion lineal.
- doble progresion.
- sugerencias en preview de proxima sesion.
- deteccion de estancamiento.

### A6 - Casa/gimnasio power

- selector de equipamiento.
- filtro global por equipamiento.
- sustituciones inteligentes.
- rutinas sugeridas por equipamiento.

### A7 - Cardio, bienestar y HealthKit profundo

- cardio manual.
- importacion de entrenos HealthKit.
- FC/calorias si hay permisos.
- sueno/fatiga/estres/molestias.

### A8 - Producto PRO/social/sync

- CSV export/import.
- iCloud/CloudKit o backend.
- compartir imagen de PR/entreno sin datos sensibles.
- modelo de funciones PRO.

## Criterio de calidad

Antes de marcar cualquier fase como completa:

- Debe existir UI accesible desde navegacion principal.
- Debe persistir y sobrevivir relanzamiento.
- Debe tener estado vacio.
- Debe tener al menos test unitario si incluye calculo o regla de negocio.
- Debe estar localizado o aislado para localizacion.
- Debe revisarse en simulador con captura.
