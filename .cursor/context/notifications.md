# Módulo notifications — estado actual

Fuente de arquitectura: `architecture.md`. Este archivo describe **qué ya está en la UI**, cómo funcionan las alarmas y qué queda pendiente. No reimplementar el flujo visual.

## Qué hay

El tab **Notificaciones** está en el footer de `MainShell`, entre Inicio y Familia.

| Pieza | Dónde |
|---|---|
| Lista | `lib/notifications/screens/notifications_screen.dart` — tarjetas desde **caché local** |
| Alta en 2 pasos | `lib/notifications/screens/add_notification_screen.dart` |
| Pantalla de alarma | `lib/notifications/screens/alarm_ring_screen.dart` |
| Tile de device con check | `lib/notifications/widgets/notification_device_tile.dart` |
| Tarjeta de lista | `lib/notifications/widgets/reminder_card.dart` |
| Fachada | `lib/notifications/services/notificator.dart` |
| Caché local | `lib/notifications/data/local/reminder_cache.dart` |
| Registro del device | `lib/notifications/data/local/device_registry.dart` |
| Tubo remoto | `lib/notifications/data/remote/reminder_remote.dart` |
| Sync + Realtime | `lib/notifications/services/reminder_sync.dart` |
| Alarmas del SO | `lib/notifications/services/alarm_scheduler.dart` |
| Sonido en pantalla | `lib/notifications/services/alarm_sound_player.dart` |
| Modelos | `new_reminder.dart`, `reminder.dart` |

El `+` abre `AddNotificationScreen` para crear. Tocar una tarjeta abre la misma pantalla con los campos llenos para editar. **Guardar notificación** llama a `Notificator.createReminder` o `updateReminder`. **Eliminar** pide confirmación y llama a `deleteReminder` (soft delete + quita todos los `reminder_devices`).

## Flujo visual (no tocarlo salvo pedido)

### Paso 1 — ¿Qué hay que recordar?

- Nombre *, descripción, hora *, fecha de inicio * (hoy), zona * (`America/Bogota`).
- Frecuencia excluyente: **Solo una vez** (default) / **Todos los días** / **Elegir los días**.
- Si se repite: **Días de ejecución** * o **Nunca termina**.
- Continuar según esas reglas.

### Paso 2 — ¿En qué teléfonos sonará?

- Devices familiares (`CareService.listFamilyMembers`).
- Guardar con ≥1 device → `reminders` + `reminder_devices`.
- Éxito: “¡Listo! Has creado este recordatorio.” / al editar: “¡Listo! Guardamos los cambios.”
- En edición: botón **Eliminar** (paso 1 y 2). Confirma y desvincula todos los teléfonos.

### Pantalla de alarma (cuando suena)

- Fondo azul marca, **nombre** del recordatorio, **descripción** (si hay).
- Botón **check verde** grande: confirmar → `confirmed` en `reminder_responses`.
- Sonido de alarma del **sistema** en loop (Android) mientras la pantalla está abierta.
- Si no confirma en **90 segundos** → se marca `ignored`, se apaga el sonido y se cierra.
- Tras confirmar o timeout, se reprograma la **siguiente** ocurrencia (si aplica).

## Datos (nube)

Tablas: `reminders` + `reminder_devices` + `reminder_responses`.

- Crear: RPC `create_reminder` (`20260827020000_reminders.sql`).
- Editar / eliminar: RPCs `update_reminder` y `delete_reminder` (`20260827040000_reminders_update_delete.sql`). Solo quien lo creó (`created_by`). `delete_reminder` pone `deleted_at`, `is_active = false` y borra `reminder_devices`.
- Responder: RPC `respond_to_reminder` (`20260827050000_reminder_responses_insert.sql`). `confirmed` o `ignored` por `(reminder_id, device_id, due_at)`.
- Leer: políticas RLS. Sin insert directo en `reminders` desde el cliente.
- `run_days` null = `single_use` o “nunca termina”.

Prioridad de cómputo local: `single_use` → `every_day` → días + `run_days` (ver `Reminder.nextAt`).

## Caché local y sync (offline-first)

Cada teléfono guarda **su propia caché** (`ReminderCache` en `SharedPreferences`). La UI **solo lee local**. La red sincroniza.

```
Padre guarda en nube
    → Realtime / reconexión / abrir app
    → hijo: sync → caché → rescheduleAll (alarmas del SO)
```

### Cuándo sincroniza el teléfono del acompañado (abuelo)

| Disparador | Qué pasa |
|---|---|
| Supabase Realtime (`reminders`, `reminder_devices`) | Sync con debounce ~400 ms |
| Vuelve internet (`connectivity_plus`) | Sync |
| Abre la app / vuelve al foreground (`MainShell`) | `Notificator.refresh()` |
| Primera vez tras login (`MainShell` → `Notificator.initialize`) | Sync + suscripción Realtime |

**No hay polling.** Un fetch al reconectar o al evento; no un loop.

### Si el padre edita o elimina un reminder

**Sí llega al abuelo**, cuando su teléfono puede sincronizar:

1. El cambio queda en Postgres.
2. Realtime avisa (si la app está viva con internet) **o** sync al reconectar / abrir app.
3. Se actualiza la caché local.
4. `rescheduleAll` **cancela** alarmas viejas y **programa** las nuevas.

