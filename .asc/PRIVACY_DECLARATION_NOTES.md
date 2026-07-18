# App Privacy — notas de la declaración (2026-07-18)

`privacy-declaration.json` sustituye a `privacy-data-not-collected.json` (eliminado):
la app SÍ recoge datos — Firebase Analytics/Crashlytics (crash, performance,
product interaction, device id), RevenueCat (purchase history, id anónimo),
perfil social público en CloudKit (nombre, username, fotos, contenido, stats
fitness de los posts — VINCULADOS a identidad) y coordenadas para el clima
(WeatherKit/MET Norway, no vinculadas).

HealthKit y las rutas GPS NO se declaran como recogidos: viven en el dispositivo
y en el iCloud privado del usuario (inaccesible para el desarrollador). Si algún
día los posts sociales incluyen datos de salud o rutas, ampliar la declaración.

No hay tracking (sin ATT, sin redes de anuncios): ninguna categoría lleva
DATA_USED_TO_TRACK_YOU.

Aplicar (requiere sesión web de Apple — pedirá 2FA):

    asc web privacy pull --app "APP_ID" --out ./.asc/privacy-remote.json   # estado actual
    asc web privacy plan --app "APP_ID" --file ./.asc/privacy-declaration.json
    asc web privacy apply --app "APP_ID" --file ./.asc/privacy-declaration.json
    asc web privacy publish --app "APP_ID" --confirm

Validar los tokens contra `asc web privacy catalog` en la primera ejecución:
si algún token difiere del catálogo vivo, ajustar este archivo antes de apply.
Mantener este JSON sincronizado con RepsShared/PrivacyInfo.xcprivacy.
