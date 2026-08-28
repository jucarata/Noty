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

Las claves públicas se inyectan en **compile-time** con `--dart-define-from-file=.env` (no se empaquetan como asset). Si faltan, `BackendClient.initialize` falla. En local: F5 (config **noty**), args en `.vscode/settings.json`, o `.\scripts\run.ps1`. En CI, el mismo flag con el archivo de ese entorno.

Las pantallas **no** lo llaman. Solo las capas `data/remote` o los services de cada feature.

No se llama Notificator: cuando existan reportes, vínculo familiar o auth, el tubo sigue siendo el mismo y el nombre seguiría siendo mentira.

### Fachada por feature (una por módulo que hable con la nube)

Cada módulo que persiste o sincroniza tiene **su** fachada de producto:

| Feature | Fachada | Responsabilidad |
|---|---|---|
| `notifications` | `Notificator` | Crear, editar, eliminar, listar recordatorios; confirmar y programar alarmas (aún no). Ver `notifications.md`. |
| `care` | `CareService` | Vínculo familiar, dispositivos. UI en tab Familia + pantallas de QR. |
| `auth` | `AuthService` | Sesión. UI actual: correo y anónimo. Google/Microsoft están en la fachada, no en la pantalla. |
| `reports` (futuro) | p. ej. `ReportsService` | Historial y cumplimiento |

No se clona un “Notificator” por módulo. El nombre describe el dominio, no el hecho de que hable con internet.

El Notificator de recordatorios:

- Expone acciones de producto: crear, editar, eliminar, listar, confirmar, sincronizar.
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
  main.dart                 ← AuthGate: sesión persistida → MainShell o login
  core/
    constants/
    theme/
    widgets/
    network/
      backend_client.dart   ← único tubo al servidor (incluye auth técnico)
    storage/                ← setup de la base local (cuando exista)
  auth/
    models/                 ← AuthSession, AuthFailure
    services/               ← AuthService (fachada de sesión)
    screens/                ← LoginScreen, SignUpScreen
    widgets/                ← AuthGate
  home/
    screens/                ← HomeScreen, MainShell (footer: Inicio, Notificaciones, Familia, Perfil)
    widgets/
  profile/
    screens/                ← ProfileScreen
  notifications/
    models/
    data/
      local/
      remote/
    services/               ← Notificator (fachada; createReminder persiste en nube)
    screens/                ← NotificationsScreen, AddNotificationScreen
    widgets/
  care/
    models/, data/, services/, screens/
  family/
    screens/                ← FamilyScreen (tab; usa CareService)
```

`care/` y `reports/` nacerán como features hermanas, cada una con su fachada, todas usando el mismo `BackendClient`. El esquema de identidad y familia ya está en `supabase/migrations/`.

Sesión: `supabase_flutter` la guarda en el dispositivo. Al reabrir la app (aunque se haya cerrado del todo), `AuthGate` lee esa sesión. Anónimo y cuenta real cuentan como “ya entró”. Redirect OAuth: `com.noty.noty://login-callback` (también en Authentication → URL Configuration de Supabase).

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

- `home/screens` → `notifications/services` (Notificator).
- `home/screens` (MainShell) → `home` y `profile` (tabs del footer).
- `profile/screens` → `auth/services` (AuthService: cerrar sesión, purgar).
- `auth/screens` y `auth/widgets` → `auth/services` (AuthService).
- `notifications/services` → `data/local`, `data/remote` y `core/network`.
- `auth/services` → `core/network` (`BackendClient`).
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

**Base de datos:** persistencia canónica de personas, dispositivos, grupos familiares, y (luego) recordatorios y confirmaciones. Esquema en la sección 10.

## 9. Qué no hacer

- Meter toda la lógica en `home`.
- Llamar a Supabase, a la API o a `BackendClient` desde un widget.
- Un único “Notificator” para auth, recordatorios y reportes.
- Crear un servidor propio antes de que un recordatorio suene offline.
- Microservicios. Un backend, una base, una app.
- Tabla `public.users` (choca con `auth.users`). La persona es `profiles`.
- Usar IMEI / `ANDROID_ID` / `identifierForVendor` como identidad. El dispositivo se identifica con `devices.install_id` generado por la app.

## 10. Modelo de datos (Postgres / Supabase)