| Situación del abuelo | ¿Se entera al toque? |
|---|---|
| App abierta o en segundo plano con internet | Sí |
| App cerrada, recupera internet | Sí (al reconectar) |
| Abre la app | Sí |
| App cerrada, sin internet, padre ya editó/borró | **No** hasta tener red y sincronizar |

**Matiz:** si el padre borró pero el abuelo lleva tiempo sin sync, la alarma **ya programada en el SO** podría seguir hasta el próximo sync. Al sincronizar se cancela.

**Pendiente:** push (FCM/APNs) para despertar sync con la app totalmente cerrada y sin depender de que el abuelo abra Noty.

## Alarmas del sistema operativo

Las alarmas se programan **desde la caché local**, no desde la red en el momento del disparo. Servicio: `AlarmScheduler` (`flutter_local_notifications` + `timezone`).

- Android: alarma exacta, `fullScreenIntent`, sonido `content://settings/system/alarm_alert`, canal tipo alarma.
- Permisos Android pedidos: notificaciones, alarma exacta, pantalla completa (Android 14+).
- Boot receiver del plugin (`ScheduledNotificationBootReceiver`) en `AndroidManifest.xml`.

### Reinicio o batería agotada

| Evento | Comportamiento actual |
|---|---|
| **Reinicio** (Android) | Las alarmas **futuras** ya programadas se remontan solas vía boot receiver del plugin. **No hace falta** abrir la app. |
| **Batería muerta a la hora de la alarma** | Esa ocurrencia **no suena** (comportamiento estándar de alarma). |
| **Enciende tras apagado** | Alarmas futuras que el plugin tenía guardadas deberían seguir. Cambios del padre hechos offline **no** se aplican hasta sync. |
| **Padre editó/borró mientras el abuelo estaba apagado** | Hace falta **sync** (abrir app o recuperar red). |

**Pendiente:** boot handler propio que relea la **caché local** y reprograme todo (hoy el boot receiver solo restaura lo que el plugin ya tenía; no re-lee Drift/SharedPreferences).

## iOS — estado y pendientes (retomar en futuro)

**Plataforma objetivo del MVP para la persona acompañada: Android.** iOS hoy es “mejor esfuerzo”, no paridad.

### Qué hay hoy en iOS

| Característica | Estado |
|---|---|
| Notificación local programada (`zonedSchedule`) | Implementado |
| Nivel `timeSensitive` | Implementado |
| Pantalla completa con teléfono bloqueado | **No** (no existe equivalente a `fullScreenIntent`) |
| Sonido de alarma del sistema en loop | **No** (`AlarmSoundPlayer` solo en Android; en iOS el sonido lo lleva la notificación) |
| Duración del sonido | ~30 s máx. (límite del sistema para notificaciones) |
| Botón check a pantalla completa sin tocar notificación | **No** — hay que abrir la app desde la notificación |
| Permisos de notificación pedidos en código | **No** — solo se piden permisos Android en `AlarmScheduler` |
| Sync con app muerta (push) | **No** (igual que Android) |

### Pendientes iOS (checklist para retomar)

1. **Pedir permisos** explícitos (`requestPermissions` en `DarwinFlutterLocalNotificationsPlugin` + copy en onboarding).
2. **Definir UX aceptable:** notificación fuerte + al tocar → `AlarmRingScreen` con check (sin prometer pantalla sobre lock screen).
3. **Sonido:** evaluar sonido custom empaquetado o Critical Alerts (entitlement de Apple, revisión manual, no garantizado).
4. **Background:** no confiar en silent push para reprogramar; mantener sync al abrir app como red de seguridad.
5. **Pruebas en dispositivo real** con Focus / No molestar / pantalla bloqueada.
6. **Documentar en App Store** si se usan notificaciones sensibles al tiempo.

### Referencia rápida Android vs iOS

| | Android (MVP) | iOS (hoy) |
|---|---|---|
| Alarma con app cerrada | Sí | Notificación, no alarma tipo reloj |
| Pantalla emergente bloqueada | Sí | No |
| Loop de sonido hasta confirmar | Sí (~90 s en UI) | No |
| Plataforma recomendada para abuelo | **Sí** | Solo si se aceptan limitaciones |

## API de `Notificator` (fachada)

- `initialize(navigatorKey)` — timezone, alarmas, sync, Realtime.
- `refresh()` — sync manual.
- `createReminder` / `updateReminder` / `deleteReminder` — nube + refresh.
- `listReminders()` — **solo caché local**.
- `confirmOccurrence` / `ignoreOccurrence` — respuesta local + cola + reprogramar.
- `localChanges` — stream para que la lista se actualice sola.

Pantallas y widgets **no** importan `BackendClient`, Supabase ni plugins de alarmas.

## Qué no hacer todavía

- No rehacer el flujo visual de alta en 2 pasos salvo pedido explícito.
- No meter lógica de alarmas en `home` ni en widgets de lista.
- No prometer paridad iOS/Android en copy de producto hasta cerrar pendientes iOS.

## Siguiente paso (cuando se pida)

- **FCM** (y APNs en iOS): push al device hijo cuando el padre crea/edita/borra → sync sin abrir app.
- **Boot handler propio:** releer caché y `rescheduleAll` tras `BOOT_COMPLETED`.
- **Retomar iOS:** ver checklist arriba.
- Apagado automático de `is_active` en servidor al cumplir `run_days` / `single_use` (hoy parcialmente local).
