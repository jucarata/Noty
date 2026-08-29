import 'package:flutter/material.dart';
import 'package:noty/auth/models/auth_session.dart';
import 'package:noty/auth/services/auth_service.dart';
import 'package:noty/core/theme/app_colors.dart';
import 'package:noty/notifications/services/notificator.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.authService, this.notificator});

  final AuthService? authService;
  final Notificator? notificator;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final AuthService _auth;
  late final Notificator _notificator;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _auth = widget.authService ?? AuthService();
    _notificator = widget.notificator ?? Notificator.instance;
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
            'Se elimina el usuario, sus recordatorios y las alarmas de este '
            'teléfono. Después podrás crear otra cuenta, incluso con el mismo correo.',
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
      () async {
        await _notificator.clearLocalAlarmsAndCache();
        try {
          await _auth.purgeCurrentUser();
        } catch (error) {
          try {
            await _notificator.refresh();
          } catch (_) {}
          rethrow;
        }
      },
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Perfil',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tu cuenta en Noty.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: AppColors.grisMedio),
                ),
                const SizedBox(height: 48),
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
      ),
    );
  }
}
