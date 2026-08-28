# Módulo notifications — estado actual

Fuente de arquitectura: `architecture.md`. Este archivo describe **qué ya está en la UI** y qué falta. No reimplementar el flujo visual.

## Qué hay

El tab **Notificaciones** está en el footer de `MainShell`, entre Inicio y Familia.

| Pieza | Dónde |
|---|---|
| Lista | `lib/notifications/screens/notifications_screen.dart` |
| Alta en 2 pasos | `lib/notifications/screens/add_notification_screen.dart` |
| Tile de device con check | `lib/notifications/widgets/notification_device_tile.dart` |
| Fachada (vacía) | `lib/notifications/services/notificator.dart` |

El `+` abre `AddNotificationScreen` (ruta aparte, no un tab). La lista está **vacía a propósito**: aún no se guarda nada.

## Flujo visual (no tocarlo salvo pedido)

### Paso 1 — ¿Qué hay que recordar?

- **Nombre** (obligatorio). Ej. Tomar Losartan.
- **Descripción** (opcional). Ej. Tomar Losartan 500 mg.
- **Hora**, con el `TimePicker` del sistema.
- **Zona horaria**, default `America/Bogota` (Colombia).
- **Continuar** solo si hay nombre y hora.
- **Volver** cierra y regresa a la lista.

### Paso 2 — ¿En qué teléfonos sonará?

- Lista los dispositivos familiares ya vinculados (`CareService.listFamilyMembers`).
- Cada uno tiene check (`NotificationDeviceTile`).
- **Guardar notificación** se habilita con al menos un device marcado. El handler `_save` está vacío a propósito.
- **Volver** y el atrás del sistema vuelven al paso 1 **sin perder** nombre, descripción, hora, zona ni selección.

Lógica de UI permitida hoy: campos obligatorios, habilitar botones, avanzar/volver entre pasos, cargar devices para pintar checks. Nada más.

## Datos (nube)

Tablas: `reminders` + `reminder_devices` + `reminder_responses` (`supabase/migrations/20260827020000_reminders.sql`). RLS sin políticas. La app **aún no** escribe.

### `reminders` — periodicidad y estado

| Campo | Comportamiento |
|---|---|
| `start_date` | Día civil en que **empieza** a sonar. No es la hora (`time_local`) ni `created_at`. Casi siempre el día de creación; más adelante puede ser otro. Desde aquí se cuentan `run_days` y el disparo de `single_use`. |
| `single_use` | Default `false`. Suena **una sola vez** a `time_local` en `start_date`. No puede ir con `every_day`, lun–dom ni `run_days` (check SQL). Tras sonar, `is_active` = false. |
| `every_day` | Default `true`. Si está activo, **manda**: lun–dom no cuentan. Incompatible con `single_use`. |
| `monday` … `sunday` | Días concretos. Al menos uno si no es `single_use` ni `every_day`. |
| `run_days` | Hasta cuántos **días de alarma** desde `start_date` (cada día marcado cuenta 1; una vez por día a `time_local`). Solo lunes y `7` = el 7.º lunes es el último. Lun+mar y `10` = termina el martes de la 5.ª semana. `null` si `single_use`. |
| `is_active` | Default `true`. Con días concretos, al cumplirse `run_days` pasa a `false`. Con `single_use`, tras la única vez pasa a `false`. Si `every_day`, sigue activa hasta desactivarla a mano. Distinto de `deleted_at`. |

Prioridad: `single_use` → `every_day` → días + `run_days`. El apagado automático es lógica de app/job, no un trigger SQL. El teléfono hijo solo programa alarmas si `is_active` y `deleted_at` es null.

El alta visual **aún no** pide periodicidad ni `is_active`.

## Qué no hacer todavía

- No persistir desde la app (local, nube ni alarmas).
- No llenar `Notificator` ni añadir RLS/RPCs salvo pedido explícito.
- No añadir al alta visual los días / `run_days`, ni UI de confirmar/ignorar, alarmas ni listado real hasta que se pida.

## Siguiente paso (cuando se pida)

RLS/RPC de recordatorios y enganchar **Guardar notificación** a `Notificator`. Las pantallas deben hablar con esa fachada, no con `BackendClient`.
