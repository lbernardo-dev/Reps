# StreakRep 1.0.0 - textos legales y App Store

Este documento contiene textos listos para publicar en las URLs reales de privacidad y terminos, notas para App Review, y una guia de privacidad para App Store Connect manteniendo iOS 26+.

## URLs que debes crear

- Politica de privacidad: `https://TU_DOMINIO/privacy`
- Terminos de servicio: `https://TU_DOMINIO/terms`
- Soporte: `mailto:TU_EMAIL_DE_SOPORTE`

Cuando existan, reemplaza en `Reps/Features/Profile/ProfileView.swift`:

```swift
private enum AppLegalLinks {
    static let privacyPolicy = "https://TU_DOMINIO/privacy"
    static let termsOfService = "https://TU_DOMINIO/terms"
}
```

## Politica de privacidad

# Politica de privacidad de StreakRep

Fecha de entrada en vigor: 6 de julio de 2026

StreakRep es una app de fitness para planificar entrenamientos, registrar sesiones, medir progreso, usar widgets, Live Activities y Apple Watch, y sincronizar determinados datos con servicios de Apple cuando el usuario lo autoriza.

## Datos que puedes guardar en la app

StreakRep puede guardar los datos que introduces o generas al usar la app:

- Perfil: nombre visible, email opcional, idioma, unidades, objetivo, nivel, preferencias de entrenamiento, equipamiento disponible y ajustes de la app.
- Entrenamientos: rutinas, ejercicios, series, repeticiones, peso, duracion, descanso, RPE, RIR, tempo, notas, fotos, notas de voz, historial, records personales y estadisticas.
- Salud y bienestar: peso, altura, hidratacion, energia, sueno, fatiga, estres, dolor, pasos, frecuencia cardiaca, HRV, VO2 Max, calorias, minutos de ejercicio y datos relacionados con recuperacion.
- Ubicacion: rutas GPS de caminatas o carreras al aire libre cuando decides iniciar una sesion con ruta.
- Comunidad: nombre de usuario social, perfil social, publicaciones, fotos compartidas, likes, comentarios, seguidores, retos y actividad social.
- Gimnasios: pases, codigos, visitas, notas, ubicacion de gimnasio e informacion de renovacion si decides guardarla.
- Multimedia: fotos de progreso, fotos asociadas a entrenamientos, imagenes de pases de gimnasio, fotos de publicaciones y notas de voz.
- Preferencias locales: idioma, tema, widgets, recordatorios, busquedas recientes, logros vistos y estado de uso.

## Apple Health

StreakRep solo accede a Apple Health si das permiso desde el dialogo del sistema. Puedes permitir o denegar cada tipo de dato desde Ajustes > Salud > Acceso a datos y dispositivos.

StreakRep puede leer datos como peso, altura, pasos, calorias activas, agua, energia ingerida, minutos de ejercicio, frecuencia cardiaca, HRV, VO2 Max, sueno, rutas y entrenamientos.

StreakRep puede escribir datos como peso, altura, agua, energia ingerida, calorias activas, distancia, frecuencia cardiaca, pasos, rutas y entrenamientos cuando eliges sincronizarlos.

StreakRep no vende datos de salud ni los usa para publicidad.

## Ubicacion

StreakRep usa la ubicacion para registrar rutas de carrera o caminata al aire libre. En entrenamientos con ruta, la app puede continuar registrando ubicacion mientras la pantalla esta bloqueada para completar la sesion. Puedes revocar el permiso desde Ajustes > Privacidad y seguridad > Localizacion.

## Camara, fotos y microfono

StreakRep puede solicitar:

- Camara: para capturar fotos de progreso, imagenes de entrenamientos o codigos de pases de gimnasio.
- Fotos: para seleccionar imagenes y para guardar/exportar imagenes cuando lo eliges.
- Microfono: para grabar notas de voz dentro de entrenamientos.

Estos permisos se solicitan solo cuando usas una funcion que los necesita.

## Apple Music

StreakRep puede pedir acceso a Apple Music para buscar y reproducir playlists durante entrenamientos. Apple gestiona la autorizacion y la disponibilidad de la suscripcion.

## iCloud, CloudKit, widgets, Watch y Live Activities

StreakRep puede usar iCloud/CloudKit para backups, restauracion, funciones sociales y sincronizacion de datos entre dispositivos cuando esta disponible. Widgets, Apple Watch y Live Activities leen un resumen minimo desde el App Group para mostrar progreso, entrenamiento activo, racha, bateria de recuperacion o actividad social.

