# StreakRep — plan estratégico, técnico y de crecimiento

Fecha: 10 de julio de 2026  
Alcance: app iOS, Apple Watch, widgets/Live Activities, tests, producto, mercado, monetización, adquisición y retención.  
Estado de la evidencia: auditoría estática del repositorio, builds locales, ejecución del gate de localización, revisión visual de capturas existentes e investigación pública del mercado. No se dispone todavía de cohortes reales, entrevistas propias, tickets de soporte ni datos de App Store Analytics.

## 1. Veredicto ejecutivo

StreakRep no tiene un problema de falta de funcionalidades. Tiene cuatro problemas de enfoque y ejecución:

1. El valor central está enterrado bajo demasiadas superficies: fuerza, cardio, recuperación, tiempo, hidratación, social, gimnasio, rehabilitación, música, logros, rutas y métricas de salud compiten por atención.
2. La promesa más valiosa —«dime qué entrenar, regístralo rápido y ayúdame a progresar sin excederme»— no forma todavía un bucle impecable. El onboarding genera un plan que Free no activa, el paywall aparece antes del primer valor y el siguiente entrenamiento no se adapta de forma suficientemente visible y explicable al resultado anterior.
3. Hay bloqueos objetivos de release y confianza: tests que no compilan, enlaces legales inconsistentes, gate de localización fallido, requisitos de moderación social ausentes y una copia completa de datos de salud/bienestar enviada a iCloud que debe revisarse frente a las reglas de HealthKit/App Review.
4. La monetización está infravalorada y mal presentada. El precio actual está varias veces por debajo de competidores directos, pero el producto aún no demuestra el valor Pro de forma contextual antes de pedir la compra.

La recomendación no es añadir más amplitud. Es convertir StreakRep en el mejor coach de fuerza nativo del ecosistema Apple para usuarios que quieren una decisión clara cada día, registro rápido, progresión explicable y recuperación responsable.

### Posicionamiento recomendado

> **StreakRep convierte tu plan, tu historial y tus señales de Apple Health en el entrenamiento que te conviene hoy — y te explica por qué.**

Promesa corta para adquisición:

> **Sabe qué entrenar. Registra en segundos. Progresa sin pasarte.**

Usuario primario:

- Persona con iPhone y, preferentemente, Apple Watch.
- Principiante serio o intermedio que entrena fuerza 2–5 días por semana.
- Quiere estructura y progresión, pero no desea programar en hojas de cálculo ni interpretar dashboards complejos.
- Entrena en gimnasio, casa o ambos y necesita sustituciones por equipamiento disponible.

Usuario secundario, no prioritario durante los próximos seis meses:

- Lifter avanzado que crea mesociclos y usa RPE/RIR, tempo y deload.
- Usuario híbrido de fuerza y cardio que quiere un historial Apple unificado.

No intentar servir primero a rehabilitación clínica, wellness general, red social fitness, nutrición completa y programación profesional al mismo tiempo.

## 2. Qué es hoy el producto

### Target `Reps` — aplicación iOS/iPadOS

Propósito: planificar y ejecutar entrenamiento de fuerza, cardio y recuperación; conectar historial, Apple Health, métricas corporales y progreso; monetizar analítica, progresión, backups, Watch y compartir.

Capacidades existentes relevantes:

- Onboarding personalizado por objetivo, experiencia, frecuencia, duración, entorno, equipamiento y foco muscular.
- Planes propios, programas preparados, entrenamiento libre, agenda y calendario.
- Registro de series, peso, repeticiones, RPE/RIR, tempo, descansos, notas y sustituciones.
- Progresión lineal, doble progresión, RPE/RIR, porcentaje de 1RM, estancamientos y deload.
- Progreso, 1RM estimado, PR, volumen, carga, fatiga, músculos, cardio, cuerpo e historial.
- HealthKit, rutas, pasos, sueño, HRV, frecuencia cardiaca, VO2 Max, energía e hidratación.
- Música, fotos, notas de voz, pases de gimnasio, rehabilitación, objetivos, logros, rachas y social.
- RevenueCat, Firebase Analytics/Crashlytics, CloudKit social e iCloud Documents.

Fortaleza: cobertura excepcional para una versión 1.0.  
Riesgo: `AppStore` supera las 5.000 líneas, concentra estado y coordinación de casi todos los dominios en `@MainActor`, y cada nueva función aumenta el coste de cambio y regresión.

### Target `RepsWatch Watch App`

Propósito: ejecutar entrenamientos desde la muñeca, registrar fuerza, rutas e intervalos, capturar HealthKit y sincronizar con iPhone.

Fortalezas:

- No es un simple visor: contiene modelo de workout, ejecución, métricas, comandos y sincronización.
- Puede ser el diferencial más defendible de StreakRep.

Brechas:

- Casi 3.000 líneas entre modelo y vista sin target de tests propio.
- El acceso completo está tratado como Pro antes de demostrar valor.
- Las capturas actuales muestran problemas de adaptación de texto en pantalla pequeña (`reps` parte la palabra en dos líneas).
- Debe probarse pérdida de conectividad, ejecución independiente, recuperación tras cierre, duplicados en HealthKit y sincronización bidireccional.

### Target `RepsWidgets`

Propósito: mantener el plan, batería, racha, amigos y entrenamiento activo visibles fuera de la app.

Incluye:

- Widget de próximo workout.
- Widget de batería/readiness.
- Widget de racha.
- Widget social/amigos.
- Live Activity de workout.

Fortaleza: muy buen encaje con el posicionamiento Apple-first.  
Brecha: no hay pruebas específicas de timelines, snapshots, familias, contenido vacío, privacidad en pantalla bloqueada ni actualización tras cambios de estado.

### Target `RepsTests`

Propósito: tests de dominio y persistencia con Swift Testing.

Estado confirmado:

- Existen 84 tests en un único archivo de unas 2.400 líneas.
- La suite actual no compila por constructores de métricas de ruta que ahora exigen parámetros de pedómetro y puntos de ruta.
- No existen targets separados de UI tests, Watch tests ni widget tests.

### Esquemas y configuración

- El esquema `Reps` construye app, Watch y widgets correctamente en Debug de simulador.
- El esquema `RepsWatch Watch App (Notification)` lanza `Reps.app`, no la app Watch; debe corregirse o eliminarse para evitar diagnósticos falsos.
- `project.yml` declara iOS 26 y watchOS 26 para los targets finales, aunque las opciones globales mencionan watchOS 10. La fuente de verdad es inconsistente.
- iPhone y iPad están incluidos (`TARGETED_DEVICE_FAMILY = 1,2`), por lo que iPad requiere QA, layout y activos de App Store propios o debe retirarse de la primera versión.

## 3. Diagnóstico técnico confirmado

### P0 — antes de enviar a App Review

#### 3.1 La suite de tests no compila

Evidencia:

- `RouteMetricsBuilder.Input` requiere métricas de pedómetro.
- `ActiveWorkoutStatusBuilder.Input` requiere rutas y estado anterior.
- Los tests alrededor de `RepsTests.swift:1712–1825` no pasan esos campos.

Acción:

- Actualizar fixtures con valores explícitos, no defaults silenciosos.
- Añadir casos outdoor, cinta, Watch, pausa/reanudación y fallback sin GPS.
- Separar el archivo único en suites de dominio: planes, progresión, rutas, persistencia, monetización, widgets compartidos y social.

Criterio de salida: `xcodebuild test` verde dos veces consecutivas desde checkout limpio.

#### 3.2 Social no cumple todavía el mínimo funcional de UGC

Evidencia:

- Hay posts, fotos, comentarios, likes, seguidores, perfiles y retos.
- No se encontró implementación de filtrado previo, reporte de contenido, bloqueo de usuarios ni cola operativa de moderación.

