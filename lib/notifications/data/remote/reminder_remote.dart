import 'package:noty/core/network/backend_client.dart';
import 'package:noty/notifications/models/reminder.dart';

/// Tubo remoto de recordatorios. Solo lo usa [Notificator].
class ReminderRemote {
  ReminderRemote({BackendClient? client})
    : _client = client ?? BackendClient.instance;

  final BackendClient _client;

  Future<List<Reminder>> fetchReminders() async {
    final rows = await _client.fetchReminders();
    return [
      for (final row in rows)
        if (row['id'] is String) Reminder.fromMap(row),
    ];
  }

  Future<void> respondToReminder({
    required String reminderId,
    required DateTime dueAt,
    required String response,
  }) {
    return _client.respondToReminder(
      reminderId: reminderId,
      dueAt: dueAt,
      response: response,
    );
  }

  RealtimeChannelHandle subscribeToReminderChanges(void Function() onChange) {
    final handle = _client.subscribeReminderChanges(onChange);
    return RealtimeChannelHandle(handle.dispose);
  }
}

/// Manejo opaco de la suscripción Realtime.
class RealtimeChannelHandle {
  RealtimeChannelHandle(this._dispose);

  final Future<void> Function() _dispose;

  Future<void> dispose() => _dispose();
}
