import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:academia_events/core/constants/app_constants.dart';
import 'package:academia_events/core/theme/app_colors.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';
import 'package:academia_events/core/utils/validators.dart';
import 'package:academia_events/providers/auth_provider.dart';
import 'package:academia_events/shared/widgets/app_button.dart';
import 'package:academia_events/shared/widgets/error_banner.dart';

class UpdatePasswordView extends ConsumerStatefulWidget {
  const UpdatePasswordView({super.key});

  @override
  ConsumerState<UpdatePasswordView> createState() => _UpdatePasswordViewState();
}

class _UpdatePasswordViewState extends ConsumerState<UpdatePasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authControllerProvider.notifier)
        .updatePassword(_passwordCtrl.text);
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
                          Icons.lock_reset,
                          size: 44,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Nueva contraseña',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.textOnBg,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (authState.error != null)
                          AppBanner(message: authState.error!),
                        TextFormField(
                          controller: _passwordCtrl,
                          style: TextStyle(color: context.textOnBg),
                          obscureText: _obscure,
                          validator: AppValidators.password,
                          decoration: InputDecoration(
                            labelText: 'Nueva contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmCtrl,
                          style: TextStyle(color: context.textOnBg),
                          obscureText: _obscure,
                          validator: (v) => AppValidators.confirmPassword(
                              _passwordCtrl.text, v),
                          decoration: const InputDecoration(
                            labelText: 'Confirmar contraseña',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: 24),
                        AppButton(
                          label: 'Actualizar contraseña',
                          isLoading: authState.isLoading,
                          onPressed: _submit,
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