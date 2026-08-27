import 'package:flutter/material.dart';
import 'package:noty/auth/models/auth_session.dart';
import 'package:noty/auth/screens/sign_up_screen.dart';
import 'package:noty/auth/services/auth_service.dart';
import 'package:noty/auth/widgets/auth_validators.dart';
import 'package:noty/core/theme/app_colors.dart';
import 'package:noty/core/widgets/noty_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AuthService _auth;

  var _obscurePassword = true;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _auth = widget.authService ?? AuthService();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
    } on AuthFailure catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('No pudimos entrar. Intentémoslo de nuevo.');
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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await _run(() {
      return _auth.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    });
  }

  void _openSignUp() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SignUpScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _busy,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 32,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      const NotyLogo(),
                      const SizedBox(height: 16),
                      Text(
                        'Entra para cuidar y recordar juntos.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppColors.grisMedio),
                      ),
                      const SizedBox(height: 32),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Correo',
                              ),
                              validator: AuthValidators.email,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    );
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: AuthValidators.password,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _submit,
                          child: const Text('Entrar'),
                        ),
                      ),
                      TextButton(
                        onPressed: _openSignUp,
                        child: const Text('¿No tienes cuenta? Crea una'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'o',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.grisMedio),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => _run(_auth.continueWithoutAccount),
                        child: const Text('Continuar sin cuenta'),
                      ),
                      if (_busy) ...[
                        const SizedBox(height: 16),
                        const CircularProgressIndicator(),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