SQL canónico: `supabase/migrations/` (`care_identity`, `reminders`).

Auth, vínculo familiar y el alta/edición de recordatorios ya están en la app. Mutar usa RPCs `create_reminder`, `update_reminder` y `delete_reminder` (RLS de lectura + sin insert directo). Caché local y alarmas, todavía no.

### Idea

Hay cuatro entidades, no una tabla “users” con el id del celular:

1. **Persona** (`profiles`) — quien es. Correo, Google, Microsoft o anónimo comparten el mismo `id` (`auth.users.id`).
2. **Dispositivo** (`devices`) — un install de la app. Identidad = `install_id` (UUID que genera Noty y guarda en secure storage). Eso va en el QR.
3. **Grupo familiar** (`families` + `family_members`) — quién cuida a quién.
4. **Recordatorio** (`reminders` + `reminder_devices` + `reminder_responses`) — qué recordar, en qué teléfonos suena, y si confirmaron o ignoraron.

“Continuar sin login” (p. ej. un abuelo sin correo) **no** es un hueco sin fila: es **Auth anónimo** de Supabase. Hay `auth.uid()`, se crea `profiles`, se registra el `device`, y RLS funciona. Al reabrir la app, la sesión anónima + el `install_id` local permiten cargar los padres asociados.

Hay que activar **Allow anonymous sign-ins** en Authentication → Sign In / Providers cuando se implemente ese flujo. Crear familia y escanear QR siguen bloqueados para anónimos (solo cuenta real).

### Tablas

**`profiles`**

| Columna | Notas |
|---|---|
| `id` | PK = `auth.users.id`. Trigger `handle_new_user` al registrarse (incluido anónimo). |
| `display_name` | Nombre visible. Google/Microsoft pueden traerlo en metadata. |
| `created_at`, `updated_at` | |

**`devices`**

| Columna | Notas |
|---|---|
| `id` | PK interno |
| `install_id` | Unique. Lo genera la app. **No** es el id de hardware del SO. |
| `owner_id` | Profile que usa este teléfono. Un padre con celular y tablet = dos filas. |
| `custom_name` | “Celular de la abuela” |
| `platform` | `android` \| `ios` |
| `brand`, `model` | Samsung, Apple, Galaxy A54, iPhone 13… |
| `device_kind` | `phone` \| `tablet` |
| `os_version` | Opcional |
| `last_seen_at` | Última vez que abrió la app |

Si desinstalan la app, se pierde el `install_id` (secure storage). Hay que volver a vincular. El id del SO no lo evita de forma fiable.

**`families`**

| Columna | Notas |
|---|---|
| `host_id` | Profile **no anónimo** que creó el grupo |
| `name` | “Familia Pérez” |

**`family_members`**

| Columna | Notas |
|---|---|
| `family_id`, `profile_id` | Persona en ese grupo |
| `device_id` | Obligatorio si `role = accompanied` (el teléfono del QR). Null en host/caregiver |
| `role` | `host` \| `caregiver` \| `accompanied` |

Un mismo profile puede ser `host` en la familia A y `accompanied` en la B. Un device puede estar en **varias** familias (varios padres con grupos distintos).

Al reabrir el teléfono del abuelo: membresías `accompanied` de ese `device` → miembros `host` / `caregiver` de esas familias = padres asociados.

**`reminders`**

| Columna | Notas |
|---|---|
| `name`, `description` | Título obligatorio; descripción opcional |
| `time_local` | Hora de pared (`time`), sin fecha |
| `timezone` | IANA. Default `America/Bogota`. No es el país |
| `start_date` | Día civil en que empieza a sonar. Distinto de `time_local` y de `created_at`. Casi siempre el día de creación; puede ser otro. Desde ahí se cuentan `run_days` y el disparo de `single_use` |
| `single_use` | Default `false`. Una sola vez a `time_local` en `start_date`. **Excluye** `every_day`, lun–dom y `run_days` (check en SQL). Tras sonar, `is_active` = false |
| `every_day` | Default `true`. Si está activo, ignora lun–dom. Incompatible con `single_use` |
| `monday` … `sunday` | Días concretos. Al menos uno si no es `single_use` ni `every_day` |
| `run_days` | Hasta cuántos **días de alarma** desde `start_date`. Cada día marcado cuenta 1; suena una vez ese día a `time_local`. Solo lunes y `7` = el 7º lunes es el último. Lun+mar y `10` = termina el martes de la 5ª semana. Al cumplirse, `is_active` = false (no aplica si `every_day`). `null` si `single_use` |
| `is_active` | Default `true`. Si no es todos los días, al acabar `run_days` (o la única vez de `single_use`) pasa a false y hay que reactivar. Si `every_day`, sigue activa hasta desactivarla a mano |
| `created_by` | Profile que lo creó. No es `families.host_id` |
| `deleted_at` | Soft delete. `null` = vigente. No hay `is_deleted` |

