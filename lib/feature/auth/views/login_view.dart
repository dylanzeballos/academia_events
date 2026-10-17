import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:academia_events/core/constants/app_constants.dart';
import 'package:academia_events/core/theme/app_colors.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';
import 'package:academia_events/core/utils/validators.dart';
import 'package:academia_events/providers/auth_provider.dart';
import 'package:academia_events/shared/widgets/app_button.dart';
import 'package:academia_events/shared/widgets/error_banner.dart';
import 'register_view.dart';
import 'forgot_password_view.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).signIn(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
  }

  Future<void> _googleLogin() async {
    await ref.read(authControllerProvider.notifier).signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.paddingLarge),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                color: context.cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
                  side: BorderSide(color: context.divider),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.paddingLarge),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.lock_open_rounded,
                          size: 44,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Iniciar sesión',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.textOnBg,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Accede a tus clases y eventos',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.textMuted),
                        ),
                        const SizedBox(height: 24),

                        if (authState.error != null)
                          AppBanner(
                            message: authState.error!,
                            onDismiss: () => ref
                                .read(authControllerProvider.notifier)
                                .clearError(),
                          ),

                        TextFormField(
                          controller: _emailCtrl,
                          style: TextStyle(color: context.textOnBg),
                          keyboardType: TextInputType.emailAddress,
                          validator: AppValidators.email,
                          decoration: const InputDecoration(
                            labelText: 'Correo',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordCtrl,
                          style: TextStyle(color: context.textOnBg),
                          obscureText: _obscurePassword,
                          validator: AppValidators.password,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                        ),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: authState.isLoading
                                ? null
                                : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ForgotPasswordView(),
                                      ),
                                    ),
                            child: const Text('Olvidé mi contraseña'),
                          ),
                        ),

                        AppButton(
                          label: 'Entrar',
                          isLoading: authState.isLoading,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: Divider(color: context.divider),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'O',
                                style: TextStyle(
                                  color: context.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(color: context.divider),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        OutlinedButton.icon(
                          onPressed: authState.isLoading ? null : _googleLogin,
                          icon: const Icon(Icons.g_mobiledata, size: 22),
                          label: const Text('Continuar con Google'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.textOnBg,
                            side: BorderSide(color: context.divider),
                            minimumSize:
                                const Size.fromHeight(AppSizes.buttonHeight),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppSizes.radiusMedium),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        AppButton(
                          label: 'Crear cuenta',
                          isOutlined: true,
                          onPressed: authState.isLoading
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterView(),
                                    ),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}