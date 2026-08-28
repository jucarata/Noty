import 'package:noty/core/network/backend_client.dart';
import 'package:noty/notifications/models/new_reminder.dart';
import 'package:noty/notifications/models/reminder.dart';

/// Fachada de la feature notifications.
///
/// Las pantallas hablan solo con esta clase. Hoy persiste en la nube;
/// la caché local y las alarmas del SO se enganchan después.
class Notificator {
  Notificator({BackendClient? client})
    : _client = client ?? BackendClient.instance;

  final BackendClient _client;

  /// Crea el recordatorio y lo asigna a los teléfonos elegidos.
  Future<void> createReminder(NewReminder reminder) {
    return _upsert(reminder);
  }

  /// Guarda cambios de un recordatorio existente y sus teléfonos.
  Future<void> updateReminder(String id, NewReminder reminder) {
    return _upsert(reminder, id: id);
  }

  /// Elimina el recordatorio (soft delete) y lo desvincula de todos los devices.
  Future<void> deleteReminder(String id) async {
    try {
      await _client.deleteReminder(id: id);
    } on BackendAuthException catch (error) {
      throw NotificatorFailure(_copyForDelete(error));
    } catch (_) {
      throw const NotificatorFailure(
        'No pudimos eliminar el recordatorio. Intentémoslo nuevamente.',
      );
    }
  }

  Future<void> _upsert(NewReminder reminder, {String? id}) async {
    try {
      final timeLocal = _formatTime(reminder.hour, reminder.minute);
      final startDate = _formatDate(reminder.startDate);
      if (id == null) {
        await _client.createReminder(
          name: reminder.name,
          description: reminder.description,
          timeLocal: timeLocal,
          timezone: reminder.timezone,
          startDate: startDate,
          singleUse: reminder.singleUse,
          everyDay: reminder.everyDay,
          monday: reminder.monday,
          tuesday: reminder.tuesday,
          wednesday: reminder.wednesday,
          thursday: reminder.thursday,
          friday: reminder.friday,
          saturday: reminder.saturday,
          sunday: reminder.sunday,
          runDays: reminder.runDays,
          deviceIds: reminder.deviceIds,
        );
      } else {
        await _client.updateReminder(
          id: id,
          name: reminder.name,
          description: reminder.description,
          timeLocal: timeLocal,
          timezone: reminder.timezone,
          startDate: startDate,
          singleUse: reminder.singleUse,
          everyDay: reminder.everyDay,
          monday: reminder.monday,
          tuesday: reminder.tuesday,
          wednesday: reminder.wednesday,
          thursday: reminder.thursday,
          friday: reminder.friday,
          saturday: reminder.saturday,
          sunday: reminder.sunday,
          runDays: reminder.runDays,
          deviceIds: reminder.deviceIds,
        );
      }
    } on BackendAuthException catch (error) {
      throw NotificatorFailure(_copyFor(error));
    } catch (_) {
      throw const NotificatorFailure(
        'No pudimos guardar el recordatorio. Intentémoslo nuevamente.',
      );
    }
  }

  /// Recordatorios para pintar la lista. Orden: el que suena más pronto.
  Future<List<Reminder>> listReminders() async {
    try {
      final rows = await _client.fetchReminders();
      final reminders = [
        for (final row in rows)
          if (row['id'] is String) Reminder.fromMap(row),
      ]..sort(_byNextThenCreated);
      return reminders;
    } on BackendAuthException catch (error) {
      throw NotificatorFailure(_copyForList(error));
    } catch (_) {
      throw const NotificatorFailure(
        'No pudimos cargar tus recordatorios. Intentémoslo de nuevo.',
      );
    }
  }

  int _byNextThenCreated(Reminder a, Reminder b) {
    final nextA = a.nextAt;
    final nextB = b.nextAt;
    if (nextA == null && nextB == null) {
      return b.createdAt.compareTo(a.createdAt);
    }
    if (nextA == null) {
      return 1;
    }
    if (nextB == null) {
      return -1;
    }
    final byNext = nextA.compareTo(nextB);
    if (byNext != 0) {
      return byNext;
    }
    return b.createdAt.compareTo(a.createdAt);
  }

  String _formatTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _copyFor(BackendAuthException error) {
    if (error.code == 'missing_session') {
      return 'Para guardar un recordatorio, entra a la app.';
    }
    if (error.code == 'anonymous_not_allowed') {
      return 'Para guardar un recordatorio, entra o crea una cuenta.';
    }

    final message = error.message.trim();
    if (message.contains('Debes entrar') ||
        message.contains('Inicia sesión') ||
        message.contains('Ponle un nombre') ||
        message.contains('Elige la hora') ||
        message.contains('Elige el día') ||
        message.contains('Elige al menos') ||
        message.contains('no está en tu familia') ||
        message.contains('días de ejecución') ||
        message.contains('No encontramos este recordatorio') ||
        message.contains('gestionar recordatorios')) {
      return message;
    }

    return 'No pudimos guardar el recordatorio. Intentémoslo nuevamente.';
  }

  String _copyForList(BackendAuthException error) {
    if (error.code == 'missing_session') {
      return 'Para ver tus recordatorios, entra a la app.';
    }
    return 'No pudimos cargar tus recordatorios. Intentémoslo de nuevo.';
  }

  String _copyForDelete(BackendAuthException error) {
    if (error.code == 'missing_session' ||
        error.code == 'anonymous_not_allowed') {
      return 'Para eliminar un recordatorio, entra o crea una cuenta.';
    }
    final message = error.message.trim();
    if (message.contains('No encontramos') ||
        message.contains('Inicia sesión') ||
        message.contains('Debes entrar')) {
      return message;
    }
    return 'No pudimos eliminar el recordatorio. Intentémoslo nuevamente.';
  }
}
