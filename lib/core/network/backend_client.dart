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
  Future<void> upsertOwnDevice({
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
      await _supabase.from('devices').upsert({
        'install_id': installId,
        'owner_id': ownerId,
        'platform': platform,
        'device_kind': deviceKind,
        'brand': ?brand,
        'model': ?model,
        'os_version': ?osVersion,
        'custom_name': ?customName,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'install_id');
    } on PostgrestException catch (error) {
      throw BackendAuthException(error.message, code: error.code);
    }
  }

  /// Vincula el device del QR a la familia del usuario actual (host).
  ///
  /// Si aún no hay familia, el RPC crea “Mi familia”. El device queda como
  /// acompañado: el host y el resto de miembros del grupo quedan relacionados.
  Future<void> linkDeviceToFamily({
    required String installId,
    String? familyId,
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

    try {
      await _supabase.rpc(
        'link_device_to_family',
        params: {'p_install_id': installId, 'p_family_id': ?familyId},
      );
    } on PostgrestException catch (error) {
      throw BackendAuthException(error.message, code: error.code);
    }
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