Apple exige las cuatro capacidades para apps con contenido generado por usuarios: filtrado, reporte con respuesta, bloqueo y contacto publicado ([App Review Guideline 1.2](https://developer.apple.com/app-store/review/guidelines/)).

Acción recomendada para v1:

- Opción A, más segura: compilar Social detrás de un feature flag remoto y mantenerlo desactivado en la primera release.
- Opción B: implementar reporte de post/comentario/perfil, bloqueo, ocultación inmediata, términos comunitarios, contacto, retención de evidencias y SLA de moderación.
- El age gate que está en desarrollo es necesario, pero no sustituye la moderación.

Criterio de salida: checklist completo de Guideline 1.2 y walkthrough reproducible para App Review.

#### 3.3 Backup de salud en iCloud requiere rediseño/comprobación legal

Evidencia:

- `AppSnapshot` incluye sesiones, cardio, métricas corporales, salud, fotos, rehabilitación y rutas.
- `ICloudBackupService` codifica el snapshot completo como `reps-backup.json` en iCloud Documents.
- Apple indica que las apps no pueden almacenar información personal de salud en iCloud dentro de sus reglas de HealthKit ([Guideline 5.1.3](https://developer.apple.com/app-store/review/guidelines/)).

Acción:

- Detener el backup automático completo hasta resolver el alcance permitido.
- Separar configuración/planes de datos de salud sensibles.
- Mantener HealthKit como fuente de verdad para señales de salud cuando sea posible.
- Ofrecer exportación local cifrada y explícita, iniciada por el usuario.
- Revisar con asesoría legal qué datos de fitness propios pueden sincronizarse y cuáles no.
- Actualizar privacidad, nutrición de datos y copy Pro; no vender «backup automático» hasta cerrar esta cuestión.

#### 3.4 Enlaces legales y marca inconsistentes

Evidencia:

- Perfil y Ajustes usan `https://repsapp.com/...` con comentario TODO.
- Metadatos usan `https://romerodev.com/streakrep/...`.
- Código muestra `StreakRep`, App Store/capturas muestran `StreakRep Fit` y documentos previos alternan `Reps`, `StreakReps` y `StreakRep`.

Acción:

- Elegir una marca canónica: recomendación `StreakRep`.
- Centralizar URL, email, nombre legal y bundle-facing copy en una sola configuración.
- Verificar política, soporte, términos y términos de suscripción con HTTP 200 desde todos los territorios.

#### 3.5 Localización no pasa su propio gate

Evidencia obtenida con `Scripts/verify-localization.mjs`:

- 4.332 entradas stale ignoradas.
- Claves nuevas sin `en` o `es`.
- Decenas de `localizedString` ausentes del catálogo.
- Literales visibles en español en Today, Plans, Settings, Workout y Progress.
- El script escanea además dependencias dentro de carpetas derived, generando ruido.

Acción:

- Hacer que el verificador excluya `.derived*`, SourcePackages y tests de terceros.
- Corregir primero claves visibles y nuevas.
- Reducir catálogo stale en lotes y bloquear nuevas regresiones en CI.
- Añadir snapshots EN/ES de onboarding, workout, summary, paywall, Today, Progress, Watch y widgets.

#### 3.6 Privacidad y consentimiento

Evidencia:

- Firebase Analytics y Crashlytics se activan en el arranque.
- El manifest propio declara interacción de producto y crash data, pero la nutrición final de App Store no está verificable desde el repositorio.
- La app maneja salud, fitness, localización, contacto, identificadores sociales, fotos, voz, contenido y compras.

Acción:

- Inventario de datos campo por campo: origen, destino, finalidad, retención, vinculación y borrado.
- Verificar manifests agregados de Firebase, RevenueCat y demás SDK.
- Crear un Privacy Center real: analítica, Crashlytics, HealthKit, ubicación, social, exportación y borrado.
- No enviar señales de salud a Firebase. Mantener la sanitización y revisar breadcrumbs/custom values.
- Alinear manifest, etiquetas de privacidad, política y tráfico observado.

### P1 — estabilidad, rendimiento y mantenibilidad

#### 3.7 Dividir `AppStore` por dominios, de forma incremental

No reescribirlo entero. Extraer owners estables:

- `WorkoutSessionStore`: drafts, timer, set completion y recuperación.
- `TrainingPlanStore`: planes, activación, agenda y recomendación.
- `HealthReadinessStore`: HealthKit, caché y battery.
- `ProgressStore`: render models, rangos e insights.
- `EntitlementStore`: RevenueCat y gates.
- `SocialStore`: CloudKit, feed, retos y moderación.

`AppStore` debe quedar como composición/navegación, no como base de datos, motor de dominio, sync hub y coordinador de UI al mismo tiempo.

#### 3.8 Sacar persistencia pesada del intervalo de MainActor

Estado positivo ya implementado:

- Debounce de 500 ms.
- Persistencia por scopes.
- Signposts.
- Render models de Progreso, Calendario y Today.
- Índice de búsqueda del catálogo.

Pendiente:

- `SwiftDataPersistence` y su `ModelContext` siguen en `@MainActor`.
- Los scopes reemplazan colecciones completas, aunque ya no todo el snapshot.
- `commitPendingSave` construye snapshots y sincroniza widgets/Watch desde el owner global.
- `activeWorkoutDrafts` persiste y notifica desde el store global en la ruta más sensible.

Acción:

- Medir primero con los signposts existentes.
- Usar actor/model actor de persistencia y aplicar deltas por ID.
- Mantener en MainActor solo la captura compacta de estado y el commit visual.
- Introducir `ActiveWorkoutSessionModel` local con checkpoints en hitos, no en cada edición.

#### 3.9 Compatibilidad de sistema

iOS/watchOS 26 reduce soporte, alcance y posibilidad de migración desde competidores. No es necesariamente incorrecto, pero es una decisión de negocio, no solo técnica.

Acción:

- Medir distribución de OS del mercado objetivo con App Store Connect cuando existan instalaciones.
- Estimar un spike para iOS 18/19+ usando fallback de tabs y APIs con availability.
- Si el coste es razonable, ampliar compatibilidad antes de invertir en paid acquisition.
- Alinear watchOS global/target y documentar la matriz iPhone–Watch soportada.

### P2 — calidad visual

Hallazgos en capturas actuales:

- Today da prioridad visual al tiempo antes que al entrenamiento.
- La barra «Registro rápido» tapa contenido y compite con la tab bar.
- Encabezados truncados (`CREA Y AJUSTA TU...`).
- Watch rompe unidades/palabras en columnas estrechas.
- Progreso muestra densidad alta antes de responder «qué hago ahora».
- Capturas ASO incluyen el texto interno «Datos premium reales. Sin pantallas vacías», que no comunica beneficio al cliente.
- Las primeras capturas venden weather/readiness antes que el acto principal de empezar y registrar un entrenamiento.

Acción:

- Un CTA principal por pantalla.
- Priorizar «Entrena hoy» sobre weather en Today.
- Hacer progresivo el disclosure de wellness.
- Revisar Dynamic Type, VoiceOver, contraste y tamaños compactos Watch.
- Rehacer el orden ASO: decisión de hoy → registro → progreso → Watch → recuperación.

## 4. Mercado y competencia

### 4.1 Atractivo del mercado

- Health & Fitness alcanzó máximos de descargas e ingresos IAP en 2024 y EE. UU. concentró más de la mitad del gasto global de la categoría ([Sensor Tower](https://sensortower.com/blog/state-of-mobile-health-and-fitness-in-2025)).
- Las estimaciones externas sitúan el mercado global de fitness apps alrededor de USD 12,1–12,3 mil millones en 2025 y cerca de USD 13,9 mil millones en 2026, aunque las definiciones varían ([Grand View Research](https://www.grandviewresearch.com/industry-analysis/fitness-app-market), [Fortune Business Insights](https://www.fortunebusinessinsights.com/fitness-app-market-116380)).
- Es un mercado atractivo y muy competido. La distribución, la confianza y el hábito importan más que el número bruto de funciones.
- Health & Fitness lidera la conversión download-to-paid D35 en RevenueCat 2026: mediana 2,9% y cuartil superior por encima de 6,2%. Freemium tiene mediana 2,1% frente a 10,7% en hard paywall, pero el hard paywall tiene mucha más varianza y sacrifica alcance ([RevenueCat 2026](https://www.revenuecat.com/state-of-subscription-apps-2026-shopping/)).
- El 82,1% de los trials de Health & Fitness empieza en D0 y el rango 5–9 días es el más común en la categoría. Esto hace crítico el onboarding y el momento del primer paywall.

### 4.2 Mapa competitivo

Precios públicos de EE. UU.; pueden variar por región y promoción.

| Producto | Compra principal | Fortaleza | Debilidad/reclamo | Precio público aproximado |
|---|---|---|---|---|
| Hevy | Tracker social + nuevo entrenador | Logging, comunidad, UX, Watch, Live Activities, 4,9/79K en App Store | Bugs recientes, batería, cierre post-workout, límites Free | USD 2,99/mes, 23,99/año, 74,99 lifetime ([oficial](https://www.hevyapp.com/features/workout-plan-generator/)) |
| Strong | Utilidad pura | Simplicidad, historial, Apple Watch, confianza de años, 4,9/108K | Programación manual, base de ejercicios rígida, menor innovación percibida | USD 4,99/mes, 29,99/año ([App Store](https://apps.apple.com/us/app/strong-workout-tracker-gym-log/id464254577)) |
| Fitbod | Coach adaptativo | Generación automática, 1.000+ ejercicios con vídeos, integrations | Precio alto, recomendaciones poco confiables, bugs/sync | USD 15,99/mes, 95,99/año ([oficial](https://app.prod.fitbod.me/)) |
| Alpha Progression | Hipertrofia/progresión | Prescripciones, RIR, deload, gimnasios/equipamiento | Más técnico, menos social/ecosistema | USD 12,99/mes, 79,99/año ([oficial](https://alphaprogression.com/en/subscribe)) |
| Boostcamp | Programas de expertos | 11.000+ programas free, coaches, RPE/RIR, comunidad | Editor/logging menos flexible, crashes, Watch todavía en evolución | USD 14,99/mes o 59,99/año ([oficial](https://www.boostcamp.app/pro)) |
| SmartGym | Apple-first + trainer | 730+ animaciones, 130+ workouts, Watch premiado, iPhone/iPad/Mac | Fiddly, precio superior, complejidad | USD 9,99/mes, 59,99/año ([App Store](https://apps.apple.com/us/app/smartgym-gym-home-workouts/id922744883)) |
| StreakRep actual | Todo-en-uno Apple-first | Fuerza + recuperación + Health + Watch + widgets + progresión | Foco diluido, sin media guiada comparable, release risks, valor Pro no demostrado | USD/EUR 0,99 semana, 1,99 mes, 8,99 año, EUR 19,99 lifetime según configuración local |

Amenaza principal: Hevy ya ha incorporado entrenador personalizado y progresión sin subir precio.  
Referente Apple: SmartGym tiene una historia de producto y una biblioteca visual mucho más madura.  
Hueco real: progresión de fuerza **explicable** que use recuperación de Apple Health sin convertir el entrenamiento en una caja negra ni en un dashboard de wellness.

### 4.3 Voz de cliente pública

Esta evidencia proviene de usuarios de competidores, no de clientes propios. Debe orientar hipótesis, no sustituir entrevistas.

#### Tema A — «Quiero registrar sin que la app me moleste»

Confianza: alta. Aparece de forma recurrente en reseñas de Strong/Hevy y comparativas comunitarias.

Implicación:

- Tiempo desde abrir rutina hasta primer set < 20 segundos.
- Tap de completar set inmediato, undo visible, timer no modal.
- Offline y batería son parte del producto, no detalles técnicos.

#### Tema B — «Dime qué hacer, pero necesito confiar en la lógica»

Confianza: alta. Fitbod recibe quejas recurrentes sobre workouts incoherentes, equipamiento ignorado, pesos/reps extraños y progresión que parece aleatoria ([ejemplo 1](https://www.reddit.com/r/fitbod/comments/1ucuvx8/feedback_for_devs_pls_fix_this/), [ejemplo 2](https://www.reddit.com/r/fitbod/comments/1qje0v9/i_hope_fitbod_will_explain_recent_app_behavior/)).

Implicación:

- Cada cambio debe incluir «por qué», datos usados y opción de mantener/sustituir.
- El algoritmo debe ser determinista y testeable; la IA explica y conversa, no inventa prescripciones.
- Mostrar confianza/calidad de datos: «basado en 4 sesiones», «sin HRV suficiente», etc.

#### Tema C — sustituciones instantáneas por equipo, dolor o gimnasio lleno

Confianza: alta. Se repite en Fitbod, Boostcamp y Hevy.

Implicación:

- Botón de sustituir en workout, con alternativas equivalentes por patrón, músculo, equipo y dificultad.
- Recordar la sustitución solo hoy o para todo el plan.
- Aprender preferencias sin romper la progresión del ejercicio principal.

#### Tema D — Watch y Health deben ser fiables

Confianza: alta. Hevy y Fitbod muestran que duplicados, desconexiones, batería y finalización rota erosionan rápidamente la confianza ([Hevy](https://www.reddit.com/r/Hevy/comments/1s7rtnn/blank_screen_after_workout_complete/), [Fitbod](https://www.reddit.com/r/fitbod/comments/1sufjlm/devs_hear_us_fix_this/)).

Implicación:

- Métrica principal del target Watch: porcentaje de workouts iniciados que terminan sincronizados exactamente una vez.
- El resumen debe aparecer aunque la conectividad falle.
- Estado claro: local, pendiente de sync, sincronizado, conflicto.

#### Tema E — fatiga de suscripciones y miedo a perder el historial

Confianza: media-alta. Aparece en reseñas, comunidades y nuevas alternativas local-first.

Implicación:

- Exportación y portabilidad como señal de confianza.
- No borrar datos al bajar de Pro.
- Evitar semanal como plan visualmente dominante.
- Explicar por qué existe la suscripción: mejora continua, Watch, algoritmos, contenido y soporte.

#### Tema F — programas de calidad reducen la ansiedad de empezar

Confianza: alta. Es el motor de Boostcamp y parte del avance de Hevy Trainer.

Implicación:

- No competir por volumen de programas todavía.
- Lanzar 8–12 programas excelentes, firmados/revisados por profesionales, con progresión y población objetivo claras.
- Permitir importar/migrar desde Strong, Hevy y CSV para reducir switching cost.

## 5. Estrategia de producto

### 5.1 Bucle central

```text
Objetivo + equipo
      ↓
Plan activo gratis
      ↓
“Hoy toca esto”
      ↓
Registro rápido y fiable
      ↓
Resumen: qué lograste
      ↓
Siguiente ajuste explicado
      ↓
Vuelta en la próxima sesión
```

Todo lo que no mejore una de estas transiciones es secundario durante los próximos seis meses.

### 5.2 Aha moment y north star

Aha moment operativo:

> Completar un primer workout real con al menos tres series y recibir una recomendación comprensible para la siguiente sesión.

North star:

> Usuarios que completan al menos dos workouts válidos por semana durante cuatro semanas consecutivas.

Métricas auxiliares:

- Tiempo a primer set.
- Primer workout D0/D1.
- Workouts completados por usuario activo semanal.
- Porcentaje de recomendaciones aceptadas, editadas o descartadas.
- D1, D7 y D30.
- Tasa de recuperación después de una semana fallida.
- Workouts Watch sincronizados exactamente una vez.

## 6. Roadmap priorizado

### Fase 0 — Release Confidence (0–2 semanas)

Objetivo: que el producto sea enviable y medible.

1. Reparar tests y separar suites.
2. Decidir Social off en v1 o completar moderación.
3. Pausar/rediseñar backup iCloud de datos de salud.
4. Unificar marca, URLs y email legal.
5. Corregir el gate de localización y claves visibles.
6. Auditar PrivacyInfo, nutrition labels y SDK manifests.
7. Completar IAP review metadata, capturas, contacto y notas de revisión; revalidar ASC porque los documentos locales están desactualizados.
8. Probar Release en dispositivo real: HealthKit, location background, Music, Watch, widgets, Live Activity, compra/restauración.
9. Decidir soporte iPad; si sigue, hacer QA y screenshots 13".
10. Corregir/eliminar el esquema Watch Notification engañoso.

Criterios de salida:

- Builds Debug y Release verdes.
- Tests verdes.
- Cero enlaces placeholder.
- Gate de localización verde.
- Checklist App Review y UGC resuelto.
- Compra, restore y downgrade probados con sandbox.

### Fase 1 — Activation First (semanas 2–6)

Objetivo: reducir tiempo a valor y no cobrar antes de demostrarlo.

1. Activar automáticamente el primer plan generado para Free.
2. Eliminar paywall como CTA principal del onboarding.
3. Terminar onboarding en Today con una única acción: «Empezar primer entrenamiento».
4. Posponer HealthKit, notificaciones, ubicación, música y social hasta que la función los necesite.
5. Crear modo «primera semana»: plan, próximo workout, progreso simple; ocultar weather y dashboards secundarios.
6. Primer set guiado dentro de la sesión, no tour pasivo.
7. Resumen del primer workout: logro, siguiente sesión y preview Pro contextual.
8. Instrumentar pasos de onboarding, plan generado/activado, primer workout, primer set, finalización y abandono.

Experimentos:

- A: onboarding actual vs onboarding hasta primer set.
- B: paywall al final del onboarding vs después del primer summary.
- C: HealthKit en onboarding vs tras primer workout.

### Fase 2 — Core Loop Quality (semanas 6–12)

Objetivo: ser tan fiable y rápido como los mejores trackers.

1. `ActiveWorkoutSessionModel` local y resiliente.
2. Checkpoints de workout, crash recovery y sync idempotente Watch/HealthKit.
3. Timer pasivo, feedback de set, undo y siguiente acción.
4. Sustitución «solo hoy» / «todo el plan».
5. Objetivos autocalculados desde sesiones, PR, peso, pasos e hidratación.
6. Resumen narrativo: PR/volumen → consistencia → siguiente ajuste.
7. 100 ejercicios core con media propia/licenciada de calidad antes de ampliar catálogo; cubrir ejecución, errores y variantes.
8. Importadores de Strong/Hevy/CSV con mapeo y preview antes de aplicar.
9. Tests de rendimiento con dataset de 1, 6, 24 y 60 meses.

### Fase 3 — Differentiation (meses 3–6)

Objetivo: construir una razón clara para cambiar desde Hevy/Strong/Fitbod.

1. Coach explicable:
   - recomendación de carga/reps;
   - evidencia usada;
   - confianza de datos;
   - aceptar, editar o mantener;
   - efecto esperado.
2. Readiness accionable, no decorativo:
   - entrenar normal;
   - bajar volumen;
   - sustituir por técnica/movilidad;
   - descansar;
   - explicar señales y límites.
3. Apple Watch básico gratuito para demostrar el ecosistema; Pro para progresión avanzada, readiness, rutas detalladas, insights y personalización.
4. Weekly Review: tres cambios, un riesgo y una acción para la semana siguiente.
5. 8–12 programas editoriales excelentes, versionados y revisados por profesionales.
6. Coach conversacional on-device opcional usando lógica de dominio verificada. Nunca dejar que el modelo genere cargas sin pasar por reglas deterministas.

### Fase 4 — Monetization & Growth (meses 4–9)

Objetivo: convertir después de valor y adquirir de forma repetible.

1. Paywall contextual por fuente:
   - preview real del dato bloqueado;
   - beneficio específico;
   - progreso ya conseguido;
   - CTA y continuidad Free.
2. Trial iniciado después del primer workout o al intentar el primer ajuste Pro, no al abrir la app.
3. Pricing research y test por cohortes.
4. Rehacer ASO y screenshots alrededor del loop principal.
5. Pedir review después de un PR o tercer workout satisfactorio, nunca después de un fallo/sync.
6. Programa de referidos: compartir programa/resultado con deep link, no spam social.
7. Contenido de adquisición:
   - progresión explicable;
   - cómo usar RPE/RIR;
   - entrenar con poca recuperación;
   - guías Apple Watch para fuerza;
   - migración desde hojas de cálculo/Strong/Hevy.
8. Partnerships pequeñas con entrenadores certificados para programas y credibilidad.

### Fase 5 — Scale & Moat (meses 9–18)

Solo después de retención y conversión demostradas:

- iPad/Mac como planificador de bloques y análisis, no simple estirado de iPhone.
- Portal de coach y planes compartidos.
- Marketplace curado con revenue share.
- Integraciones Strava/Garmin si la demanda real las prioriza.
- Localización adicional basada en búsquedas e ingresos, no por intuición.
- Comunidad reactivada con densidad suficiente, moderación y grupos por programa.
- Android solo si el canal y la demanda justifican duplicar superficie; no antes de consolidar el loop iOS.

## 7. Monetización y packaging

### Problema actual

- €8,99/año y €19,99 lifetime están muy por debajo de Hevy, Strong, Boostcamp, Alpha, Fitbod y SmartGym.
- Un precio demasiado bajo puede limitar CAC, soporte, contenido profesional y percepción de calidad.
- El weekly añade riesgo de churn/refund y hace que una app de progreso a largo plazo parezca transaccional.
- El paywall actual usa `RevenueCatUI.PaywallView` directamente; el código de preview contextual existe, pero no participa en `body`.

### Packaging recomendado

#### Free — debe crear hábito y confianza

- Logging ilimitado.
- Un plan activo y rutinas propias con límite razonable.
- Historial completo visible; limitar profundidad analítica, no secuestrar datos.
- Métricas básicas, PR y 1RM.
- Sustituciones manuales.
- Apple Watch básico.
- Exportación de datos iniciada por usuario.

#### Pro — debe mejorar decisiones

- Progresión adaptativa y explicaciones.
- Múltiples planes, bloques y periodización.
- Analítica avanzada, carga, fatiga y músculos.
- Readiness y recomendaciones HealthKit.
- Watch avanzado/offline y personalización.
- Programas premium.
- Backup permitido y compliant, si se resuelve.
- Share cards avanzadas y weekly review.

### Hipótesis de precio para investigar, no aplicar a ciegas

- Mensual: €4,99.
- Anual de lanzamiento: €29,99; precio estándar a validar: €39,99.
- Lifetime founder limitado: €59,99; estándar potencial: €79,99.
- Retirar weekly de la presentación principal.
- Mantener clientes existentes grandfathered.

Antes de cambiar:

- Van Westendorp con al menos 100 respuestas del segmento principal.
- Test de packaging, no solo de número.
- Medir conversión, ingresos por install, refund y retención, no CTR aislado.

Trial:

- Control: 7 días después de valor.
- Variante: 14 días con recap de progreso y recordatorios claros.
- Anual seleccionado por defecto, mensual visible; lifetime como opción secundaria.

Benchmarks externos para orientar, no como garantía:

- D35 paid Health & Fitness: 2,9% mediana; >6,2% cuartil superior.
- Trial-to-paid general: 37,4% para trials de 5–9 días y 42,5% para 17–32 días.

## 8. Plan de experimentación

| Prioridad | Hipótesis | Cambio | Métrica primaria | Guardrail |
|---|---|---|---|---|
| E1 | Activar el plan Free aumenta primer workout | Activación automática + CTA | First workout D1 | Paywall views no deben crecer |
| E2 | Cobrar tras valor convierte mejor | Paywall tras summary | D35 paid / revenue per install | D7 retention |
| E3 | Today simplificado reduce indecisión | Workout primero, weather después | Tiempo a workout start | Uso Health no cae >20% |
| E4 | Explicar la recomendación genera confianza | «Por qué» + aceptar/editar | Acceptance rate | Correcciones manuales y lesiones reportadas |
| E5 | Watch básico Free impulsa Pro | Logging básico libre | Watch activation → Pro | Coste de soporte/crashes |
| E6 | Precio mayor mejora negocio sin destruir conversión | €29,99 vs €39,99 anual | Revenue per install D60 | Refund, churn, rating |
| E7 | 14 días crea más hábito que 7 | Trial 7 vs 14 | Paid retained D60 | Trial abuse y cancelaciones |
| E8 | Migración reduce switching cost | Import Strong/Hevy | Import completed → first workout | Errores de datos |

Reglas:

- Una métrica primaria por experimento.
- Definir duración y tamaño de muestra antes de empezar.
- No tomar decisiones con menos de dos ciclos semanales completos salvo bug.
- Segmentar nuevos, migrados, Watch/no Watch y principiante/intermedio.

## 9. Cuadro de mando

### Calidad/release

- Build success Debug/Release: 100%.
- Tests: 100% verdes.
- Crash-free users: objetivo operativo inicial ≥99,8%.
- ANR/hangs, hitches y duración de persistencia.
- Watch exact-once sync ≥99,5% como objetivo inicial.
- Cero claves visibles sin EN/ES.

### Activación

- Onboarding completion.
- Plan generado → activado.
- Primer set D0.
- Primer workout D0/D1.
- Mediana de tiempo install → first set.
- Primer workout finalizado / iniciado.

Objetivos operativos iniciales, a recalibrar tras obtener baseline:

- Onboarding completion ≥70%.
- Primer workout D1 ≥40%.
- Finalización del primer workout ≥70% de los iniciados.
- Mediana a primer set <3 minutos desde instalación y <20 segundos desde abrir una rutina.

### Retención

- D1, D7, D30 por cohorte.
- WAU que completan 2+ workouts.
- Semanas consecutivas activas.
- Recuperación tras 7 días de inactividad.

### Monetización

- Paywall impression por source.
- Preview → CTA.
- CTA → trial/purchase.
- Trial-to-paid.
- D35 download-to-paid.
- Revenue per install D14/D60.
- Refund, cancelación y retención por plan.
- Motivo de cancelación.

### Confianza

- Recomendación aceptada/editada/rechazada.
- Incidencias de sync/duplicado.
- Exportaciones e imports completados.
- Rating y temas de reseñas.
- Contactos de soporte por 1.000 workouts.

## 10. Investigación propia que falta

No crear personas definitivas hasta tener evidencia propia.

Próximos 30 días:

1. 8 entrevistas con usuarios de Hevy/Strong que programan por su cuenta.
2. 8 entrevistas con usuarios de Fitbod/Alpha que quieren guía.
3. 5 entrevistas con usuarios intensivos de Apple Watch.
4. Test moderado con 5 principiantes: llegar al primer set sin ayuda.
5. Test con 5 intermedios: editar plan, sustituir ejercicio y entender la recomendación.
6. Encuesta de cancelación y microencuesta tras tercer workout.
7. Banco de citas VOC etiquetado por job, dolor, trigger, objeción y resultado.

Preguntas críticas:

- ¿Qué tendría que pasar para abandonar su historial actual?
- ¿Qué recomendación automática no confiarían nunca?
- ¿Qué información necesitan para aceptar subir/bajar carga?
- ¿Pagarían por Watch, por programación o por analítica?
- ¿Qué datos consideran demasiado sensibles para cloud/analytics?

## 11. Qué no hacer ahora

- No añadir nutrición completa.
- No expandir rehabilitación hacia claims médicos.
- No construir un feed social más amplio antes de moderación y densidad.
- No usar «AI» como posicionamiento genérico.
- No generar programas con LLM sin motor determinista y validación profesional.
- No bloquear logging, historial básico o exportación detrás de Pro.
- No reescribir `AppStore` de golpe.
- No lanzar paid acquisition antes de medir activation, D7 y D35 paid.
- No competir por el catálogo más grande; competir por la mejor decisión y ejecución.

## 12. Orden de ejecución final

1. Release/compliance: tests, UGC, iCloud Health, legal, localización, privacidad.
2. Activación: plan Free activo, primer workout, permisos progresivos.
3. Core: logging, recuperación, exact-once sync, sustitución.
4. Diferencial: progresión/readiness explicables y Watch.
5. Monetización: packaging, paywall contextual, pricing tests.
6. Adquisición: ASO, contenido, reviews, referidos y partnerships.
7. Escala: programas/coach platform, nuevas integraciones y plataformas.

Si StreakRep ejecuta bien este orden, puede competir de tú a tú no por tener más casillas que Hevy, Fitbod o SmartGym, sino por resolver mejor la pregunta que realmente paga el usuario: **«¿Qué hago hoy para seguir progresando y cómo sé que está funcionando?»**
