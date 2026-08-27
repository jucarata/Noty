class AuthValidators {
  AuthValidators._();

  static const minPasswordLength = 8;

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty || !email.contains('@')) {
      return 'Escribe un correo válido.';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.length < minPasswordLength) {
      return 'La contraseña debe tener al menos $minPasswordLength caracteres.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    final lengthError = AuthValidators.password(value);
    if (lengthError != null) {
      return lengthError;
    }
    if (value != password) {
      return 'Las contraseñas no coinciden.';
    }
    return null;
  }
}
