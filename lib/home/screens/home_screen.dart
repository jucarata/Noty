import 'package:flutter/material.dart';
import 'package:noty/auth/models/auth_session.dart';
import 'package:noty/auth/screens/login_screen.dart';
import 'package:noty/auth/services/auth_service.dart';
import 'package:noty/care/screens/add_device_screen.dart';
import 'package:noty/care/screens/share_device_screen.dart';
import 'package:noty/core/theme/app_colors.dart';
import 'package:noty/core/widgets/noty_logo.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AuthService _auth;

  @override
  void initState() {
    super.initState();
    _auth = widget.authService ?? AuthService();
  }

  void _openLogin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LoginScreen(authService: _auth)),
    );
  }

  void _openShareDevice() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ShareDeviceScreen()));
  }

  void _openAddDevice() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const AddDeviceScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: StreamBuilder<AuthSession?>(
            initialData: _auth.currentSession,
            stream: _auth.sessions,
            builder: (context, snapshot) {
              final canAddDevice = snapshot.data?.isAnonymous == false;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const NotyLogo(),
                  const SizedBox(height: 48),
                  FilledButton(
                    onPressed: _openShareDevice,
                    child: const Text('Compartir código de vinculación'),
                  ),
                  const SizedBox(height: 12),
                  if (canAddDevice)
                    OutlinedButton(
                      onPressed: _openAddDevice,
                      child: const Text('Añadir miembro familiar'),
                    )
                  else ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Text(
                        'Para añadir un miembro familiar, entra o crea una cuenta.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(color: AppColors.grisMedio),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _openLogin,
                      child: const Text('Iniciar sesión'),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
