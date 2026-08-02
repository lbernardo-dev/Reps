# Política de localización de Reps

## Contrato

La aplicación usa inglés como idioma fuente y español como idioma adicional. No se admite que una pantalla dependa de que el dispositivo esté en español para funcionar.

Las claves de aplicación:

- son únicas;
- usan snake_case y empiezan por una letra;
- expresan intención, no el texto accidental de una pantalla;
- se mantienen estables aunque cambie la traducción;
- tienen entradas en en y es en Reps/Resources/Localizable.xcstrings.

## Código permitido

Para SwiftUI y servicios se usan String(localized:), LocalizedStringResource, localizedString o los helpers del proyecto cuando la clave procede del catálogo. Para widgets, watchOS y App Intents se usan recursos localizados compatibles con esas extensiones.

Los valores dinámicos usan interpolación localizada, String.LocalizationValue, format styles o las APIs de Foundation que preservan locale y pluralización.

## Código no permitido

No se deben añadir textos visibles en:

- Text, Label, Button, alert, navigationTitle o accessibilityLabel;
- diccionarios de traducción por idioma;
- fallbacks en inglés o español dentro de modelos;
- switches que devuelven textos según hasPrefix("es");
- snapshots, widgets o watch con copy visible sin catálogo;
- errores que expongan un mensaje de usuario sin clave.

Los nombres de SF Symbols, URLs, identificadores CloudKit, claves de InfoPlist, nombres de tipos y valores técnicos no son copy traducible.

## Flujo de cambio

1. Añadir o modificar la clave en Localizable.xcstrings con en y es.
2. Usar la clave desde el código.
3. Ejecutar normalize-localization cuando se haya hecho una migración masiva.
4. Ejecutar verify-localization.
5. Compilar app, widgets y watch y revisar el idioma inglés y español.

La normalización elimina entradas antiguas no referenciadas. No debe usarse para sustituir expresiones que contengan llamadas localizadas anidadas; esas migraciones se hacen con cambios de código acotados y revisión de compilación.
