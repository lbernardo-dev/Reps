# Plan de mejora integral de UI — Reps

Fecha: 2026-07-04
Referencia: capturas de la competencia (Home, Weather, Vitals, Heart Rate, Sleep, Steps, Active Workout) + `COMPETITOR_WELLNESS_TEARDOWN_PROPOSAL.md` (estrategia de producto; este documento cubre la capa visual/UI).

## 0. Diagnóstico: dónde estamos vs. la referencia

Lo que ya tenemos (no partir de cero):

- `MetricDomain` con 9 dominios, tint + secondaryTint + 3 gradientes (`backgroundGradient`, `headerGradient`, `chartAreaGradient`).
- `GlassMetricCard`, `DomainTintedBackground`, `DomainStatusPill`, `HealthStatsHeader`, `HealthInsightRow`, `HealthMiniTile`.
- Detalles de Sleep/Steps/HRV/VO2 ya montados sobre ese sistema.

Los gaps reales frente a las capturas:

| Área | Competencia | Reps hoy |
|---|---|---|
| Cards de Home | Gradiente de dominio **saturado** (rojo pleno, ámbar pleno, índigo pleno) — cada card es un bloque de color reconocible a 2 metros | `GlassMetricCard` con tint 0.07–0.14: todas las cards se ven casi iguales (gris con matiz) |
| Lenguaje de estado | Palabra humana primero: "Excellent", "Worth a look", "Healthy recovery" | Número primero, estado a veces ausente |
| Lenguaje de charts | Idéntico en toda la app: línea + puntos huecos, RuleMark blanca de media, **pill de valor a la derecha** ("54 BPM"), min/max en eje derecho, gridlines punteadas verticales | Cada vista improvisa su propio chart (barras en Sleep, línea en HRV…) sin la pill de valor ni la media |
| Profundidad de detalle | Sleep = score compuesto + fases + hipnograma + HR nocturno + respiración + semana; Steps = aro + calendario + rachas + comparativa vs periodo anterior | Sleep = barras semanales + "anoche" + 3 insights. Steps similar de plano |
| Comparación temporal | "+16.322 ↑ 62%" contra el periodo anterior en verde, en casi todas las stats | Valores absolutos casi siempre |
| Densidad de Home | Cockpit escaneable: saludo → clima → plantillas → wellness grid → hábitos → Quick Log | `TodayView` (2.195 líneas) mezcla analítica profunda con resumen |

Conclusión: **no necesitamos otro sistema, necesitamos subir la saturación, unificar el chart language y dar profundidad a los drill-downs.**

## 1. F-UI-1 · Dos niveles de card por dominio (la mejora más visible)

La competencia usa dos superficies distintas y nosotros solo una:

1. **`DomainHeroCard` (nueva)** — para el wellness grid de Home. Gradiente saturado del dominio como fondo completo (ej. rojo `#8E1F33 → #5A1522`, ámbar, índigo…), no un tinte al 10 %. Contenido: icono en chip translúcido arriba-izquierda, chevron arriba-derecha, valor grande `heroNumeric`, label, y una **mini-visualización propia del dominio** en el tercio inferior:
   - Heart rate: barras finas tipo ECG.
   - Steps: área acumulada del día con punto final.
   - Sleep: anillo de score con iconos orbitando (ya tenemos `RepsActivityRings` como base).
   - HRV / VO2: línea suave con área degradada.
   - Vitals: las "pills" Above/Typical/Below en miniatura.
2. **`GlassMetricCard` (actual)** — se queda para las vistas de detalle, donde el fondo ya está teñido por `DomainTintedBackground` y el cristal sutil es correcto.

Regla de continuidad (la clave de la sensación premium de la referencia): la `DomainHeroCard` que tocas y el header del detalle que se abre comparten exactamente el mismo gradiente → la transición se percibe como "la card se expande". Implementar con `matchedTransitionSource` / `navigationTransition(.zoom)` (iOS 18+) para que sea literal.

