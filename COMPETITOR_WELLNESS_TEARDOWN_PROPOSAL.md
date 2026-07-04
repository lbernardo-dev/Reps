# Propuesta de mejora para Reps a partir del análisis competitivo

Fecha: 2026-07-03  
Referencia: capturas de app competidora aportadas por el usuario

## 1. Resumen ejecutivo

La app de la competencia no gana por una sola feature. Gana por convertir datos dispersos
de entrenamiento, salud, sueño, pasos, clima, peso y nutrición en un dashboard oscuro,
visual y accionable. Cada pantalla sigue casi siempre el mismo patrón:

1. número principal grande;
2. estado entendible en lenguaje humano;
3. gráfico de tendencia;
4. insights o flags;
5. una recomendación concreta.

Reps ya tiene gran parte de los datos y servicios necesarios: HealthKit, pasos, sueño,
HRV, VO2 Max, peso, Training Battery, historial, progreso, widgets, watch, métricas de
carga, PRs y entrenamientos. La oportunidad principal es de producto y UX:

- menos pantallas que compiten por ser "resumen";
- más drill-downs consistentes por métrica;
- más consejos accionables;
- entrenamiento activo más denso y rápido;
- una capa visual más premium y uniforme.

La dirección recomendada es posicionar Reps como:

> El centro diario para saber si conviene entrenar, qué entrenar y cómo está progresando
> tu cuerpo.

## 2. Lo que hace bien la competencia

### 2.1 Home como cockpit diario

Observaciones:

- saludo personal y fecha como entrada emocional;
- tarjeta meteorológica con gráfico horario y CTA a detalle;
- plantillas de entrenamiento visibles arriba;
- bloque Wellness con tarjetas de ritmo cardiaco, vitals, pasos, sueño, VO2 Max y HRV;
- Quick Log persistente y tab bar con iconos grandes;
- diseño oscuro, tarjetas con color por dominio y números muy grandes.

Lección para Reps:

- Hoy debe responder en 10 segundos: "cómo estoy", "qué toca entrenar", "qué dato merece
  atención" y "qué puedo registrar rápido".
- No debe mostrar analítica profunda. Para eso está Progreso.

### 2.2 Weather orientado a entrenamiento

Observaciones:

- no es una pantalla de clima genérica;
- traduce clima en decisión deportiva: "great conditions for outdoor workout";
- muestra temperatura, viento, UV, lluvia, amanecer/atardecer;
- propone "best times" para entrenar fuera;
- los gráficos detallados explican temperatura, lluvia, viento y UV.

Lección para Reps:

- Si añadimos clima, debe ser una tarjeta contextual para cardio exterior o días de running,
  no una sección permanente para todos.
- Valor diferencial: "mejor hora para salir", "evita calor/UV", "ajusta hidratación".

### 2.3 Vitals y salud como señales, no como tablas

Observaciones:

- vitals empieza con estado global: "Worth a look";
- usa pills en un gráfico con rangos Above/Typical/Below;
- resume métricas clave: HR, HRV, respiración y oxígeno;
- cada métrica tiene pantalla de detalle con promedio, mínimo, máximo, tendencia e insights;
- las tarjetas de insights explican qué puede estar pasando.

Lección para Reps:

- Reps no necesita copiar el volumen de métricas médicas, pero sí el patrón:
  estado + tendencia + interpretación + acción.
- Hay que evitar alarmismo médico. Usar lenguaje de bienestar: "fuera de tu rango habitual",
  "podría afectar recuperación", "observa tendencia".

### 2.4 Sueño como score descompuesto

Observaciones:

- score 72/100 con factores: interrupciones, eficiencia, consistencia, sueño restaurador,
  duración;
- resumen con hora de dormir, despertar, duración, eficiencia;
- fases de sueño con rango óptimo;
- frecuencia cardiaca y respiratoria durante sueño;
- insights semanales y flags.

Lección para Reps:

- Sleep no debe ser solo una tarjeta. Debe alimentar el Training Battery / Readiness.
- La pantalla de sueño debería explicar qué factor limita la recuperación y cómo impacta
  el entrenamiento del día.

