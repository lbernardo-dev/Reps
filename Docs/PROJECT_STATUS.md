# Reps — Estado del proyecto

Fecha de actualización: 2026-08-02

## Alcance actual

Reps es una aplicación SwiftUI local-first con SwiftData, HealthKit, CloudKit Social, Firebase/Crashlytics, RevenueCat, widgets y companion de watchOS. El proyecto se genera desde project.yml y usa Xcode 26.6, Swift 6.3.3, iOS/watchOS 26 como deployment target.

La estabilización de permisos y localización es una fase previa a las correcciones visuales y de rendimiento. El ajuste fino de espaciados, jerarquía visual, animaciones y profiling queda deliberadamente para el cierre de la tanda de correcciones.

## Autorización social

- Existe un único superadmin: el owner record name de CloudKit configurado en SocialAuthorization.
- El username, display name y cualquier dato editable del perfil no conceden permisos.
- El superadmin y solo los moderadores registrados por el superadmin pueden ejecutar moderación.
- Solo el superadmin puede conceder o retirar el rol de moderador.
- Las operaciones sensibles vuelven a comprobar la autorización dentro de SocialService; ocultar botones no es la única barrera.
- La cuenta sin owner record name válido no obtiene acceso de moderación.

## Localización

- Idioma base: inglés.
- Idioma adicional: español.
- El catálogo principal es Reps/Resources/Localizable.xcstrings.
- Las claves activas del catálogo deben ser únicas, estables y estar en snake_case.
- Cada clave de la aplicación debe tener localización en en y es.
- Los textos visibles no deben vivir en diccionarios bilingües, fallbacks manuales, modelos de datos ni condiciones de idioma.
- Las cadenas con valores dinámicos deben usar interpolación o format styles de Foundation, manteniendo la clave en el catálogo.
- Los nombres obligatorios de claves de InfoPlist de Apple son una excepción técnica: sus identificadores no se renombrarán porque forman parte del contrato del sistema.
- La comprobación automatizada es:

    node Scripts/verify-localization.mjs

- La normalización reproducible del catálogo es:

    node Scripts/normalize-localization.mjs

El catálogo ya declara en como source language, incluye version 1.0 y no contiene claves activas fuera de snake_case. La cobertura completa de literales visibles sigue siendo trabajo de esta fase: PulseTheme, snapshots compartidos, widgets/watch, accesibilidad y algunos mensajes de error aún requieren migración o revisión de traducción.

## Documentación canónica

Este archivo describe el estado operativo. La política de claves y localización está en Docs/LOCALIZATION_POLICY.md. Los documentos de auditoría histórica que contradicen este estado se han retirado.

## Validación pendiente

1. Terminar la migración de textos visibles restantes y hacer que verify-localization sea una puerta limpia.
2. Compilar app, widgets y watch en sus destinos válidos.
3. Ejecutar la suite de tests y revisar la autorización social.
4. Actualizar las guías de release y privacidad si la implementación cambia sus superficies.
5. Cerrar visual QA y profiling al final de la tanda.
