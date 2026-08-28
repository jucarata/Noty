# Módulo notifications — estado actual

Fuente de arquitectura: `architecture.md`. Este archivo describe **qué ya está en la UI** y qué falta. No reimplementar el flujo visual.

## Qué hay

El tab **Notificaciones** está en el footer de `MainShell`, entre Inicio y Familia.

| Pieza | Dónde |
|---|---|
| Lista | `lib/notifications/screens/notifications_screen.dart` — tarjetas desde la nube |
| Alta en 2 pasos | `lib/notifications/screens/add_notification_screen.dart` |
| Tile de device con check | `lib/notifications/widgets/notification_device_tile.dart` |
| Tarjeta de lista | `lib/notifications/widgets/reminder_card.dart` |
| Fachada | `lib/notifications/services/notificator.dart` — `createReminder`, `listReminders` |
| Modelos | `new_reminder.dart`, `reminder.dart` |

El `+` abre `AddNotificationScreen`. **Guardar notificación** llama a `Notificator` → `BackendClient.createReminder` → RPC `create_reminder`.

## Flujo visual (no tocarlo salvo pedido)

### Paso 1 — ¿Qué hay que recordar?

- Nombre *, descripción, hora *, fecha de inicio * (hoy), zona * (`America/Bogota`).
- Frecuencia excluyente: **Solo una vez** (default) / **Todos los días** / **Elegir los días**.
- Si se repite: **Días de ejecución** * o **Nunca termina**.
- Continuar según esas reglas.

### Paso 2 — ¿En qué teléfonos sonará?

- Devices familiares (`CareService.listFamilyMembers`).
- Guardar con ≥1 device → `reminders` + `reminder_devices`.
- Éxito: “¡Listo! Has creado este recordatorio.”

## Datos (nube)

Tablas: `reminders` + `reminder_devices` + `reminder_responses`.

- Crear: RPC `create_reminder` (`supabase/migrations/20260827020000_reminders.sql`).
- Leer: políticas RLS. Sin insert directo desde el cliente.
- `run_days` null = `single_use` o “nunca termina”.

Prioridad: `single_use` → `every_day` → días + `run_days`. Alarmas y apagado automático de `is_active` aún no.

## Qué no hacer todavía

- No caché local, ni alarmas del SO, ni confirmar/ignorar.

## Siguiente paso (cuando se pida)

Caché local y programar alarmas desde ella. Confirmar / ignorar → `reminder_responses`.
