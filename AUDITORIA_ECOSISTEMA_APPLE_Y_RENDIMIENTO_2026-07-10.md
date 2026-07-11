# Auditoría de ecosistema Apple y rendimiento — Reps

Fecha: 10 de julio de 2026

## Posicionamiento del producto

Reps no debe intentar reemplazar Apple Health o Fitness. Debe utilizar ambos como capa de sensores y registro canónico, y aportar la capa que el usuario de fuerza y entrenamiento híbrido no recibe allí:

- planificación y progresión de cargas;
- series, repeticiones, RPE, RIR, tempo y descansos;
- adherencia real frente al plan;
- carga por músculo, fatiga y recuperación;
- récords personales y recomendaciones para la siguiente sesión;
- historial unificado de fuerza, cardio, rutas y recuperación;
- explicación de por qué conviene entrenar, reducir carga o descansar.

## Integración Apple implementada

### HealthKit y Fitness

- Lectura de peso, altura, grasa corporal, cintura, pasos, energía, ejercicio, hidratación, nutrición, frecuencia cardiaca, HRV, VO2 Max, sueño, workouts y rutas.
- Escritura autorizada de peso, altura, hidratación, nutrición y workouts.
- Sesión nativa con `HKWorkoutSession` y `HKLiveWorkoutBuilder` en iPhone y Apple Watch.
- Mirroring y recuperación de sesión entre Watch y iPhone.
- Workout canónico único para evitar duplicados en Apple Fitness.
- Metadata `Reps` y UUID externo para vincular de forma determinista el workout de HealthKit con la sesión local.
- Importación y enriquecimiento posteriores con ruta, distancia, pulso, cadencia, energía, pasos y recuperación cardiaca.
- Observer queries y background delivery para workouts y métricas diarias.

### Superficies del sistema

- Widgets de workout, batería y racha.
- Live Activity para entrenamiento activo.
- Apple Watch con registro básico disponible y sincronización de estado.
- Siri y Atajos:
  - iniciar el entrenamiento recomendado;
  - abrir progreso, historial y récords.
- Deep links compartidos por la app y App Intents para evitar lógica duplicada.

## Optimizaciones aplicadas

- Consultas independientes de HealthKit ejecutadas concurrentemente:
  - agregados diarios;
  - bienestar corporal;
  - sensores alrededor de un workout;
  - pulso, ruta, pasos y resumen durante importación.
- Un único `HKHealthStore` compartido entre el servicio de lectura y los observers de AppStore.
- Sincronización diaria y de workouts solapada cuando es seguro.
- Signposts `health.sync` y `health.processWorkout` para medir latencia real.
- Historial agrupado y filtrado en estado derivado; no se vuelve a ordenar ni a crear `DateFormatter` en cada evaluación de `body`.
- Splits, pulso y elevación de una ruta calculados una sola vez por evaluación de la pantalla.
- Formato numérico basado en `FormatStyle` en lugar de crear `NumberFormatter` por fila.
- Resolución de iCloud retirada del constructor y del primer frame.
- Backup iCloud operativo limitado y agrupado, sin HealthKit, fotos ni rutas.
- MetricKit ampliado para conservar métricas de producción además de diagnósticos de hangs y crashes.

## Ventaja sobre Apple Fitness

Apple Fitness sigue siendo el destino canónico del workout y de los anillos. Reps añade continuidad antes y después:

1. Antes: recomienda el workout según plan, adherencia, recuperación y carga reciente.
2. Durante: registra ejercicio, serie, carga, repeticiones, descansos, técnica, RPE/RIR y sensores del Watch.
3. Después: cruza volumen, progresión, músculo, ruta, splits, zonas, cadencia, elevación y recuperación cardiaca.
4. Siguiente sesión: convierte ese historial en una decisión accionable de carga, volumen o recuperación.

## Validación necesaria en hardware

Realizar en Release y dispositivo físico:

1. Iniciar fuerza desde Siri y confirmar apertura de la sesión correcta.
2. Iniciar desde iPhone con Watch conectado; confirmar un solo workout en Fitness.
3. Iniciar desde Watch; confirmar mirroring y un solo workout en Fitness.
4. Pausar/reanudar desde ambos dispositivos y validar continuidad.
5. Finalizar una ruta exterior y comprobar mapa, splits, pulso, cadencia, elevación y recuperación.
6. Desconectar Watch durante la sesión y confirmar fallback del iPhone.
7. Denegar permisos parciales de HealthKit y verificar degradación sin errores.
8. Capturar Instruments SwiftUI + Time Profiler + Hangs en Today, Active Workout, Historial y Progreso.
9. Comparar los signposts `health.sync` y `health.processWorkout` en tres ejecuciones estables.
10. Revisar MetricKit y Organizer después de una beta de TestFlight.

## Métricas objetivo

- cero workouts duplicados en Fitness;
- cero hangs de más de 250 ms en interacción normal;
- scroll del historial sin hitches visibles con 500 sesiones;
- sincronización de agregados sin bloquear el primer frame;
- importación de workout y ruta eventual, idempotente y sin duplicados;
- apertura desde Siri/Atajos al destino correcto en todos los estados de la app.
