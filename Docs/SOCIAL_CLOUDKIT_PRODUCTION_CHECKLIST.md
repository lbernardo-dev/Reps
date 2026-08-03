# Social y CloudKit: checklist de producción

La funcionalidad social usa la base pública del contenedor `iCloud.com.romerosoft.reps`. El esquema de desarrollo no se copia automáticamente a producción. Antes de distribuir una build, desplegar el esquema desde CloudKit Console y verificar la build contra el entorno de producción con dos cuentas iCloud reales.

## Índices necesarios

| Record type | Campo | Índice |
| --- | --- | --- |
| `SocialProfile` | `username` | Queryable |
| `SocialProfile` | `ownerRecordName` | Queryable |
| `SocialFollow` | `followingUsername` | Queryable |
| `WorkoutPost` | `ownerUsername` | Queryable |
| `WorkoutPost` | `creationDate` | Queryable + Sortable |
| `WorkoutLike` | `postOwnerUsername` | Queryable |
| `WorkoutLike` | `likerOwnerName` | Queryable |
| `WorkoutComment` | `postRecordName` | Queryable |
| `WorkoutComment` | `postOwnerUsername` | Queryable |
| `WorkoutComment` | `ownerUsername` | Queryable |
| `SocialBlock` | `blockerOwnerName` | Queryable |
| `SocialReport` | `status` | Queryable |
| `SocialReport` | `reporterOwnerRecordName` | Queryable |
| `Challenge` | `endDate` | Queryable |
| `Challenge` | `creationDate` | Sortable |
| `ChallengeParticipation` | `challengeID` | Queryable |
| `ChallengeParticipation` | `currentValue` | Sortable |

Los tipos `SocialBan` y `SocialModerator` deben permitir consultas sin predicado. Los campos usados por las tres `CKQuerySubscription` (`followingUsername` y `postOwnerUsername`) deben existir exactamente con esos nombres en producción.

## Modelo de relación

- Un `SocialFollow` unilateral es una solicitud pendiente.
- Solo la intersección entre relaciones salientes y entrantes es una amistad aceptada.
- El feed de amigos, los posts del perfil privado, el ranking y los contadores de amigos deben usar exclusivamente esa intersección.
- Bloquear elimina la relación saliente y oculta inmediatamente perfiles, sugerencias, búsquedas, posts y comentarios en el cliente.

## Prueba de aceptación con dos cuentas

1. Instalar la misma build (TestFlight o App Store) en dos dispositivos con cuentas iCloud distintas. No mezclar una build de desarrollo con otra de producción.
2. Crear `@cuenta_a` y `@cuenta_b`; confirmar que ambas aparecen buscando el nombre exacto y un prefijo.
3. A envía una solicitud a B. A debe ver «Pendiente»; B debe ver una invitación recibida y una notificación.
4. Antes de aceptar, ninguno debe ver al otro en Amigos ni en el feed de amigos.
5. B acepta. Ambos deben aparecer como amigos, la solicitud debe desaparecer y el feed debe actualizarse.
6. Desactivar notificaciones sociales y confirmar en CloudKit que se eliminan las tres suscripciones; reactivarlas y comprobar que se recrean.
7. Bloquear desde un post, comentario y perfil. El usuario bloqueado no debe volver a aparecer en ninguna superficie del cliente.
8. Denunciar un usuario, post y comentario; comprobar que los tres llegan como `SocialReport` pendiente a moderación.
9. Eliminar la cuenta y comprobar que desaparecen perfil, contenido propio, likes, comentarios, relaciones salientes, bloqueos, denuncias propias y suscripciones.

## Seguridad operativa

Las comprobaciones de moderador del cliente sirven para evitar operaciones accidentales, pero una aplicación modificada puede omitirlas. CloudKit debe restringir creación a usuarios autenticados y actualización/eliminación al creador. Las acciones que un moderador deba ejecutar sobre registros de terceros requieren un backend privilegiado (CloudKit Web Services/server-to-server) o una cola de acciones que procese ese backend. No se debe conceder escritura o borrado público para hacer funcionar el panel de moderación.

Los registros de denuncias no deben ser legibles desde el cliente ordinario. Si el esquema público no permite aislarlos con roles, mover la recepción y lectura de denuncias a un backend antes de producción.

## Push

- Capacidad Push Notifications activa y `remote-notification` en Background Modes.
- `aps-environment` correcto en la firma de distribución.
- Las notificaciones silenciosas de CloudKit se convierten en notificaciones visibles y llevan destino al perfil del actor cuando este puede resolverse.
- Revisar telemetría `social_subscription_save`, `social_subscription_delete` y `notif.did_fail_to_register_for_remote`.

## App Store Connect

Declarar como datos vinculados a la identidad y usados para funcionalidad: identificador de usuario, contenido de usuario y fotos/vídeos. Mantener alineados el formulario de privacidad, la política publicada y `PrivacyInfo.xcprivacy`.
