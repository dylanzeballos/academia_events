import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:academia_events/core/theme/app_colors.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';
import 'package:academia_events/core/utils/validators.dart';
import 'package:academia_events/data/models/profile_model.dart';
import 'package:academia_events/providers/auth_provider.dart';
import 'package:academia_events/shared/widgets/app_button.dart';

class ProfileFormSection extends ConsumerStatefulWidget {
  const ProfileFormSection({
    super.key,
    required this.profile,
  });

  final ProfileModel profile;

  @override
  ConsumerState<ProfileFormSection> createState() => _ProfileFormSectionState();
}

class _ProfileFormSectionState extends ConsumerState<ProfileFormSection> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _phoneCtrl;
  bool _editing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController(text: widget.profile.firstName);
    _lastNameCtrl = TextEditingController(text: widget.profile.lastName);
    _phoneCtrl = TextEditingController(text: widget.profile.phoneNumber ?? '');
  }

  @override
  void didUpdateWidget(covariant ProfileFormSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.profile != widget.profile) {
      _firstNameCtrl.text = widget.profile.firstName;
      _lastNameCtrl.text = widget.profile.lastName;
      _phoneCtrl.text = widget.profile.phoneNumber ?? '';
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.updateProfile(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );

      ref.invalidate(currentProfileProvider);
      if (mounted) setState(() => _editing = false);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Datos personales',
                style: TextStyle(
                  color: context.textOnBg,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: Icon(
                  _editing ? Icons.close : Icons.edit,
                  color: AppColors.primary,
                ),
                onPressed: () {
                  setState(() {
                    _editing = !_editing;
                    if (!_editing) {
                      _firstNameCtrl.text = widget.profile.firstName;
                      _lastNameCtrl.text = widget.profile.lastName;
                      _phoneCtrl.text = widget.profile.phoneNumber ?? '';
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _firstNameCtrl,
            enabled: _editing,
            style: TextStyle(color: context.textOnBg),
            validator: AppValidators.firstName,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _lastNameCtrl,
            enabled: _editing,
            style: TextStyle(color: context.textOnBg),
            validator: AppValidators.lastName,
            decoration: const InputDecoration(
              labelText: 'Apellido',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneCtrl,
            enabled: _editing,
            style: TextStyle(color: context.textOnBg),
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Teléfono',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          if (_editing) ...[
            const SizedBox(height: 20),
            AppButton(
              label: 'Guardar cambios',
              isLoading: _isSaving,
              onPressed: _save,
            ),
          ],
        ],
      ),
    );
  }
}