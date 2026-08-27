import 'package:flutter/material.dart';
import 'package:noty/auth/models/auth_session.dart';
import 'package:noty/auth/services/auth_service.dart';
import 'package:noty/auth/widgets/auth_validators.dart';
import 'package:noty/core/theme/app_colors.dart';
import 'package:noty/core/widgets/noty_logo.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

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
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await _auth.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on AuthFailure catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('No pudimos crear la cuenta. Intentémoslo de nuevo.');
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.azulNoty,
      ),
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
                      const NotyLogo(),
                      const SizedBox(height: 16),
                      Text(
                        'Crea tu cuenta para cuidar y recordar.',
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
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
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
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.newPassword],
                              onFieldSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                labelText: 'Confirmar contraseña',
                              ),
                              validator: (value) =>
                                  AuthValidators.confirmPassword(
                                    value,
                                    _passwordController.text,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _submit,
                          child: const Text('Crear cuenta'),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('¿Ya tienes cuenta? Entra'),
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
