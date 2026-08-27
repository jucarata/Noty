/// Sesión de producto. Las pantallas no ven tokens ni el SDK.
class AuthSession {
  const AuthSession({
    required this.userId,
    required this.isAnonymous,
    this.email,
  });

  final String userId;
  final bool isAnonymous;
  final String? email;
}

/// Fallo de auth con copy listo para mostrar.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
