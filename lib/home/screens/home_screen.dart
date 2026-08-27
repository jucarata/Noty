import 'package:flutter/material.dart';
import 'package:noty/auth/models/auth_session.dart';
import 'package:noty/auth/services/auth_service.dart';
import 'package:noty/core/widgets/noty_logo.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AuthService _auth;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _auth = widget.authService ?? AuthService();
  }

  Future<void> _signOut() async {
    await _run(
      _auth.signOut,
      fallback: 'No pudimos cerrar la sesión. Intentémoslo de nuevo.',
    );
  }

  Future<void> _purgeUser() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('¿Borrar esta cuenta de prueba?'),
          content: const Text(
            'Se cierra la sesión y se elimina el usuario. '
            'Después podrás crear otra cuenta, incluso con el mismo correo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Borrar cuenta'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await _run(
      _auth.purgeCurrentUser,
      fallback: 'No pudimos borrar la cuenta. Intentémoslo de nuevo.',
    );
  }

  Future<void> _run(
    Future<void> Function() action, {
    required String fallback,
  }) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
    } on AuthFailure catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage(fallback);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const NotyLogo(),
              const SizedBox(height: 48),
              FilledButton(
                onPressed: () {},
                child: const Text('Vincular dispositivo'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _busy ? null : _signOut,
                child: const Text('Cerrar sesión'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : _purgeUser,
                child: const Text('Purgar usuario (pruebas)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
