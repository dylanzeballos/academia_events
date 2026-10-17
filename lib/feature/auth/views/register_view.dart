import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:academia_events/core/constants/app_constants.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';
import 'package:academia_events/core/utils/validators.dart';
import 'package:academia_events/providers/auth_provider.dart';
import 'package:academia_events/shared/widgets/app_button.dart';
import 'package:academia_events/shared/widgets/error_banner.dart';

class RegisterView extends ConsumerStatefulWidget {
  const RegisterView({super.key});

  @override
  ConsumerState<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends ConsumerState<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final fullName =
        '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}';
    await ref.read(authControllerProvider.notifier).signUp(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          fullName: fullName,
        );
    if (mounted && ref.read(authControllerProvider).error == null) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        backgroundColor: context.scaffoldBg,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.paddingLarge),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (authState.error != null)
                    AppBanner(
                      message: authState.error!,
                      onDismiss: () =>
                          ref.read(authControllerProvider.notifier).clearError(),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstNameCtrl,
                          style: TextStyle(color: context.textOnBg),
                          validator: AppValidators.firstName,
                          decoration:
                              const InputDecoration(labelText: 'Nombre'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lastNameCtrl,
                          style: TextStyle(color: context.textOnBg),
                          validator: AppValidators.lastName,
                          decoration:
                              const InputDecoration(labelText: 'Apellido'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmCtrl,
                    style: TextStyle(color: context.textOnBg),
                    obscureText: _obscurePassword,
                    validator: (v) => AppValidators.confirmPassword(
                        _passwordCtrl.text, v),
                    decoration: const InputDecoration(
                      labelText: 'Confirmar contraseña',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Registrarme',
                    isLoading: authState.isLoading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}