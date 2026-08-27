import 'package:flutter/material.dart';
import 'package:noty/auth/models/auth_session.dart';
import 'package:noty/auth/services/auth_service.dart';

/// Elige home o login según la sesión persistida. No llama a red ni a Supabase.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.signedIn,
    required this.signedOut,
    this._authService,
  });

  final Widget signedIn;
  final Widget signedOut;
  final AuthService? _authService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthService _auth;

  @override
  void initState() {
    super.initState();
    _auth = widget._authService ?? AuthService();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthSession?>(
      initialData: _auth.currentSession,
      stream: _auth.sessions,
      builder: (context, snapshot) {
        if (snapshot.data != null) {
          return widget.signedIn;
        }
        return widget.signedOut;
      },
    );
  }
}
