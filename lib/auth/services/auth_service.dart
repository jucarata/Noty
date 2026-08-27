import 'package:noty/auth/models/auth_session.dart';
import 'package:noty/core/network/backend_client.dart';

/// Fachada de la feature auth.
///
/// Las pantallas hablan solo con esta clase. No importan Supabase ni
/// [BackendClient].
class AuthService {
  AuthService({BackendClient? client})
    : _client = client ?? BackendClient.instance {
    sessions = _client.authChanges.map(_map);
  }

  final BackendClient _client;

  late final Stream<AuthSession?> sessions;

  AuthSession? get currentSession => _map(_client.currentSession);

  Future<AuthSession> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return _mapRequired(
        await _client.signInWithEmail(email: email, password: password),
      );
    } on BackendAuthException catch (error) {
      throw AuthFailure(_copyFor(error));
    }
  }

  Future<AuthSession> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return _mapRequired(
        await _client.signUpWithEmail(email: email, password: password),
      );
    } on BackendAuthException catch (error) {
      throw AuthFailure(_copyFor(error));
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      await _client.signInWithGoogle();
    } on BackendAuthException catch (error) {
      throw AuthFailure(_copyFor(error, provider: 'Google'));
    }
  }

  Future<void> signInWithMicrosoft() async {
    try {
      await _client.signInWithMicrosoft();
    } on BackendAuthException catch (error) {
      throw AuthFailure(_copyFor(error, provider: 'Microsoft'));
    }
  }

  /// Si ya hay sesión (anónima o no), la reutiliza. No crea otro usuario.
  Future<AuthSession> continueWithoutAccount() async {
    try {
      return _mapRequired(await _client.signInAnonymously());
    } on BackendAuthException catch (error) {
      throw AuthFailure(_copyFor(error));
    }
  }

  Future<void> signOut() async {
    try {
      await _client.signOut();
    } on BackendAuthException catch (error) {
      throw AuthFailure(_copyFor(error));
    }
  }

  /// TEMPORAL de desarrollo: borra la cuenta en Supabase y la sesión local.
  Future<void> purgeCurrentUser() async {
    try {
      await _client.purgeCurrentUser();
    } on BackendAuthException catch (error) {
      throw AuthFailure(_copyFor(error));
    }
  }

  AuthSession? _map(BackendAuthSession? session) {
    if (session == null) {
      return null;
    }
    return AuthSession(
      userId: session.userId,
      isAnonymous: session.isAnonymous,
      email: session.email,
    );
  }

  AuthSession _mapRequired(BackendAuthSession session) {
    return _map(session)!;
  }

  String _copyFor(BackendAuthException error, {String? provider}) {
    final code = error.code ?? '';
    switch (code) {
      case 'invalid_credentials':
        return 'El correo o la contraseña no coinciden. Revisémoslo.';
      case 'email_not_confirmed':
        return 'Revisa tu correo para confirmar la cuenta. Luego podrás entrar.';
      case 'user_already_exists':
      case 'email_exists':
      case 'identity_already_exists':
      case 'signup_disabled':
        return 'Ya existe una cuenta con este correo. Probemos a entrar.';
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
        return 'Supabase pausó los registros un rato (límite del plan gratis). '
            'Espera unos minutos o entra con Continuar sin cuenta.';
      case 'email_address_invalid':
      case 'email_address_not_authorized':
        return 'Ese correo no es válido para crear la cuenta. Prueba con uno real, como Gmail u Outlook.';
      case 'validation_failed':
        return 'Revisa el correo y la contraseña e intentémoslo de nuevo.';
      case 'weak_password':
        return 'Esa contraseña es demasiado común. Prueba otra de al menos 8 caracteres.';
      case 'unexpected_failure':
        return 'No pudimos guardar la cuenta. Si ya corriste las tablas en Supabase, intentémoslo de nuevo.';
      case 'anonymous_provider_disabled':
        return 'Por ahora necesitamos una cuenta para entrar. Probemos con correo.';
      case 'PGRST202':
        return 'Falta crear en Supabase la función de borrar cuenta. Ejecuta la migración purge_own_account.';
      default:
        if (provider != null) {
          return 'No pudimos entrar con $provider. Intentémoslo de nuevo o usa correo.';
        }
        if (error.message.contains('Anonymous')) {
          return 'Por ahora necesitamos una cuenta para entrar. Probemos con correo.';
        }
        if (error.message.contains('purge_own_account') ||
            error.message.contains('Could not find the function')) {
          return 'Falta crear en Supabase la función de borrar cuenta. Ejecuta la migración purge_own_account.';
        }
        if (error.message.toLowerCase().contains('database')) {
          return 'No pudimos guardar el perfil. Revisa que las tablas de Noty estén creadas en Supabase.';
        }
        if (error.message.toLowerCase().contains('already') ||
            error.message.toLowerCase().contains('registered')) {
          return 'Ya existe una cuenta con este correo. Probemos a entrar.';
        }
        return 'No pudimos entrar. Intentémoslo de nuevo.';
    }
  }
}
