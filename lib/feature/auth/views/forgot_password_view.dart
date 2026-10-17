import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:academia_events/core/constants/app_constants.dart';
import 'package:academia_events/core/theme/app_colors.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';
import 'package:academia_events/core/utils/validators.dart';
import 'package:academia_events/providers/auth_provider.dart';
import 'package:academia_events/shared/widgets/app_button.dart';
import 'package:academia_events/shared/widgets/error_banner.dart';

class ForgotPasswordView extends ConsumerStatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  ConsumerState<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends ConsumerState<ForgotPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authControllerProvider.notifier)
        .sendPasswordRecovery(_emailCtrl.text.trim());
    if (mounted && ref.read(authControllerProvider).error == null) {
      setState(() => _sent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const Text('Recuperar contraseña'),
        backgroundColor: context.scaffoldBg,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingLarge),
          child: _sent
              ? _SuccessContent(email: _emailCtrl.text.trim())
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Ingresa tu correo y te enviaremos un enlace para restablecer tu contraseña.',
                        style: TextStyle(color: context.textMuted),
                      ),
                      const SizedBox(height: 20),
                      if (authState.error != null)
                        AppBanner(message: authState.error!),
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
                      const SizedBox(height: 24),
                      AppButton(
                        label: 'Enviar enlace',
                        isLoading: authState.isLoading,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _SuccessContent extends StatelessWidget {
  const _SuccessContent({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          size: 64,
          color: AppColors.success,
        ),
        const SizedBox(height: 16),
        Text(
          '¡Correo enviado!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: context.textOnBg,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Revisa tu bandeja en $email',
          style: TextStyle(color: context.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}