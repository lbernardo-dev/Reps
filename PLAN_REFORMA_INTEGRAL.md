# StreakRep — Plan de Reforma Integral (Producto + Diseño + Código)

Fecha: 2026-07-03
Ámbito: iOS app, watchOS app, Widgets/Live Activities, App Store
Sustituye y absorbe: `UI_AUDIT_RESOLUTION_PLAN.md` (polish táctico ya aplicado)

---

## 1. Diagnóstico ejecutivo

### 1.1 Lo que la app YA tiene (y no hay que reinventar)

La auditoría de código revela que el problema **no es falta de funcionalidad**, es falta de
coherencia y ejecución. Inventario real:

| Capa | Activos existentes |
|---|---|
| Datos | `Models.swift`: SetLog con RPE, supersets (`supersetGroup`), CardioLog con rutas GPS, BodyMetric, DailyHealthMetric, GymPass/Visitas, ProgressPhoto, media attachments |
| Métricas | `FitnessMetrics.swift`: 1RM estimado, volumen efectivo, sessionLoad, averageRPE, intensityDistribution, muscleVolumePoints, **trainingBattery** (proto-readiness), workloadSummary, stalledExercises, insightCards |
| Servicios | HealthKit, notificaciones inteligentes, iCloud backup + Pro entitlement, CSV, share cards, música (Apple Music), telemetría, haptics, App Shortcuts, gamificación + achievements, SmartProgressionAdvisor |
| Superficies | Watch app completa, 5 widgets (Streak, Battery, Workout, Friends, Live Activity), Social hub con retos, Paywall RevenueCat |

### 1.2 Los problemas raíz (por qué "no acaba de estar bien")

1. **Monolitos de vista que impiden diseño consistente.**
   - `ProgressView.swift`: **4.430 líneas**. `ActiveWorkoutView.swift`: **4.022**. `TodayView.swift`: **2.761**. `WatchWorkoutView.swift`: 1.400.
   - Cada monolito redefine sus propias cards, tiles y charts → la inconsistencia visual
     que percibes es consecuencia directa de la estructura del código.

2. **Duplicación masiva Hoy ↔ Resumen.** `TodayView` define `SummaryMetricTile`,
   `SummaryChip`, `ActivityMatrixCard`, `MiniTrendCard`, `MiniAreaChart`, `MiniBarChart`,
   `HomeMetricTile`, `WellnessWidget`… y `ProgressView` tiene su propia sección
   "New Summary Components" con anillos y drill-downs. Dos pantallas compiten por ser
   "el resumen" → el usuario no sabe a dónde mirar.

3. **Sin hilo conductor de producto.** Las 4 tabs (Resumen / Calendario / Entrenar /
   Social) no cuentan una historia. No existe un loop claro:
   *¿Qué hago hoy? → Entreno → ¿Qué conseguí? → ¿Qué toca mañana?*

4. **Progreso plano.** Los datos existen (RPE, tonelaje, 1RM, zonas HR) pero se
   presentan como listas de tiles con `—` y ceros. La competencia presenta lo mismo como:
   ficha por-ejercicio con récords, donut de volumen, tendencias multi-año, filtros por
   variante.

5. **Watch y widgets sin identidad.** El watch tiene el modelo (1.536 líneas) pero la UI
   no sigue el patrón de la competencia (set actual gigante + Complete Set + rating RPE +
   rest timer con +30s). Los widgets muestran datos pero sin jerarquía ni el lenguaje
   visual del sistema.

6. **Design system a medias.** `PulseTheme` existe pero convive con estilos ad-hoc por
   pantalla. No hay librería de charts compartida ni tokens de espaciado/tipografía
   forzados.

---

## 2. Auditoría de mercado (referencias adjuntas)

Patrones ganadores extraídos de las capturas de competencia (estética dark + acento lima,
tipo Hevy / SmartGym / Train) y de Apple Fitness:

| # | Patrón | Qué lo hace bueno | Estado en StreakRep |
|---|---|---|---|
| M1 | **Ficha por-ejercicio histórica** (max weight, tonelaje, avg RPE con etiqueta "heavy", reps, sets, frecuencia/semana, filtros por variante, rango de fechas) | Convierte el log en conocimiento; retención a largo plazo | Datos ✅, vista ❌ (ExerciseProgressView básica) |
| M2 | **Donut "Volume by exercise"** con selector Week/Month/Year/All y total central | Una imagen = distribución del esfuerzo | ❌ |
| M3 | **Calculadora 1RM multi-fórmula** (Epley, Brzycki, Lander, Average, RPE-based) + tabs Weighted / Bodyweight+load + **generador de calentamiento** por objetivo (Max strength 5×1–3 @90%…) + "Copy to workout" | Herramienta diaria, no decorativa; explica el cálculo | Solo Epley interna; `OneRepMaxCalculatorView` mínima |
| M4 | **Constructor híbrido por bloques** (Strength / Circuit / Tabata / EMOM / AMRAP + Superset) en un mismo workout | Cubre gym + metcon + cardio en un flujo | Supersets ✅; bloques metcon ❌ |
| M5 | **Suite de timers** standalone (Stopwatch, Timer, Tabata, EMOM, AMRAP, Boxing, Metronome, Yoga) | Utilidad instantánea, punto de entrada diario | ❌ |
| M6 | **Readiness index 0–100 con 6–7 factores** (Recovery, ACWR, Sleep, Monotony, Load trend, Frequency) + recomendación del día ("75–85% del máximo, 5–10 reps, RPE 7–8") | Da propósito a los datos de salud; el usuario vuelve cada mañana | `trainingBattery` ✅ como base; falta descomposición por factores y prescripción |
| M7 | **PRs en vídeo** — grabar intentos, galería por ejercicio, récords por rango de reps (50kg×10, 90kg×1…) | Emocional + viral | Media attachments ✅; galería/records por reps ❌ |
| M8 | **Educación "?" contextual** — sheets con la ciencia (hidratación ml/kg, sueño y 1RM, zonas de readiness, cómo se calcula ACWR) | Confianza y diferenciación; justifica el paywall | ❌ |
| M9 | **Watch de sesión completa** — "55 kg × 10" gigante, Complete set, rating RPE 0–10 con color, rest 1:45 con Skip/+30s, superset badge (A2 · 1/3) | El gym se vive desde la muñeca | Modelo ✅, UI a rehacer |
| M10 | **Apple Fitness system-feel** — anillos, Training Load (7 vs 28 días), Trends, Awards, Sharing con amigos | Familiaridad instantánea | Parcial y duplicado |

**Conclusión de mercado:** la referencia no gana por tener *más* pantallas, gana porque
cada pantalla tiene **un job claro** y todos los números llevan a una acción
(Copy to workout, Start, recomendación del día).

---

## 3. El hilo conductor propuesto

> **"Cada dato te dice qué hacer hoy y te enseña por qué."**

Loop de producto:

```
 MAÑANA            GYM                 POST                 SEMANA
 Readiness   →   Entrenar con    →   Resumen + PRs   →   Progreso/Tendencias
 + plan del día  prescripción         + share card        + ajuste del plan
      ▲                                                        │
      └────────────────── el plan se recalibra ◄───────────────┘
```

### 3.1 Nueva arquitectura de información (5 tabs)

| Tab | Job to be done | Contenido único (sin duplicar) |
|---|---|---|
| **Hoy** | "¿Qué hago hoy y cómo estoy?" | Readiness index + factores, workout del día con CTA único, streak, 2–3 señales (sueño, HR reposo, pasos). *Nada de analytics profundos.* |
| **Entrenar** | "Empiezo algo ya" | Quick start, planes/rutinas, constructor por bloques, **Timers metcon**, librería de workouts |
| **Progreso** | "¿Estoy mejorando?" | Anillos/carga estilo Fitness, tendencias, donut de volumen, mapa muscular, récords, historial. Drill-down por métrica |
| **Ejercicios** | "Todo sobre un movimiento" | Librería + **ficha por-ejercicio** (M1): récords por rango de reps, vídeos PR, gráficos, 1RM, calentamiento sugerido |
| **Perfil** | "Yo y mi entorno" | Cuerpo/fotos, logros, social/retos, gimnasio (pases/visitas), ajustes, paywall |

Reglas duras:
- Un componente de métrica vive en **una sola tab**; las demás enlazan.
- Calendario deja de ser tab → se integra como vista dentro de Entrenar (programación) y Progreso (historial).
- Social deja de ser tab → sección en Perfil + share cards post-entreno (donde aporta).
- Quick Log accessory se mantiene, pero con 3 acciones máximo.

---

## 4. Reforma del Design System (prerequisito de todo)

