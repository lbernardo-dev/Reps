# Integración RevenueCat — Pasos manuales

Completa estos pasos **en orden** antes de decirme que continúe.  
Yo implementaré el código después de que tengas la API Key.

---

## Paso 1 — Crear cuenta y app en RevenueCat

1. Ve a **[app.revenuecat.com](https://app.revenuecat.com)** e inicia sesión (o crea cuenta con tu email `lbernardo.cu@gmail.com`).
2. En el dashboard, pulsa **"+ New app"** (arriba a la derecha o en el selector de apps).
3. Rellena:
   - **App name:** `StreakRep`
   - **Platform:** `App Store`
   - **Bundle ID:** `com.romerodev.repsfitness`
4. Pulsa **Save**.

---

## Paso 2 — Conectar App Store Connect a RevenueCat

RevenueCat necesita validar receipts contra Apple. Hay que darle una **App Store Connect API Key**.

1. Ve a [appstoreconnect.apple.com/access/integrations/api](https://appstoreconnect.apple.com/access/integrations/api).
2. Pulsa **"+"** para generar una nueva clave.
   - **Name:** `RevenueCat`
   - **Access:** `Finance` (es suficiente para RC)
3. Descarga el archivo `.p8` — **solo se puede descargar una vez**.
4. Anota el **Key ID** (8 caracteres, ej: `ABC12DEF34`) y el **Issuer ID** (UUID largo que aparece arriba de la lista de claves).
5. Vuelve al dashboard de RC → tu app → **App Store Connect** (en el menú lateral izquierdo).
6. Sube el `.p8` y rellena:
   - **Key ID:** el de 8 caracteres
   - **Issuer ID:** el UUID largo
   - **App-specific shared secret:** (opcional, pero recomendado) — en App Store Connect → tu app → **App Information** → **App-Specific Shared Secret** → Generate.
7. Pulsa **Save**.

---

## Paso 3 — Crear el Entitlement "pro"

1. En RC, menú lateral → **Entitlements** → **"+ New"**.
2. Rellena:
   - **Identifier:** `pro` ← exactamente este valor, en minúscula
   - **Description:** `Reps Pro access`
3. Pulsa **Add**.

---

## Paso 4 — Añadir los 4 productos

1. Menú lateral → **Products** → **"+ New"**.
2. Añade los 4 productos uno a uno con estos valores exactos:

| Product identifier | Tipo |
|---|---|
| `com.romerodev.repsfitness.pro.weekly` | Subscription |
| `com.romerodev.repsfitness.pro.monthly` | Subscription |
| `com.romerodev.repsfitness.pro.annual` | Subscription |
| `com.romerodev.repsfitness.pro.lifetime` | Non-subscription (One-time) |

3. Para cada uno: pega el identifier, selecciona el tipo y pulsa **Save**.

---

## Paso 5 — Adjuntar productos al Entitlement "pro"

1. Menú lateral → **Entitlements** → pulsa en `pro`.
2. Pulsa **"Attach"**.
3. Selecciona los 4 productos del paso anterior.
4. Pulsa **Save**.

---

## Paso 6 — Crear el Offering "default"

1. Menú lateral → **Offerings** → **"+ New"**.
2. Rellena:
   - **Identifier:** `default` ← exactamente este valor
   - **Description:** `Main offering`
3. Pulsa **Add**.

---

## Paso 7 — Crear los Packages dentro del Offering

Dentro del offering `default`, pulsa **"+ New package"** 4 veces:

| Package identifier | Product que asignas |
|---|---|
| `$rc_weekly` | `com.romerodev.repsfitness.pro.weekly` |
| `$rc_monthly` | `com.romerodev.repsfitness.pro.monthly` |
| `$rc_annual` | `com.romerodev.repsfitness.pro.annual` |
| `$rc_lifetime` | `com.romerodev.repsfitness.pro.lifetime` |

Para cada package: pulsa **"+ New package"**, elige el identifier de la lista (`$rc_weekly`, etc.), luego en la sección "Products" asigna el producto correspondiente de la tabla y pulsa **Save**.

---

## Paso 8 — Copiar la API Key pública

1. Menú lateral → **API Keys** (o en la cabecera de tu app → ⚙️ Settings → API Keys).
2. Copia la clave que empieza por **`appl_`** — es la **Public SDK key**.
   - No es la secret key (empieza por `sk_`). La que necesito yo es la que empieza por `appl_`.

---

## ✅ Checklist antes de avisarme

- [ ] App creada en RC con bundle ID `com.romerodev.repsfitness`
- [ ] App Store Connect API Key conectada (archivo `.p8` subido)
- [ ] Entitlement `pro` creado
- [ ] 4 productos añadidos y adjuntados al entitlement `pro`
- [ ] Offering `default` creado con 4 packages
- [ ] Tengo la **Public SDK Key** (`appl_...`)

Cuando tengas todo esto, dime:

> "RC listo, la key es `appl_XXXXXXXXXX`"

…y yo implemento todo el código automáticamente.

---

## Lo que yo haré después (sin que tengas que tocar nada)

- Añadir RevenueCat SDK al proyecto vía Swift Package Manager
- Inicializar RC al arrancar la app con tu API Key
- Reemplazar el flujo de compra (`purchaseSubscription`) con RC
- Reemplazar el restore de compras con RC
- Actualizar `MonetizationState` desde `CustomerInfo` de RC (fuente de verdad única)
- Suscribir al stream de cambios de entitlement en tiempo real
- Mantener el sistema `iCloudOwner` en paralelo (no lo gestiona RC)
- Actualizar `PaywallView` para mostrar precios reales desde RC `Offerings`
- Build, commit, push y subida a App Store Connect