## Analitica, diagnostico y rendimiento

StreakRep usa Firebase Analytics y Firebase Crashlytics para entender uso general de funciones, diagnosticar errores y mejorar estabilidad. Estos datos pueden incluir interacciones con producto, eventos de app, propiedades generales de configuracion, errores no fatales y crash reports.

StreakRep no usa estos datos para rastrear al usuario entre apps o sitios de otras empresas. StreakRep no solicita App Tracking Transparency porque no realiza tracking publicitario cross-app.

## Compras y suscripciones

Las compras digitales se procesan mediante In-App Purchase de Apple. StreakRep puede comprobar el estado de compra o suscripcion para desbloquear funciones Pro, restaurar compras y mostrar el estado de acceso. Apple gestiona el pago.

## Finalidades del tratamiento

Usamos los datos para:

- Proporcionar funcionalidades principales de entrenamiento y progreso.
- Sincronizar widgets, Watch, Live Activities y backups.
- Personalizar recomendaciones, rutinas y estadisticas.
- Enviar recordatorios y notificaciones que configuras.
- Procesar compras y restaurar acceso Pro.
- Mejorar estabilidad, diagnosticar errores y medir uso agregado.
- Permitir funciones sociales si decides activarlas.

## Comparticion de datos

StreakRep puede compartir datos con:

- Apple, para HealthKit, StoreKit, CloudKit, iCloud, Apple Music, notificaciones, widgets, Live Activities y Watch.
- Firebase/Google, para analitica y crash reporting.

No vendemos datos personales.

## Conservacion y eliminacion

Los datos locales permanecen en tu dispositivo salvo que uses iCloud, backups, funciones sociales o servicios de terceros indicados. Puedes eliminar datos desde la app cuando la funcion lo permita o desinstalando la app. Si necesitas solicitar eliminacion de datos asociados a servicios remotos, contacta con soporte.

## Seguridad

StreakRep usa APIs de Apple, almacenamiento local del sistema, iCloud/CloudKit y servicios de terceros para proteger y operar los datos. Ningun sistema es completamente infalible, pero aplicamos medidas razonables para proteger la informacion.

## Menores

StreakRep no esta dirigida a menores de 13 anos. Si crees que un menor ha proporcionado datos personales, contacta con soporte.

## Cambios

Podemos actualizar esta politica para reflejar cambios de producto, legales o tecnicos. La fecha de entrada en vigor indicara la version vigente.

## Contacto

Para privacidad, soporte o eliminacion de datos: `TU_EMAIL_DE_SOPORTE`.

## Terminos de servicio

# Terminos de servicio de StreakRep

Fecha de entrada en vigor: 6 de julio de 2026

Al usar StreakRep aceptas estos terminos.

## Servicio

StreakRep ayuda a planificar entrenamientos, registrar sesiones, consultar progreso, usar widgets, Apple Watch, Live Activities, funciones sociales y sincronizaciones opcionales con servicios de Apple.

StreakRep no es un servicio medico. La informacion de entrenamiento, recuperacion, salud y progreso es orientativa y no sustituye consejo medico, diagnostico, tratamiento ni supervision profesional.

## Uso responsable

Eres responsable de:

- Usar la app de forma segura y adecuada a tu condicion fisica.
- Consultar a un profesional sanitario antes de iniciar o cambiar entrenamientos si tienes dudas, lesiones, enfermedad o condiciones relevantes.
- Detener el ejercicio si sientes dolor, mareo, falta de aire anormal u otros sintomas preocupantes.
- Mantener informacion precisa si quieres que las recomendaciones sean utiles.

## Cuenta, perfil y contenido

Algunas funciones pueden permitir crear perfil social, publicaciones, retos, comentarios, fotos o interacciones. No debes publicar contenido ilegal, ofensivo, enganoso, invasivo de privacidad o que infrinja derechos de terceros. Podemos limitar o eliminar contenido si incumple estos terminos.

## Compras y StreakRep Pro

StreakRep puede ofrecer funciones Pro mediante compras dentro de la app, suscripciones auto-renovables o compra vitalicia.

Las compras en iOS se procesan con Apple In-App Purchase. Los precios, impuestos, pruebas gratuitas, renovaciones, cancelaciones y reembolsos se gestionan segun las reglas de Apple y App Store.

Las suscripciones se renuevan automaticamente salvo cancelacion desde la cuenta de Apple antes del fin del periodo vigente. Puedes gestionar o cancelar suscripciones desde Ajustes de iOS o App Store.