**Objetivo:** que ninguna feature vuelva a dibujar su propia card.

1. **Tokens** en `PulseTheme`: espaciados (4/8/12/16/24), radios (12/16/20), tipografía
   (LargeTitle rounded bold → caption mono para números), elevaciones, y paleta
   consolidada (fondo #0D0F14 aprox, superficie, acento lima, semánticos por métrica:
   HR rojo, volumen lima, sueño índigo, readiness verde→rojo).
2. **Librería de charts compartida** (`DesignSystem/Charts/`) sobre Swift Charts:
   `MetricDonutChart`, `TrendLineChart` (con rango y anotación de PR),
   `WeeklyBarsChart`, `HeatmapCalendar`, `ZoneStackedBar`, `ReadinessGauge`,
   `SparklineTile`. Todas con estados: vacío (CTA), cargando, con datos.
3. **Componentes canon**: `MetricCard`, `SectionHeader` (título + "?" educativo + chevron),
   `RecordRow` (estrella + kg + reps + fecha), `FilterChips` (Week/Month/Year/All),
   `HeroNumber` (número gigante + unidad pequeña, como "100 kg" de la referencia).
4. **Micro-interacciones**: obligatorio usar la skill `swiftui-microinteractions`
   (regla ya establecida en memoria) — springs al completar set, haptic en PR,
   count-up de números, transición matched en drill-downs.
5. **Regla de oro tipográfica de la competencia**: número enorme + label pequeña gris.
   Nunca label grande + número pequeño.

---

## 5. Plan por fases

> Orden pensado para que cada fase deje la app **mejor y shippable**, no un big-bang.

### FASE 0 — Cimientos (refactor estructural) · sin cambio visual
- Trocear monolitos en componentes por carpeta:
  - `ProgressView.swift` (4.430) → `Progress/Components/*` + subvistas por sección.
  - `ActiveWorkoutView.swift` (4.022) → ya hay `ActiveWorkout*Components.swift`; completar la extracción (set row, block header, rest overlay, summary).
  - `TodayView.swift` (2.761) → extraer todos los tiles a `DesignSystem` o borrarlos si duplican Progreso.
- Crear `DesignSystem/Charts/` y tokens (§4.1–4.3).
- **Criterio de salida:** ningún fichero de vista > 800 líneas; build verde; snapshot idéntico.

### FASE 1 — Nueva IA de navegación
- RootView: 5 tabs de §3.1; migrar Calendario y Social a sus nuevos hogares.
- Hoy reescrito: Readiness hero + workout del día + streak + 3 señales. Eliminar de Hoy
  todo lo que duplica Progreso.
- Quick Log reducido a: Entrenar ya / Registrar cardio / Registrar peso.
- **Criterio de salida:** cero componentes de métrica duplicados entre tabs (grep de tiles).

### FASE 2 — Progreso "wow" (la mayor deuda visual)
- Pantalla Progreso estilo Apple Fitness: anillos + Training Load (7 vs 28 días,
  reutiliza `workloadSummary`/ACWR ya implementado) + Trends con flechas.
- **Donut de volumen por ejercicio/músculo** (M2) con Week/Month/Year/All.
- Mapa muscular como heatmap de volumen semanal (paquete MuscleMap ya integrado).
- Drill-down por métrica (`ProgressMetricDetailView` ya iniciado — completarlo con la
  librería de charts común).
- Historial de workouts como "receipt" cards ricas (ya existe `WorkoutReceiptView` — unificar).
- **Criterio de salida:** demo de 90s solo en la tab Progreso sin tocar otra tab.

### FASE 3 — Ficha por-ejercicio + herramientas de fuerza
- **Exercise Detail 2.0** (M1): hero stats (max weight, tonelaje con mini-bars, avg RPE
  etiquetado, reps, sets, x/semana), filtros por variante, rango temporal, récords por
  rango de reps (M7 parcial), galería de vídeos PR, gráfico de progresión con PRs anotados.
- **1RM Calculator 2.0** (M3): Epley/Brzycki/Lander/Average/RPE, modo Bodyweight+load
  (streetlifting), explicación "cómo se calcula", **generador de calentamiento** por
  objetivo (Max strength/Strength/Volume/Endurance) y "Copiar al workout".
- Plate calculator ya existe → enlazarlo desde el set activo.
- **Criterio de salida:** paridad visual con las capturas M1/M3 de referencia.