Nuevos tokens en `MetricDomain`:

```swift
var heroGradient: LinearGradient   // saturado, para DomainHeroCard
var glowColor: Color               // sombra exterior coloreada, radio 20–30, opacidad 0.25
var onHero: Color                  // color de texto garantizado sobre heroGradient (via PulseTheme.onColor)
```

## 2. F-UI-2 · Chart language unificado (`DomainChartStyle`)

Un solo componente `DomainLineChart` / `DomainBarChart` que encapsule el estilo de la referencia y sustituya los charts ad-hoc de HRV/VO2/Sleep/Steps/Progress:

- Línea del dominio con puntos huecos (círculo con borde, relleno de fondo).
- `RuleMark` horizontal blanca en la media, con **pill flotante de valor actual** anclada al borde derecho ("13.1 br/m", "54 BPM") — es el rasgo más reconocible de la referencia.
- Etiquetas min/max apoyadas en el eje derecho, sin eje Y completo.
- Gridlines verticales punteadas solo en 3–4 fechas ancla.
- Área bajo la línea con `chartAreaGradient` (ya existe).
- Estado seleccionado por drag: punto relleno + línea vertical + pill que sigue el dedo (esto ya lo hace la referencia en Vitals/HRV).
- Variante barras (Steps semanal): barra activa saturada, resto al 40 %, línea AVG punteada con badge "AVG".

Beneficio directo: borramos ~5 implementaciones divergentes y cualquier métrica nueva sale "de fábrica" con el look correcto.

## 3. F-UI-3 · Estado humano primero (`DomainVerdictHeader`)

Patrón de la referencia en Vitals ("Worth a look"), Sleep ("Excellent") y Weather ("Clear + consejo"):

```
[palabra de estado — .largeTitle bold]
[frase humana de 1–2 líneas explicando por qué]
```

Componente `DomainVerdictHeader(verdict:message:domain:)` que se coloca arriba del detalle, antes de cualquier número. Escala de veredictos compartida y localizada: Excellent / Good / Fair / Worth a look / Poor — cada una con su color semántico fijo (no el color del dominio: verde/azul/amarillo/naranja/rojo), de modo que el dominio da identidad y el veredicto da semántica.

Dónde aplica ya: Sleep (score), Vitals (triage), HRV (recovery), Steps (goal), Training Battery.

## 4. F-UI-4 · Drill-downs con la profundidad de la referencia

Orden por impacto:

1. **Sleep** — score 0–100 compuesto (duración 30 + consistencia 25 + restaurador 25 + eficiencia 10 + interrupciones 10) con anillo central e iconos de factor orbitando; desglose por factor con barra de progreso y etiqueta Poor/Fair/Excellent; fases con barras horizontales vs. rango óptimo (Awake 0–5 %, REM 20–25 %, Light 45–55 %, Deep 13–23 %); "This week": bedtime medio / wake medio / consistencia ±min. HealthKit ya expone `sleepAnalysis` por fases — es sobre todo trabajo de UI + un `SleepScoreEngine` pequeño.
2. **Steps** — aro de progreso grande con % (>100 % sigue creciendo el badge, como el "154 %"); rachas (actual / mejor / días de objetivo); calendario mensual con días cumplidos; comparativa del periodo: Total / Best / Average con delta verde "+3.264 ↑ 62 %" vs. periodo anterior.
3. **Heart Rate** — vista propia (hoy vive dentro de HRV/Vitals): rango del día con barras intradía, card "Post-Workout Recovery" (caída de HR en 3 min tras el último entreno — dato que ya tenemos con workout HR), cards de Workout HR y Sleep HR, resting 30 días. Muy alineado con Reps por ser métrica de entrenamiento.
4. **Vitals (triage)** — pantalla de estado con las pills Above/Typical/Below por vital y grid resumen con flechas direccionales. Es la puerta de entrada "¿me preocupo o no?" que hoy no existe.