### 2.5 Pasos, peso y nutrición como hábitos

Observaciones:

- pasos tiene aro de progreso, streak, calendario, estadísticas semanales e insights;
- peso tiene historia, actividad de pesaje, BMI, métricas corporales;
- calorías combina eaten/burned/goal y explica el presupuesto restante;
- hidratación aparece como hábito en Home.

Lección para Reps:

- Estas métricas son secundarias para una app de fuerza, pero útiles para retención diaria.
- Deben vivir en Hoy/Profile/Progreso como hábitos y señales de contexto, no desplazar el
  flujo de entrenamiento.

### 2.6 GymHub como dashboard de entrenamiento

Observaciones:

- total workouts mensual con matriz de días;
- ejercicio destacado;
- PR Wall;
- Muscle Activity;
- Quick Start;
- frecuencia e intensidad;
- medidas corporales y librería de ejercicios;
- historial mensual de entrenamientos con rutas y chips de distancia, duración, ritmo, kcal.

Lección para Reps:

- La tab Entrenar de Reps debería sentirse como un hub, no solo como lista de planes.
- PRs, ejercicio destacado, actividad muscular y quick start son muy buenos accesos
  recurrentes.

### 2.7 Workout activo

Observaciones:

- pantalla de rutina tipo modal grande;
- cabecera con nombre, ejercicios y sets;
- cada ejercicio tiene imagen, tipo de tracking, timer, menú y tabla KG/REPS/TIMER;
- acciones por ejercicio: Add Set y Stats;
- botones sticky: Exercise, Start, Save.

Lección para Reps:

- El registro debe priorizar densidad y velocidad: editar KG/REPS/rest sin navegar.
- La estadística del ejercicio debe estar a un tap durante el entrenamiento.
- La imagen del ejercicio ayuda a confianza y escaneo rápido.

### 2.8 Historial mensual y resumen comparativo

Observaciones:

- la vista mensual combina una curva acumulada, barras de sesiones y comparación contra
  el mes anterior;
- debajo hay tiles de Training Load, Duration, Distance, Elevation Gain, Energy y Sessions;
- el tile seleccionado se tiñe con azul, borde azul y fondo azul translúcido;
- el historial reciente usa filas densas con icono, fecha, chips de duración/ritmo/kcal y
  miniatura de ruta cuando aplica;
- la lista no intenta mostrar todos los detalles, solo suficientes señales para reconocer
  cada sesión y entrar al detalle.

Lección para Reps:

- Progreso debe tener una vista de periodo que compare contra el periodo anterior, no solo
  valores absolutos.
- El historial de entrenamientos puede ser mucho más útil si cada row muestra chips
  contextuales: fuerza (sets, volumen, PR), cardio (distancia, ritmo, kcal, ruta), movilidad
  (duración, consistencia).
- El estado seleccionado debe cambiar la coloración del panel, no solo un texto o un borde.

### 2.9 Weight, calorías y medidas corporales

Observaciones:

- Weight History usa un dominio morado: fondo superior tintado, icono morado y cards
  negras con acento violeta;
- el gráfico principal aparece incluso con pocos datos, pero la competencia lo compensa con
  stats de actividad de pesaje y BMI;
- BMI muestra barra de categorías multicolor, etiqueta de estado y explicación de limitación
  ("no mide grasa o músculo");
- Body metrics resume resting kcal, body fat estimada, ideal weight y altura;
- calorías usa un dominio naranja/rojo con card grande, desglose daily goal - eaten + burned
  y una frase que explica la regla del presupuesto.

Lección para Reps:

- Peso y composición corporal deben ser un subproducto serio de Profile/Wellness, no una
  card aislada.
- Cada cálculo opinable necesita explicación visible. BMI debe mostrarse con cautela y con
  contexto de fuerza/músculo para no generar conclusiones pobres.
- Calorías puede entrar como contexto de objetivo, pero Reps no debería convertirse en un
  contador nutricional completo salvo que se decida competir en nutrición.

### 2.10 Sistema visual por dominio

Observaciones:

- cada funcionalidad tiene una familia cromática constante:
  - HRV/recuperación: verde;
  - VO2 Max/cardio fitness: cian;
  - peso/body metrics: violeta;
  - pasos/actividad diaria: ámbar;
  - calorías: naranja/rojo;
  - sueño: índigo/morado;
  - GymHub/fuerza: gris oscuro con acentos blancos, azules o verdes según submétrica;
- la tarjeta resumen y la vista detalle repiten el mismo tinte, icono y gradiente;
- el fondo superior del detalle se tiñe con el color del dominio, como una extensión de la
  tarjeta que abrió el usuario;
- los gráficos heredan el color del dominio: línea, puntos, etiquetas y pills;
- las cards usan una base tipo cristal oscuro: superficie translúcida, borde sutil,
  degradado interno y glow muy controlado.

Lección para Reps:

- Reps necesita un "Domain Theme System", no solo colores sueltos.
- Cada feature debe declarar su dominio visual una vez y reutilizarlo en Home, detalle,
  charts, icons, chips, widgets y share cards.
- Esta continuidad da sensación premium y reduce carga cognitiva: el usuario sabe que verde
  es recuperación, cian es cardio, rojo es heart rate, ámbar es actividad, violeta es cuerpo.

## 3. Qué no conviene copiar literalmente

- Demasiadas tarjetas de salud pueden diluir la promesa de Reps si compiten con entrenar.
- La competencia muestra algunos datos dudosos, por ejemplo mínimos de HR de 0 bpm. Reps
  debe filtrar outliers y explicar cuando un dato es insuficiente.
- El exceso de blur y overlays puede perjudicar legibilidad y accesibilidad.
- El color por métrica funciona, pero hay riesgo de interfaz demasiado ruidosa si no se
  define una jerarquía estricta.
- No conviene convertir Reps en una app médica. El lenguaje debe ser de fitness y hábitos.
- El cristal tintado debe usarse como sistema, no como efecto aplicado a todo. Si todas las
  cards brillan igual, ninguna jerarquía destaca.
- Los gradientes deben reforzar dominio y profundidad; no deben sustituir buen layout,
  contraste y lectura.
- BMI y calorías son sensibles: mostrarlos sin contexto puede chocar con usuarios de fuerza,
  recomposición corporal o historial de relación complicada con el peso.

## 4. Propuesta de producto para Reps

### Iniciativa A - Hoy 2.0: readiness + plan + señales

Objetivo:
Que Hoy sea el punto de decisión diaria.

Contenido propuesto:

- Hero "Readiness / Training Battery" de 0 a 100.
- Estado humano: "Listo para entrenar", "Carga moderada", "Recupera hoy".
- CTA principal único: "Empezar Lower A", "Entreno libre" o "Crear plan".
- Señales compactas: sueño, HRV, pasos/actividad, fatiga/carga.
- Si el entrenamiento es outdoor: tarjeta de condiciones y mejor hora.
- Una sección "Worth a look" con máximo 2 flags accionables.

No incluir:

- gráficos profundos de tendencia;
- tablas extensas;
- secciones repetidas de Progreso.

### Iniciativa B - Drill-down estándar por métrica

Objetivo:
Todas las métricas importantes deben tener el mismo patrón visual y narrativo.

Plantilla:

1. header con métrica enorme;
2. estado o etiqueta;
3. comparación contra periodo anterior;
4. tres stats clave;
5. gráfico principal;
6. insights;
7. "Cómo mejorar" o "Qué significa";
8. enlace a datos/fuente.

Aplicar a:

- HRV;
- VO2 Max;
- pasos;
- sueño;
- peso;
- frecuencia cardiaca;
- carga de entrenamiento;
- volumen;
- ejercicio concreto.

Beneficio:

- reduce componentes duplicados;
- mejora aprendizaje del usuario;
- facilita monetización Pro con insights avanzados.

### Iniciativa C - Entrenar/GymHub 2.0

Objetivo:
Convertir Entrenar en un hub operativo.

Contenido propuesto:

- Total workouts del mes con calendario/matriz.
- Próximo entrenamiento / rutina activa.
- Quick Start prominente.
- PR Wall.
- Ejercicio destacado.
- Muscle Activity con Recovery y Volume.
- Frecuencia e intensidad con filtros 7D/30D/90D.
- Librería de ejercicios y body measurements como accesos.

Decisión de arquitectura:

- Planes y rutinas siguen existiendo, pero el primer viewport debe ser un dashboard de
  acción, no una lista administrativa.

### Iniciativa D - Active Workout 2.0

Objetivo:
Bajar la fricción de registrar en el gimnasio.

Cambios propuestos:

- Cabecera compacta con ejercicio actual, progreso de sets y duración.
- Cards de ejercicio con imagen, último PR/última carga y tabla editable.
- Columnas configurables: kg, reps, RPE, timer, completado.
- Acción "Stats" por ejercicio con historial rápido y recomendación de progresión.
- Rest timer integrado por set, con Skip y +30s.
- Sticky controls: Exercise, Start/Pause, Save/Finish.
- Haptics y animación al completar set.
- Filtrado de campos avanzados para que el modo básico sea limpio.

### Iniciativa E - Wellness como capa de contexto

Objetivo:
Usar salud diaria para mejorar decisiones de entrenamiento.

Métricas:

- sueño;
- HRV;
- frecuencia cardiaca en reposo;
- pasos;
- peso;
- hidratación;
- calorías activas;
- VO2 Max.

Regla de producto:

Cada métrica debe responder una pregunta deportiva:

- Sueño: "¿recuperé suficiente?"
- HRV: "¿estoy adaptando o acumulando estrés?"
- Pasos: "¿mi actividad base acompaña mi objetivo?"
- Peso: "¿mi tendencia encaja con fuerza/definición?"
- VO2 Max: "¿mi cardio mejora?"

### Iniciativa F - Insights & Flags compartidos

Objetivo:
Que la app explique los números.

Formato:

- icono semántico;
- título corto;
- frase de diagnóstico;
- acción recomendada;
- opcional: botón "Aprender".

Ejemplos:

- "HRV subiendo: buena señal de recuperación. Mantén la carga planificada."
- "Sueño irregular: evita buscar PRs hoy; trabaja a RPE 7."
- "VO2 Max mejora: añade una sesión zona 2 para consolidar."
- "Pasos bajos esta semana: programa 20 min de caminata post-entreno."

### Iniciativa G - Domain Theme System

Objetivo:
Crear un lenguaje visual donde cada dominio de producto tenga identidad propia y consistente
entre resumen, detalle, gráfico, widgets y acciones.

Dominios propuestos:

| Dominio | Color base | Uso principal |
|---|---|---|
| Fuerza / GymHub | Lima + grafito | entrenamientos, volumen, PRs, biblioteca |
| Recuperación / HRV | Verde | readiness, HRV, recuperación, adaptación |
| Cardio / VO2 Max | Cian | VO2 Max, cardio fitness, rutas, zona 2 |
| Heart rate | Rojo/coral | HR actual, reposo, workout HR, post-workout HR |
| Sueño | Índigo/violeta | score, fases, sueño restaurador |
| Pasos / actividad | Ámbar | pasos, streak diario, actividad base |
| Peso / body metrics | Violeta | peso, medidas, composición corporal |
| Nutrición / calorías | Naranja | calorías, balance energético, hidratación |
| Clima outdoor | Azul | weather, UV, lluvia, viento, mejores horas |

Componentes técnicos:

- `MetricDomain` enum con color, icono, gradiente, glow, chart style y copy tone.
- `DomainTintedBackground` para la cabecera de detalle.
- `GlassMetricCard` para tarjetas resumen con cristal tintado.
- `DomainChartStyle` para que líneas, puntos, áreas, barras, labels y pills sean coherentes.
- `DomainStatusPill` para estados como Excellent, Fair, Normal, Above, Below, Goal met.

Reglas visuales:

- La card de Home y su detalle deben compartir el mismo dominio.
- El detalle debe comenzar con un fondo superior tintado, no con una card aislada.
- El color de dominio se usa para icono, gráfico primario, etiqueta de tendencia y glow.
- El texto principal sigue siendo blanco; el color nunca debe cargar todo el contenido.
- Máximo un dominio dominante por pantalla. Las listas pueden tener iconos de color, pero no
  fondos multicolor simultáneos.

### Iniciativa H - Period Summary 2.0

Objetivo:
Dar a Progreso una vista mensual/semanal comparable y escaneable.

Contenido propuesto:

- gráfico acumulado de entrenamiento actual vs periodo anterior;
- barras o marcadores de sesiones por día;
- tiles seleccionables: Training Load, Duration, Distance, Elevation, Energy, Sessions,
  Volume, PRs;
- al seleccionar un tile, cambia el color del gráfico y el tinte del tile;
- Recent Workouts con filas densas y chips contextuales;
- filtros: Week, Month, 90D, Year.

Aplicación en Reps:

- Fuerza: volumen, sets, PRs, RPE medio.
- Cardio: distancia, ritmo, elevación, kcal, ruta.
- Híbrido/GymHub: duración, carga, bloques completados.

### Iniciativa I - Body & Weight Detail 2.0

Objetivo:
Convertir peso y medidas en una vista útil para usuarios de fuerza, no solo dieta.

Contenido propuesto:

- hero de peso actual y cambio 7/30/90 días;
- gráfico de tendencia con media móvil;
- weigh-in activity: entradas, frecuencia semanal, streak y spread;
- BMI con explicación y baja prominencia;
- body metrics: cintura, pecho, cadera, brazo, resting kcal, estimación de grasa si existe;
- objetivo configurable: mantener, ganar músculo, perder grasa, recomposición;
- insights no moralizantes: "peso estable con volumen subiendo", "tendencia de peso y fuerza
  avanzan en direcciones coherentes", "pocos pesajes para detectar tendencia".

Regla:
El peso no debe ocupar el mismo lenguaje de alerta que una métrica de seguridad. Debe
tratarse como tendencia contextual.

## 5. Backlog priorizado

### P0 - Diseño y arquitectura

- Consolidar tokens de diseño: fondo, superficie, borde, acentos por métrica, radios,
  tipografía numérica y estados.
- Crear componentes compartidos: `MetricHero`, `InsightList`, `MetricTrendCard`,
  `MetricDetailScaffold`, `WorkoutExerciseLogCard`, `StatusPill`.
- Asegurar estados empty/loading/locked para todos los charts.
- Crear `MetricDomain`, `GlassMetricCard`, `DomainTintedBackground`,
  `DomainChartStyle` y `DomainStatusPill`.
- Definir una tabla de dominios visuales con color, gradiente, icono, glow y tono de copy.

### P1 - Hoy y Entrenar

- Rehacer Hoy con readiness, CTA de entrenamiento y 2-3 señales.
- Rehacer Entrenar como GymHub: quick start, rutina activa, PR Wall, muscle activity,
  monthly activity.
- Reducir Quick Log a tres acciones reales: entreno libre, cardio/pasos, peso/hábito.
- Aplicar continuidad visual: la card de cada métrica abre un detalle con la misma
  coloración, gradiente e icono.

### P2 - Métricas de salud accionables

- HRV detail.
- VO2 Max detail.
- Sleep detail.
- Steps detail.
- Weight detail.
- Insights por métrica.
- Body & Weight Detail 2.0 con lenguaje específico para fuerza y recomposición.

### P3 - Workout activo

- Rediseñar cards de ejercicio.
- Añadir historial/stats rápido por ejercicio.
- Rest timer por set con controles grandes.
- Mejorar sticky bottom actions.
- Validar con una sesión real de 4 ejercicios y 20 sets.

### P4 - Period Summary e historial

- Crear vista de periodo estilo mensual/semanal con comparación contra periodo anterior.
- Añadir Recent Workouts con rows contextuales por tipo de sesión.
- Incorporar mini rutas para cardio outdoor cuando haya GPS.
- Añadir filtros Week/Month/90D/Year.

### P5 - Weather contextual

