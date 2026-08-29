import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sesión remota. Lo usa la fachada de auth, no las pantallas.
class BackendAuthSession {
  const BackendAuthSession({
    required this.userId,
    required this.isAnonymous,
    this.email,
  });

  final String userId;
  final bool isAnonymous;
  final String? email;
}

/// Error del tubo de auth. [AuthService] lo traduce a copy de producto.
class BackendAuthException implements Exception {
  const BackendAuthException(this.message, {this.code});

  final String message;
  final String? code;
}

/// Único tubo de la app hacia el servidor.
///
/// Hoy encapsula Supabase; mañana una API propia. Las pantallas no usan
/// esta clase: solo `data/remote` o los services de cada feature.
class BackendClient {
  BackendClient._();

  static final BackendClient instance = BackendClient._();

  static bool _initialized = false;
  static Stream<BackendAuthSession?>? _authChanges;

  static const oauthRedirectTo = 'com.noty.noty://login-callback';

  /// Arranca el tubo. Debe llamarse una vez desde [main], antes de [runApp].
  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const url = String.fromEnvironment('SUPABASE_URL');
    const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

    if (url.isEmpty || publishableKey.isEmpty) {
      throw StateError(
        'Faltan SUPABASE_URL o SUPABASE_PUBLISHABLE_KEY. '
        'Compila con --dart-define-from-file=.env',
      );
    }