Todos usan la misma plantilla: `DomainTintedBackground` + `DomainVerdictHeader` + `HealthStatsHeader` + `DomainLineChart` + secciones + `HealthInsightRow`s. La plantilla ya existe a medias — formalizarla como `MetricDetailScaffold`.

### Lo que NO copiar de la referencia (errores visibles en sus propias capturas)

- Min de resting HR = 0 bpm graficado → filtrar outliers antes de pintar.
- "Efficiency 100 %" con 9 interrupciones y veredicto "Excellent" con Restorative "Poor" → nuestros veredictos deben ser consistentes entre sí o pierden credibilidad.
- Copy fantasioso ("your body got the deep rest it needs" con 4 % de sueño profundo) → el copy debe derivarse de los factores reales.

## 5. F-UI-5 · Comparativa temporal como patrón transversal

Componente `TrendDelta(value:previous:)` → "+3.264 ↑ 62 %" en verde / rojo / gris neutro. Aplicarlo en: stats de Steps, volumen semanal de Today, Progress summary cards, VO2/HRV promedios. Es barato y es de las cosas que más "app seria de datos" transmite.

## 6. F-UI-6 · Home: escaneable, no analítico

Sin rehacer la arquitectura (eso es la Iniciativa A del teardown), tres cambios visuales:

1. Wellness grid 2 columnas con las nuevas `DomainHeroCard` (hoy el bloque wellness usa tiles planos).
2. Analítica profunda (matriz de actividad, mini-trends, competitive summary) sale de Today → vive en Progress; Today queda: saludo/fecha → hero de entrenamiento → wellness grid → hábitos → shortcuts.
3. `TodayView` (2.195 líneas) se trocea en componentes por sección — requisito para poder iterar el diseño sin miedo.

## 7. F-UI-7 · Micro-interacciones y fluidez

(Implementación con la skill `swiftui-microinteractions`, según regla del proyecto.)

- Transición zoom card→detalle (`navigationTransition(.zoom)`).
- `contentTransition(.numericText())` en todos los valores grandes al cambiar de periodo.
- Anillos y barras animan al aparecer con spring escalonado (patrón ya presente en `RepsActivityRings` — extenderlo a los charts).
- Pill de valor del chart con haptic `selection` al cruzar puntos durante el drag.
- Veredicto del header aparece con `.blurReplace`.

## 8. Orden de ejecución propuesto

| Fase | Entregable | Toca |
|---|---|---|
| 1 | Tokens nuevos (`heroGradient`, `glowColor`, `onHero`) + `DomainHeroCard` + `DomainVerdictHeader` + `TrendDelta` | `PulseTheme.swift` + 3 archivos nuevos |
| 2 | `DomainLineChart`/`DomainBarChart` y migración de HRV, VO2, Sleep, Steps | `DesignSystem/Charts/` |
| 3 | Home wellness grid con hero cards + transición zoom | `TodayView` (troceo incluido) |
| 4 | Sleep 2.0 (score + fases + semana) | `SleepView`, `SleepScoreEngine` |
| 5 | Steps 2.0 (aro + calendario + rachas + deltas) | `StepsView` |
| 6 | Heart Rate detail + Vitals triage | nuevos en `Features/Today` |
| 7 | Barrido de micro-interacciones | transversal |

Cada fase compila y se puede lanzar sola; 1–3 son las que cambian la percepción de toda la app de golpe (todas las cards y todos los charts).

## 9. Criterios de aceptación visual

- Desde Home puedes decir qué dominio es cada card **sin leer texto** (solo por color/forma).
- Card y detalle comparten gradiente e icono; la navegación se siente como expansión, no como cambio de pantalla.
- Todos los charts de la app comparten: pill de valor derecha, media blanca, puntos huecos, gridlines punteadas.
- Toda métrica con estado muestra la palabra antes que el número.
- Toda stat agregada de periodo muestra delta vs. periodo anterior.
- Ningún veredicto contradice sus factores (mejor que la referencia, no igual).