- Añadir WeatherKit solo como módulo opcional para entrenamientos outdoor.
- Mostrar mejor hora, calor/UV/viento y recomendación de hidratación.
- No mostrar clima en el centro de Hoy si el usuario solo entrena fuerza indoor.

### P6 - Pro / monetización

- Insights avanzados.
- Comparativas 30/90 días.
- PR Wall avanzado.
- Muscle Activity detallado.
- Watch/widgets rediseñados con los mismos tokens.

## 6. Roadmap recomendado

### Sprint 1 - Fundaciones visuales

- Crear scaffolds y componentes compartidos de métricas.
- Normalizar charts y tarjetas.
- Definir estados empty/locked.
- Implementar el sistema de dominios visuales y cristal tintado.

Resultado:
La app empieza a verse coherente sin cambiar toda la navegación.

### Sprint 2 - Hoy 2.0

- Hero readiness.
- CTA principal de entrenamiento.
- Señales de sueño/HRV/pasos/carga.
- Flags accionables.

Resultado:
La primera pantalla compite directamente con la referencia, pero enfocada en entrenar.

### Sprint 3 - Entrenar/GymHub 2.0

- Dashboard mensual.
- Quick Start.
- PR Wall.
- Muscle Activity.
- Rutinas y librería como accesos claros.

Resultado:
Entrenar deja de ser administrativo y se vuelve recurrente.

### Sprint 4 - Drill-downs de salud

- HRV, VO2, sueño, pasos y peso con la plantilla estándar.
- Insights y "cómo mejorar".
- Continuidad cromática completa entre card, detalle, chart y status pills.

Resultado:
Reps absorbe lo mejor del cockpit de salud sin perder foco.

### Sprint 5 - Period Summary + historial

- Comparativa semanal/mensual contra periodo anterior.
- Tiles seleccionables de Training Load, Duration, Distance, Energy, Sessions, Volume y PRs.
- Recent Workouts con chips contextuales y mini rutas.

Resultado:
Progreso gana una capa ejecutiva clara y comparable.

### Sprint 6 - Active Workout 2.0

- Registro denso por ejercicio.
- Stats por ejercicio.
- Timer y acciones sticky.

Resultado:
La parte más crítica de Reps, entrenar, se siente más rápida que la competencia.

## 7. Criterios de éxito

- En Hoy, el usuario entiende en menos de 10 segundos si debe entrenar fuerte, normal o
  suave.
- Iniciar un entrenamiento requiere un tap desde Hoy o Entrenar.
- Registrar un set no exige navegación ni abrir sheets.
- Cada métrica importante tiene explicación y acción.
- No hay métricas vacías ocupando espacio principal.
- Las pantallas de detalle comparten patrón visual.
- La tarjeta resumen y el detalle de una métrica comparten dominio visual: color, gradiente,
  icono, chart y status pills.
- Una pantalla no mezcla más de un dominio visual dominante.
- Los detalles de peso/BMI evitan lenguaje moralizante y explican limitaciones.
- El lenguaje evita promesas médicas y se centra en rendimiento, hábitos y recuperación.

## 8. Recomendación final

La competencia ya está jugando a "fitness operating system". Reps puede competir mejor si
no intenta ser una copia amplia, sino una app de entrenamiento que usa salud diaria para
decidir mejor. Las nuevas capturas refuerzan una segunda idea: la experiencia premium nace
de un sistema visual coherente por dominio, donde color, cristal, gradiente, icono y gráfico
se mantienen desde la card de resumen hasta la pantalla de detalle.

Prioridad real:

1. Domain Theme System con cristal tintado y continuidad card-detalle.
2. Hoy 2.0 con readiness accionable.
3. Entrenar/GymHub 2.0.
4. Period Summary 2.0 e historial contextual.
5. Active Workout 2.0.
6. Drill-downs de HRV, VO2, sueño, pasos y peso.
7. Weather contextual para outdoor.

La ventaja de Reps es que muchos datos ya existen. El trabajo importante es ordenar,
explicar, dar identidad visual a cada dominio y convertir cada número en una acción.