### FASE 4 — Entrenamiento híbrido + timers
- Constructor por **bloques** (M4): Strength / Circuit / Tabata / EMOM / AMRAP en un
  mismo workout ("HYBRID · Mixed block types"). Modelo: nuevo `WorkoutBlock` sobre
  `WorkoutDay` (los supersets existentes se convierten en un tipo de bloque).
- Runner de bloques en ActiveWorkout: pantalla EMOM/AMRAP tipo referencia (countdown
  gigante ámbar, MIN 3/5, next exercise).
- **Tab de Timers** standalone (M5): Stopwatch, Timer, Tabata, EMOM, AMRAP,
  Boxing/MMA, Metronome, Yoga — cada uno con Live Activity.
- **Criterio de salida:** un workout mixto fuerza+EMOM completo de principio a fin con
  Live Activity correcta.

### FASE 5 — Readiness + educación (retención)
- Evolucionar `trainingBattery` → **Readiness Index** (M6) con 6 factores visibles:
  Recovery, ACWR (ya está), Sleep quality, Monotony, Load trend, Frequency & timing.
  Gauges circulares por factor + "Today's goal" con prescripción concreta
  (%1RM, reps, RPE, descanso) conectada al SmartProgressionAdvisor existente.
- **Sistema educativo "?"** (M8): `EducationSheet` reutilizable + catálogo de ~15 temas
  (readiness zones, ACWR, sueño, hidratación, RPE, 1RM, sobrecarga progresiva…).
  Contenido localizado ES/EN. Parte del contenido como gancho Pro.
- **Criterio de salida:** cada número "opinable" de la app tiene su "?".

### FASE 6 — Watch + Widgets + PR video
- **Watch 2.0** (M9): rehacer `WatchWorkoutView` con el patrón referencia — peso×reps
  gigante, Complete set, rating RPE con color, rest countdown con Skip/+30s, badge de
  superset/bloque, métricas HR en página 2. El modelo actual (1.536 líneas) se conserva.
- **Widgets 2.0**: rediseño de los 5 widgets con los tokens nuevos; añadir widget de
  Readiness (gauge) y de "próximo entreno"; Lock Screen widgets.
- **PR en vídeo completo** (M7): captura desde el set activo, galería en Exercise Detail,
  comparación lado a lado (v2 si hay tiempo).
- **Criterio de salida:** sesión completa gym solo con watch; widgets pasan revisión visual.

### FASE 7 — Pulido de conversión y lanzamiento
- Onboarding cuestionario de alta conversión (usar skill `app-onboarding-questionnaire`):
  objetivo → experiencia → equipamiento → días/semana → readiness inicial → paywall.
- Paywall alineado a los nuevos ganchos Pro (readiness factores, educación, PR video, análisis avanzado).
- Screenshots App Store con pipeline `asc-shots-pipeline` replicando el estilo de las
  capturas de referencia (claim grande + mockup).
- QA integral: pass de localización ES/EN, clean-install onboarding (pendiente del audit
  anterior), accesibilidad (Dynamic Type, VoiceOver en charts), rendimiento en scroll.

---

## 6. Prioridades si hay que elegir (impacto/esfuerzo)

1. **F0 + F1** — sin esto, todo lo demás vuelve a salir inconsistente.
2. **F2 + F3** — es exactamente lo que hoy "está feo y no se entiende"; máximo impacto percibido.
3. **F5** — readiness es el diferenciador de retención diaria.
4. **F4** — abre el mercado metcon/CrossFit (nadie más mezcla bien fuerza+metcon).
5. **F6 → F7** — pulido de superficie y lanzamiento.

## 7. Métricas de éxito

- Estructura: 0 vistas > 800 líneas; 0 componentes de métrica duplicados.
- Producto: tiempo hasta primer set < 30s desde cold start; cada tab responde a un job en ≤ 1 frase.
- Diseño: 100% de charts desde `DesignSystem/Charts`; revisión lado a lado contra capturas de referencia por fase.
- Negocio: onboarding → trial conversion medible vía telemetría existente; retención D7 como métrica norte tras F5.

## 8. Riesgos

- **Migración de datos**: `WorkoutBlock` (F4) requiere migración SwiftData cuidadosa — hacer additive-only.
- **Alcance social**: no invertir más en Social hasta F7; hoy no es el problema.
- **Big-bang temptation**: cada fase debe mergearse con build verde y app usable; nada de branch de 3 meses.