    await Supabase.initialize(
      url: url,
      publishableKey: publishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        detectSessionInUri: true,
        persistSession: true,
      ),
    );
    _initialized = true;
  }

  GoTrueClient get _auth => _supabase.auth;

  SupabaseClient get _supabase {
    if (!_initialized) {
      throw StateError(
        'BackendClient.initialize() debe llamarse antes de usar el tubo.',
      );
    }
    return Supabase.instance.client;
  }

  BackendAuthSession? get currentSession => _mapUser(_auth.currentUser);

  Stream<BackendAuthSession?> get authChanges {
    return _authChanges ??= _auth.onAuthStateChange
        .map((state) => _mapUser(state.session?.user))
        .asBroadcastStream();
  }

  Future<BackendAuthSession> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email,
        password: password,
      );
      return _requireSession(response.user);
    } on AuthException catch (error) {
      throw _wrap(error);
    }
  }

  Future<BackendAuthSession> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final existing = currentSession;
    if (existing != null && existing.isAnonymous) {
      return _convertAnonymousUser(email: email, password: password);
    }

    try {
      final response = await _auth.signUp(email: email, password: password);
      if (response.session != null && response.user != null) {
        return _requireSession(response.user);
      }

      final identities = response.user?.identities ?? const [];
      if (identities.isEmpty && response.user != null) {
        throw const BackendAuthException(
          'Ya existe una cuenta con este correo. Probemos a entrar.',
          code: 'email_exists',
        );
      }

      return _requireSession(response.user);
    } on BackendAuthException {
      rethrow;
    } on AuthException catch (error) {
      throw _wrap(error);
    }
  }

  Future<void> signInWithGoogle() => _signInWithOAuth(OAuthProvider.google);

  Future<void> signInWithMicrosoft() => _signInWithOAuth(OAuthProvider.azure);

  Future<BackendAuthSession> signInAnonymously() async {
    final existing = currentSession;
    if (existing != null) {
      return existing;
    }

    try {
      final response = await _auth.signInAnonymously();
      return _requireSession(response.user);
    } on AuthException catch (error) {
      throw _wrap(error);
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on AuthException catch (error) {
      throw _wrap(error);
    }
  }

  /// TEMPORAL de desarrollo: borra la cuenta actual en Auth y cierra sesión local.
  Future<void> purgeCurrentUser() async {
    try {
      await _supabase.rpc('purge_own_account');
      await _auth.signOut(scope: SignOutScope.local);
    } on PostgrestException catch (error) {
      throw BackendAuthException(error.message, code: error.code);
    } on AuthException catch (error) {
      throw _wrap(error);
    }
  }

  /// Registra o actualiza este install. El QR lleva [installId].
  ///
  /// Devuelve `devices.id`. Si el install pertenece a otra cuenta, lanza
  /// [BackendAuthException] con código `device_taken`.
  Future<String> upsertOwnDevice({
    required String installId,
    required String platform,
    required String deviceKind,
    String? brand,
    String? model,
    String? osVersion,
    String? customName,
  }) async {
    final ownerId = currentSession?.userId;
    if (ownerId == null) {
      throw const BackendAuthException(
        'Debes entrar a la app para compartir este dispositivo.',
        code: 'missing_session',
      );
    }

    try {
      final result = await _supabase.rpc(
        'register_own_device',
        params: {
          'p_install_id': installId,
          'p_platform': platform,
          'p_device_kind': deviceKind,
          'p_brand': brand,
          'p_model': model,
          'p_os_version': osVersion,
          'p_custom_name': customName,
        },
      );
      final id = _asNonEmptyString(result);
      if (id == null) {
        throw const BackendAuthException(
          'No pudimos registrar este teléfono.',
          code: 'device_register_failed',
        );
      }
      return id;
    } on BackendAuthException {
      rethrow;
    } on PostgrestException catch (error) {
      debugPrint(
        'Noty register_own_device: code=${error.code} message=${error.message}',
      );
      if (_isMissingRpc(error, 'register_own_device')) {
        return _upsertOwnDeviceDirect(
          installId: installId,
          ownerId: ownerId,
          platform: platform,
          deviceKind: deviceKind,
          brand: brand,
          model: model,
          osVersion: osVersion,
          customName: customName,
        );
      }
      throw _wrapDeviceRegister(error);
    }
  }

  Future<String> _upsertOwnDeviceDirect({
    required String installId,
    required String ownerId,
    required String platform,
    required String deviceKind,
    String? brand,
    String? model,
    String? osVersion,
    String? customName,
  }) async {
    try {
      final row = await _supabase
          .from('devices')
          .upsert({
            'install_id': installId,
            'owner_id': ownerId,
            'platform': platform,
            'device_kind': deviceKind,
            'brand': ?brand,
            'model': ?model,
            'os_version': ?osVersion,
            'custom_name': ?customName,
            'last_seen_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'install_id', defaultToNull: false)
          .select('id')
          .maybeSingle();
      final id = _asNonEmptyString(row?['id']);
      if (id == null) {
        throw const BackendAuthException(
          'Este dispositivo ya está vinculado a otra cuenta.',
          code: 'device_taken',
        );
      }
      return id;
    } on BackendAuthException {
      rethrow;
    } on PostgrestException catch (error) {
      debugPrint(
        'Noty devices upsert: code=${error.code} message=${error.message}',
      );
      throw _wrapDeviceRegister(error);
    }
  }

  BackendAuthException _wrapDeviceRegister(PostgrestException error) {
    final message = error.message;
    if (error.code == '23505' ||
        message.contains('otra cuenta') ||
        message.contains('duplicate key')) {
      return BackendAuthException(message, code: 'device_taken');
    }
    return BackendAuthException(message, code: error.code);
  }

  bool _isMissingRpc(PostgrestException error, String name) {
    return error.code == 'PGRST202' || error.message.contains(name);
  }

  String? _asNonEmptyString(Object? value) {
    if (value is List && value.isNotEmpty) {
      return _asNonEmptyString(value.first);
    }
    if (value == null) {
      return null;
    }
    final text = value is String ? value.trim() : value.toString().trim();
    return text.isEmpty || text == 'null' ? null : text;
  }

  /// Vincula el device del QR a la familia del usuario actual (host).
  ///
  /// Si aún no hay familia, el RPC crea “Mi familia”. El device queda como
  /// acompañado: el host y el resto de miembros del grupo quedan relacionados.
  /// [customName] es el nombre con el que quien cuida reconocerá ese teléfono.
  Future<void> linkDeviceToFamily({
    required String installId,
    String? familyId,
    String? customName,
  }) async {
    final session = currentSession;
    if (session == null) {
      throw const BackendAuthException(
        'Debes entrar a la app para vincular un dispositivo.',
        code: 'missing_session',
      );
    }
    if (session.isAnonymous) {
      throw const BackendAuthException(
        'Inicia sesión para vincular un dispositivo.',
        code: 'anonymous_not_allowed',
      );
    }

    final named = customName?.trim();
    try {
      await _supabase.rpc(
        'link_device_to_family',
        params: {
          'p_install_id': installId,
          'p_family_id': ?familyId,
          'p_custom_name': ?named,
        },
      );
    } on PostgrestException catch (error) {
      throw BackendAuthException(error.message, code: error.code);
    }
  }

  /// Saca el device de la familia de quien llama y los recordatorios que
  /// ese grupo le había asignado. El teléfono en sí no se borra.
  Future<void> unlinkDeviceFromFamily({required String deviceId}) async {
    final session = currentSession;
    if (session == null) {
      throw const BackendAuthException(
        'Debes entrar a la app para desvincular un dispositivo.',
        code: 'missing_session',
      );
    }
    if (session.isAnonymous) {
      throw const BackendAuthException(
        'Inicia sesión para desvincular un dispositivo.',
        code: 'anonymous_not_allowed',
      );
    }

    try {
      await _supabase.rpc(
        'unlink_device_from_family',
        params: {'p_device_id': deviceId},
      );
    } on PostgrestException catch (error) {
      throw BackendAuthException(error.message, code: error.code);
    }
  }

  /// Teléfonos de familiares acompañados en los grupos donde quien llama cuida.
  Future<List<Map<String, dynamic>>> fetchFamilyMembers() async {
    final session = currentSession;
    if (session == null) {
      throw const BackendAuthException(
        'Debes entrar a la app para ver tu familia.',
        code: 'missing_session',
      );
    }
    if (session.isAnonymous) {
      throw const BackendAuthException(
        'Inicia sesión para ver tu familia.',
        code: 'anonymous_not_allowed',
      );
    }

    try {
      final memberships = await _supabase
          .from('family_members')
          .select('family_id')
          .inFilter('role', const ['host', 'caregiver']);

      final familyIds = <String>{
        for (final row in memberships)
          if (row['family_id'] is String) row['family_id'] as String,
      };
      if (familyIds.isEmpty) {
        return const [];
      }

      final rows = await _supabase
          .from('family_members')
          .select('devices(id, custom_name, brand, model, last_seen_at)')
          .inFilter('family_id', familyIds.toList())
          .eq('role', 'accompanied');

      final devices = <String, Map<String, dynamic>>{};
      for (final row in rows) {
        final device = _asDeviceMap(row['devices']);
        final id = device?['id'];
        if (device == null || id is! String || id.isEmpty) {
          continue;
        }
        devices[id] = device;
      }

      final list = devices.values.toList()
        ..sort((a, b) {
          final aSeen = a['last_seen_at'] as String? ?? '';
          final bSeen = b['last_seen_at'] as String? ?? '';
          return bSeen.compareTo(aSeen);
        });
      return list;
    } on PostgrestException catch (error) {
      throw BackendAuthException(error.message, code: error.code);
    }
  }

  /// Crea un recordatorio y lo une a los [deviceIds] (devices.id).
  Future<void> createReminder({
    required String name,
    required String timeLocal,
    required String timezone,
    required String startDate,
    required List<String> deviceIds,
    String? description,
    bool singleUse = false,
    bool everyDay = false,
    bool monday = false,
    bool tuesday = false,
    bool wednesday = false,
    bool thursday = false,
    bool friday = false,
    bool saturday = false,
    bool sunday = false,
    int? runDays,
  }) async {
    _requireAccountForReminders();

    try {
      await _supabase.rpc(
        'create_reminder',
        params: _reminderParams(
          name: name,
          description: description,
          timeLocal: timeLocal,
          timezone: timezone,
          startDate: startDate,
          singleUse: singleUse,
          everyDay: everyDay,
          monday: monday,
          tuesday: tuesday,
          wednesday: wednesday,
          thursday: thursday,
          friday: friday,
          saturday: saturday,
          sunday: sunday,
          runDays: runDays,
          deviceIds: deviceIds,
        ),
      );
    } on PostgrestException catch (error) {
      throw BackendAuthException(error.message, code: error.code);
    }
  }

  /// Actualiza un recordatorio propio y reemplaza sus devices.
  Future<void> updateReminder({
    required String id,
    required String name,
    required String timeLocal,
    required String timezone,
    required String startDate,
    required List<String> deviceIds,
    String? description,
    bool singleUse = false,
    bool everyDay = false,
    bool monday = false,
    bool tuesday = false,
    bool wednesday = false,
    bool thursday = false,
    bool friday = false,
    bool saturday = false,
    bool sunday = false,
    int? runDays,
  }) async {
    _requireAccountForReminders();

    try {
      await _supabase.rpc(
        'update_reminder',
        params: {
          'p_id': id,
          ..._reminderParams(
            name: name,
            description: description,
            timeLocal: timeLocal,
            timezone: timezone,
            startDate: startDate,
            singleUse: singleUse,
            everyDay: everyDay,
            monday: monday,
            tuesday: tuesday,
            wednesday: wednesday,
            thursday: thursday,
            friday: friday,
            saturday: saturday,
            sunday: sunday,
            runDays: runDays,
            deviceIds: deviceIds,
          ),
        },
      );
    } on PostgrestException catch (error) {
      throw BackendAuthException(error.message, code: error.code);
    }
  }

  /// Soft delete: deja de existir para la app y se desvincula de los devices.
  Future<void> deleteReminder({required String id}) async {
    _requireAccountForReminders();

    try {
      await _supabase.rpc('delete_reminder', params: {'p_id': id});
    } on PostgrestException catch (error) {
      throw BackendAuthException(error.message, code: error.code);
    }
  }

  void _requireAccountForReminders() {
    final session = currentSession;
    if (session == null) {
      throw const BackendAuthException(
        'Debes entrar a la app para guardar un recordatorio.',
        code: 'missing_session',
      );
    }
    if (session.isAnonymous) {
      throw const BackendAuthException(
        'Inicia sesión para guardar un recordatorio.',
        code: 'anonymous_not_allowed',
      );
    }
  }

  Map<String, dynamic> _reminderParams({
    required String name,
    required String timeLocal,
    required String timezone,
    required String startDate,
    required List<String> deviceIds,
    String? description,
    required bool singleUse,
    required bool everyDay,
    required bool monday,
    required bool tuesday,
    required bool wednesday,
    required bool thursday,
    required bool friday,
    required bool saturday,
    required bool sunday,
    int? runDays,
  }) {
    return {
      'p_name': name,
      'p_description': description,
      'p_time_local': timeLocal,
      'p_timezone': timezone,
      'p_start_date': startDate,
      'p_single_use': singleUse,
      'p_every_day': everyDay,
      'p_monday': monday,
      'p_tuesday': tuesday,
      'p_wednesday': wednesday,
      'p_thursday': thursday,
      'p_friday': friday,
      'p_saturday': saturday,
      'p_sunday': sunday,
      'p_run_days': runDays,
      'p_device_ids': deviceIds,
    };
  }

  /// Resuelve devices.id a partir del install_id local.
  Future<String?> fetchDeviceIdByInstallId({required String installId}) async {
    if (currentSession == null) {
      return null;
    }

    try {
      final row = await _supabase
          .from('devices')
          .select('id')
          .eq('install_id', installId)
          .maybeSingle();
      final id = row?['id'];
      return id is String ? id : null;
    } on PostgrestException catch (error) {
      throw BackendAuthException(error.message, code: error.code);
    }
  }

  /// Confirma o ignora una ocurrencia que sonó en este teléfono.
  Future<void> respondToReminder({
    required String reminderId,
    required DateTime dueAt,
    required String response,
  }) async {
    if (currentSession == null) {
      throw const BackendAuthException(
        'Debes entrar a la app para responder.',
        code: 'missing_session',
      );
    }

    try {
      await _supabase.rpc(
        'respond_to_reminder',
        params: {
          'p_reminder_id': reminderId,
          'p_due_at': dueAt.toUtc().toIso8601String(),
          'p_response': response,
        },
      );
    } on PostgrestException catch (error) {
      throw BackendAuthException(error.message, code: error.code);
    }
  }

  /// El socket de Realtime está abierto (no implica que el canal ya se unió).
  bool get isRealtimeConnected => _supabase.realtime.isConnected;

  /// Suscripción a cambios de recordatorios. El callback debe ser liviano.
  ///
  /// [onSocketLost] se llama si el canal se cierra o falla. Útil en segundo
  /// plano: `supabase_flutter` corta el WebSocket al pausar la app.
  ({Future<void> Function() dispose}) subscribeReminderChanges(
    void Function() onChange, {
    void Function()? onSocketLost,
  }) {
    final userId = currentSession?.userId ?? 'anon';
    var disposed = false;
    final channel = _supabase
        .channel('noty-reminders-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reminders',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reminder_devices',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reminder_responses',
          callback: (_) => onChange(),
        )
        .subscribe((status, error) {
          debugPrint(
            'Noty realtime reminders: $status'
            '${error == null ? '' : ' $error'}',
          );
          if (disposed) {
            return;
          }
          if (status == RealtimeSubscribeStatus.closed ||
              status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) {
            onSocketLost?.call();
          }
        });

    return (
      dispose: () async {
        disposed = true;
        await _supabase.removeChannel(channel);
      },
    );
  }

  /// Apaga en la nube los recordatorios que ya no tienen más avisos.
  Future<void> expireFinishedReminders() async {
    if (currentSession == null) {
      return;
    }

    try {
      await _supabase.rpc('expire_finished_reminders');
    } on PostgrestException catch (error) {
      debugPrint('Noty expire finished reminders: ${error.message}');
    }
  }

  /// Recordatorios vigentes de quien llama, con los devices asignados.
  Future<List<Map<String, dynamic>>> fetchReminders() async {
    if (currentSession == null) {
      throw const BackendAuthException(
        'Debes entrar a la app para ver tus recordatorios.',
        code: 'missing_session',
      );
    }

    try {
      final rows = await _supabase
          .from('reminders')
          .select(
            'id, name, description, time_local, timezone, start_date, '
            'every_day, monday, tuesday, wednesday, thursday, friday, '
            'saturday, sunday, run_days, single_use, is_active, created_at, '
            'reminder_devices(devices(id, custom_name, brand, model)), '
            'reminder_responses(response, due_at, device_id, responded_at)',
          )
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      return [
        for (final row in rows) Map<String, dynamic>.from(row),
      ];
    } on PostgrestException catch (error) {
      throw BackendAuthException(error.message, code: error.code);
    }
  }

  Map<String, dynamic>? _asDeviceMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    if (value is List && value.isNotEmpty) {
      return _asDeviceMap(value.first);
    }
    return null;
  }

  Future<BackendAuthSession> _convertAnonymousUser({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.updateUser(
        UserAttributes(email: email, password: password),
      );
      return _requireSession(response.user);
    } on BackendAuthException {
      rethrow;
    } on AuthException catch (error) {
      throw _wrap(error);
    }
  }

  Future<void> _signInWithOAuth(OAuthProvider provider) async {
    try {
      final launched = await _auth.signInWithOAuth(
        provider,
        redirectTo: kIsWeb ? null : oauthRedirectTo,
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
      if (!launched) {
        throw const BackendAuthException(
          'No pudimos abrir el inicio de sesión. Intentémoslo de nuevo.',
          code: 'oauth_not_launched',
        );
      }
    } on BackendAuthException {
      rethrow;
    } on AuthException catch (error) {
      throw _wrap(error);
    }
  }

  BackendAuthSession _requireSession(User? user) {
    final session = _mapUser(user);
    if (session == null) {
      throw const BackendAuthException(
        'No pudimos entrar. Intentémoslo de nuevo.',
        code: 'missing_session',
      );
    }
    return session;
  }

  BackendAuthSession? _mapUser(User? user) {
    if (user == null) {
      return null;
    }
    return BackendAuthSession(
      userId: user.id,
      isAnonymous: user.isAnonymous,
      email: user.email,
    );
  }

  BackendAuthException _wrap(AuthException error) {
    debugPrint(
      'Auth error code=${error.code} status=${error.statusCode} '
      'message=${error.message}',
    );
    return BackendAuthException(error.message, code: error.code);
  }
}
