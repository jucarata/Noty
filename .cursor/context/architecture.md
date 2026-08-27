# Arquitectura técnica: Noty

Fuente de verdad de cómo está organizada la app y cómo habla con el backend. El producto y la marca viven en `brand-and-product.md`; este archivo no define copy ni alcance de negocio.

## 1. Idea central

En **diseño** hay tres servicios:

1. **App móvil** (Flutter) — UI, caché local, alarmas del sistema.
2. **Backend** — la verdad compartida entre dispositivos (hoy Supabase; mañana puede ser una API propia).
3. **Base de datos** — Postgres en Supabase.

En **el MVP** son dos piezas reales: la app y Supabase (que ya incluye API, auth y Postgres). No se construye un servidor Nest/Express/FastAPI “por si acaso”.

La app móvil **no sabe** si lo remoto es Supabase, Edge Functions o `api.noty.app`. Las pantallas no importan clientes de red ni de base de datos.

## 2. Dos contratos, no uno

El tubo hacia afuera y la lógica de cada feature **no son la misma clase**.

```
Pantallas / widgets
        ↓
  Fachada del módulo     ← Notificator, más adelante CareService, AuthService…
        ↓
  local  |  BackendClient ← caché de la feature | un solo tubo al servidor
        ↓
  alarmas del SO          ← solo en notifications, desde datos locales
```

### BackendClient (uno para toda la app)

Vive en `lib/core/network/backend_client.dart`.

Es el servicio con el que la app habla **externamente**. Hoy encapsula Supabase; mañana una API propia. Auth, base URL, timeouts y “¿hay red?” viven aquí.

Las pantallas **no** lo llaman. Solo las capas `data/remote` o los services de cada feature.

No se llama Notificator: cuando existan reportes, vínculo familiar o auth, el tubo sigue siendo el mismo y el nombre seguiría siendo mentira.

### Fachada por feature (una por módulo que hable con la nube)

Cada módulo que persiste o sincroniza tiene **su** fachada de producto:

| Feature | Fachada | Responsabilidad |
|---|---|---|
| `notifications` | `Notificator` | Crear, listar, confirmar, sincronizar recordatorios; programar alarmas |
| `care` (futuro) | p. ej. `CareService` | Vínculo familiar, dispositivos |
| `auth` (futuro) | p. ej. `AuthService` | Sesión |
| `reports` (futuro) | p. ej. `ReportsService` | Historial y cumplimiento |

No se clona un “Notificator” por módulo. El nombre describe el dominio, no el hecho de que hable con internet.

El Notificator de recordatorios:

- Expone acciones de producto: crear, listar, confirmar, sincronizar.
- Lee y escribe primero en **local** (la UI siempre ve la caché).
- Sincroniza usando **BackendClient** cuando hay red.
- Programa y cancela alarmas del sistema operativo a partir de la caché.

No es un widget ni el cliente HTTP. Si más adelante hay Riverpod, el `Notifier` de estado **delega** en la fachada de la feature.

**No hacer:** un solo Notificator gigante que cree recordatorios, loguee usuarios y pida reportes. Se vuelve intocable en dos meses.

## 3. Offline-first

Dos verdades distintas:

| Pregunta | Dónde vive |
|---|---|
| ¿Qué recordatorios existen para esta persona / familia? | Nube (Supabase), sincronizado |
| ¿Suena la alarma a las 8:00 sin internet? | Obligatorio en el teléfono |

Reglas:

1. Un familiar (o la misma persona) crea un recordatorio → se persiste en la nube.
2. Al conectar, la app **baja** esos recordatorios a la caché local.
3. Las alarmas se programan **desde la caché**, no desde la red.
4. Confirmar (“Ya tomé mi medicamento”) se guarda local y se encola para subir. Si no hay red, se sube después.
5. Las pantallas leen **solo local**. Internet no pinta la UI; solo sincroniza.

## 4. Backend: ahora vs después

| Ahora (MVP) | Después, sin reescribir pantallas |
|---|---|
| `BackendClient` habla con Supabase (y/o Edge Functions) | `BackendClient` habla con una API propia; las fachadas no cambian |
| Una persona crea y recibe | El sync ya existe para el otro dispositivo |
| Confirmación local + subida | Reportes leen esas confirmaciones en la nube |
| Notificación local | Alertas / WhatsApp / IA viven en el backend, no en Flutter |

Se justifica un servidor aparte cuando haga falta lógica que no debe vivir en el teléfono: webhooks de WhatsApp, jobs de “no confirmó”, etc.

## 5. Estructura de `lib/`

Features **hermanas**. `home` no agrupa al resto. Lo compartido va en `core`.

```
lib/
  main.dart
  core/
    constants/
    theme/
    widgets/
    network/
      backend_client.dart   ← único tubo al servidor
    storage/                ← setup de la base local (cuando exista)
  home/
    screens/
    widgets/
  notifications/
    models/
    data/
      local/
      remote/
    services/               ← Notificator (fachada de esta feature)
    screens/
    widgets/
```

Más adelante pueden nacer `auth/`, `care/`, `reports/` como features nuevas, cada una con su fachada, todas usando el mismo `BackendClient`.

Assets de imagen en `assets/images/…`. Documentos de marca en `docs/`, no empaquetados en la app.

## 6. Capas dentro de una feature (punto dulce)

Por feature basta esto. No se usa Clean Architecture de 4 carpetas (`domain/usecases/entities/datasources`) salvo que el módulo se vuelva realmente grande.

- **models/** — datos de producto (`Reminder`, `Confirmation`, …).
- **data/local/** — SQLite (Drift cuando se implemente).
- **data/remote/** — usa `BackendClient`. La UI no la importa.
- **services/** — fachada del módulo (`Notificator` aquí) y colaboradores (alarmas, sync).
- **screens/** y **widgets/** — solo UI; llaman a la fachada de su feature.

Estado de UI: Riverpod (o Provider si se mantiene aún más simple). Bloc no es el default. Un `Notifier` de Riverpod no llama a Supabase ni a `BackendClient`: llama a la fachada (`Notificator`, etc.).

## 7. Dependencias permitidas

**Sí**

- `home/screens` → `notifications/services` (Notificator) o navegación a screens de notifications.
- `notifications/services` → `data/local`, `data/remote` y `core/network`.
- `data/remote` de cualquier feature → `BackendClient`.
- Cualquier feature → `core/`.

**No**

- Widgets o screens importando `BackendClient`, Supabase, `http`, Drift o SQL.
- Un Notificator global en `core/` que concentre todos los dominios.
- `notifications` importando screens de `home` (el flujo va hacia adentro: UI → fachada).
- Lógica de negocio del recordatorio duplicada en la pantalla.

## 8. Responsabilidad de cada pieza

**App móvil:** mostrar, alarmar, confirmar, sincronizar. Debe funcionar para el recordatorio del día aunque no haya red.

**Backend:** verdad compartida entre dispositivos y, a futuro, avisar a otras personas.

**Base de datos:** persistencia canónica de recordatorios, confirmaciones y (luego) vínculos familiares.

## 9. Qué no hacer

- Meter toda la lógica en `home`.
- Llamar a Supabase, a la API o a `BackendClient` desde un widget.
- Un único “Notificator” para auth, recordatorios y reportes.
- Crear un servidor propio antes de que un recordatorio suene offline.
- Microservicios. Un backend, una base, una app.