Migración: `supabase/migrations/20260827020000_reminders.sql` (tablas, RLS de lectura y RPC `create_reminder`). Editar y borrar: `20260827040000_reminders_update_delete.sql`. Mutar no es insert directo desde el cliente.

**`reminder_devices`**

| Columna | Notas |
|---|---|
| `reminder_id` | FK a `reminders`. Cascade al borrar el recordatorio |
| `device_id` | FK a `devices.id` (PK interno). **No** `install_id` |
| unique | `(reminder_id, device_id)` |

El teléfono acompañado se reconoce por `install_id` local → fila `devices` → filas en `reminder_devices`.

**`reminder_responses`**

| Columna | Notas |
|---|---|
| `reminder_id`, `device_id` | Qué recordatorio y en qué teléfono |
| `response` | Solo `confirmed` o `ignored` (descartó o dijo que no) |
| `due_at` | Cuándo debía sonar esa ocurrencia |
| `responded_at` | Cuándo pulsó confirmar o ignorar |
| unique | `(reminder_id, device_id, due_at)` — una respuesta por disparo |

Sin fila = todavía no hay respuesta (el teléfono no contestó). Las alertas futuras salen de `ignored` o de esa ausencia. No hay estado `missed` ni `error` en esta tabla.

### Cómo mutar (no desde la UI)

| Acción | Cómo |
|---|---|
| Nuevo auth (cualquier provider o anónimo) | Trigger → `profiles` |
| Registrar/actualizar este teléfono | Insert/update en `devices` con `owner_id = auth.uid()` |
| Padre crea grupo | RPC `create_family(p_name)` |
| Padre escanea QR | RPC `link_device_to_family(p_install_id, p_family_id?)`. Si no hay familia, crea “Mi familia”. |
| Padre crea recordatorio | RPC `create_reminder(...)` → `reminders` + `reminder_devices`. Solo cuenta real; devices de familiares acompañados. |
| Padre edita recordatorio | RPC `update_reminder(...)` → actualiza la fila y reemplaza `reminder_devices`. Solo `created_by`. |
| Padre elimina recordatorio | RPC `delete_reminder(p_id)` → `deleted_at`, `is_active = false`, se borran los `reminder_devices`. |
| Purgar cuenta (**temporal**, pruebas en home) | RPC `purge_own_account` + cierre de sesión local. Quitar con el botón cuando exista Profile. |

No hay políticas de INSERT directo en `families` ni `family_members`. Así un cliente no enumera ni reclama devices ajenos: hace falta el `install_id` del QR.

### RLS (resumen)

Quien llama es `authenticated` (sesión real o anónima). Sin sesión, nada.

- `profiles`: leer el propio y a quienes comparten familia; editar solo el propio.
- `devices`: el dueño CRUD el suyo; miembros de la familia leen el device acompañado.
- `families` / `family_members`: leer si eres miembro; el host puede renombrar la familia.

### Flujos de producto ↔ datos

| En la app | En la base |
|---|---|
| Continuar sin login | `signInAnonymously` → `profiles` + `devices` |
| QR “vincularse a grupo familiar” | payload = `install_id` |
| Padre escanea | `link_device_to_family` → member `accompanied` |
| Otro hijo escanea el mismo QR | el device entra en **su** familia (segundo padre) |
| Padres al reabrir (abuelo) | carers de las familias de este device |
| Yo cuido y a mí me cuidan | el mismo `profile` en dos `families` con roles distintos |

Invitar a un segundo cuidador **al mismo** grupo (recordatorios compartidos) es un paso posterior (`invites`). Hoy, dos padres = dos familias que comparten el device.

Alertas a familiares cuando no confirman **no** están implementadas; la tabla `reminder_responses` es el dato que las alimentará.
