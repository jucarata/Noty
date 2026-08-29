import 'dart:convert';

import 'package:noty/notifications/models/reminder.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Respuesta pendiente de subir a la nube.
class PendingReminderResponse {
  const PendingReminderResponse({
    required this.reminderId,
    required this.dueAt,
    required this.response,
    required this.respondedAt,
  });

  final String reminderId;
  final DateTime dueAt;
  final String response;
  final DateTime respondedAt;

  Map<String, dynamic> toMap() {
    return {
      'reminder_id': reminderId,
      'due_at': dueAt.toUtc().toIso8601String(),
      'response': response,
      'responded_at': respondedAt.toUtc().toIso8601String(),
    };
  }

  factory PendingReminderResponse.fromMap(Map<String, dynamic> map) {
    return PendingReminderResponse(
      reminderId: map['reminder_id'] as String,
      dueAt: DateTime.parse(map['due_at'] as String).toUtc(),
      response: map['response'] as String,
      respondedAt: DateTime.parse(map['responded_at'] as String).toUtc(),
    );
  }
}

/// Caché local de recordatorios y cola de respuestas.
class ReminderCache {
  ReminderCache({SharedPreferences? preferences})
    : _preferencesFuture = preferences != null
          ? Future.value(preferences)
          : SharedPreferences.getInstance();

  static const _remindersKey = 'noty.reminders.cache';
  static const _pendingResponsesKey = 'noty.reminders.pending_responses';
  static const _lastSyncKey = 'noty.reminders.last_sync';

  final Future<SharedPreferences> _preferencesFuture;

  Future<List<Reminder>> readReminders() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_remindersKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }

    return [
      for (final row in decoded)
        if (row is Map) Reminder.fromMap(Map<String, dynamic>.from(row)),
    ];
  }

  Future<void> writeReminders(List<Reminder> reminders) async {
    final prefs = await _preferencesFuture;
    final payload = jsonEncode([for (final reminder in reminders) reminder.toMap()]);
    await prefs.setString(_remindersKey, payload);
    await prefs.setString(_lastSyncKey, DateTime.now().toUtc().toIso8601String());
  }

  Future<DateTime?> lastSyncAt() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_lastSyncKey);
    if (raw == null) {
      return null;
    }
    return DateTime.tryParse(raw)?.toUtc();
  }

  Future<List<PendingReminderResponse>> readPendingResponses() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_pendingResponsesKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }

    return [
      for (final row in decoded)
        if (row is Map)
          PendingReminderResponse.fromMap(Map<String, dynamic>.from(row)),
    ];
  }

  Future<void> writePendingResponses(
    List<PendingReminderResponse> responses,
  ) async {
    final prefs = await _preferencesFuture;
    final payload = jsonEncode([for (final row in responses) row.toMap()]);
    await prefs.setString(_pendingResponsesKey, payload);
  }

  Future<void> enqueueResponse(PendingReminderResponse response) async {
    final pending = await readPendingResponses();
    final filtered = [
      for (final row in pending)
        if (!(row.reminderId == response.reminderId &&
            row.dueAt.toUtc() == response.dueAt.toUtc()))
          row,
      response,
    ];
    await writePendingResponses(filtered);
  }

  Future<void> clear() async {
    final prefs = await _preferencesFuture;
    await prefs.remove(_remindersKey);
    await prefs.remove(_pendingResponsesKey);
    await prefs.remove(_lastSyncKey);
  }
}