Una prueba gratuita, si esta disponible, se convertira en una suscripcion de pago al finalizar salvo cancelacion previa. La compra vitalicia, si esta disponible, no es una suscripcion y no incluye renovacion.

## Funciones de terceros

StreakRep puede integrarse con Apple Health, Apple Music, iCloud, CloudKit, notificaciones, widgets, Apple Watch, Firebase y servicios de compras dentro de la app. El uso de esos servicios puede estar sujeto a sus propios terminos y disponibilidad.

## Disponibilidad

Intentamos mantener StreakRep estable, pero no garantizamos disponibilidad continua ni ausencia de errores. Algunas funciones dependen de permisos, hardware, sistema operativo, conectividad, iCloud, App Store, Apple Health, Apple Watch u otros servicios externos.

## Limitacion de responsabilidad

En la medida permitida por la ley, StreakRep se ofrece "tal cual". No somos responsables de lesiones, perdidas de datos, interrupciones, decisiones de entrenamiento, resultados fisicos, fallos de terceros o danos indirectos derivados del uso de la app.

## Propiedad intelectual

StreakRep, su diseno, marca, codigo, textos, graficos y funcionalidades pertenecen a sus titulares. No puedes copiar, modificar, distribuir, vender ni explotar la app salvo lo permitido por la ley o por estos terminos.

## Terminacion

Puedes dejar de usar StreakRep en cualquier momento. Podemos suspender acceso a funciones si existe abuso, incumplimiento de estos terminos o riesgo para el servicio o terceros.

## Cambios

Podemos actualizar estos terminos por cambios legales, tecnicos o de producto. El uso continuado tras cambios implica aceptacion de la version vigente.

## Contacto

Para soporte o preguntas legales: `TU_EMAIL_DE_SOPORTE`.

## App Review Notes sugeridas

Pega esto en App Store Connect y ajusta datos reales:

```text
StreakRep is a native fitness app for workout planning, workout logging, progress analytics, widgets, Live Activities, and Apple Watch workouts.

No demo login is required for the core app. If App Review needs social features, use:
Username: [provide test user if required]
Password / access steps: [provide if required]

HealthKit:
The app reads Health data only after user authorization to show progress, recovery, daily metrics, workout history, heart rate, HRV, VO2 Max, steps, sleep, calories, hydration, and related metrics. The app can write workouts, body metrics, hydration, energy, route, heart rate, steps, and distance when the user chooses to sync. Health data is not used for advertising or tracking.

Location:
Location is used only for outdoor walk/run route recording. Background location is used during an active route workout so the workout can continue while the device is locked.

Background modes:
Audio supports Apple Music playback during workouts. Location supports active outdoor route recording. Remote notification supports CloudKit/social updates and silent push processing.

Apple Music:
Music access is used to search and play workout playlists when the user connects Apple Music.

Camera, Photos, Microphone:
Camera and Photos are used for progress photos, workout media, gym pass images, and sharing images. Microphone is used for optional workout voice notes.

In-App Purchases:
Digital Pro features are unlocked using Apple In-App Purchase. Restore Purchases is available from the paywall/subscription center. Products: weekly, monthly, annual, and lifetime Pro access.

Privacy:
The privacy policy is available in-app under Profile > Support > Legal and in App Store Connect.
```

## App Store Connect - Privacy Nutrition Labels

Marca al menos estas categorias si se mantienen las funciones actuales:

- Health: HealthKit, entrenamiento, recuperacion, metricas corporales.
- Fitness: entrenamientos, ejercicios, actividad, progreso, rutas.
- Location: rutas GPS y gimnasios si se guardan ubicaciones.
- Contact Info: email si se guarda en perfil o soporte.
- User ID: username social, identificadores de usuario o iCloud/CloudKit si aplica.
- User Content: fotos, notas, publicaciones, comentarios, notas de voz.
- Identifiers: Firebase installation/app instance identifiers si Firebase los usa.
- Usage Data / Product Interaction: eventos de uso, paywall, pantallas, funciones.
- Diagnostics: crash reports y errores.
- Purchases: estado de compra/suscripcion.

Declara "Tracking" solo si se usa tracking cross-app/cross-site. Con el codigo actual no hay ATT ni IDFA detectado, y `GoogleService-Info.plist` tiene `IS_ADS_ENABLED = false`.

## Fuentes tecnicas

- Apple App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Apple Privacy Manifest Files: https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- Apple App Privacy Details: https://developer.apple.com/app-store/app-privacy-details/
