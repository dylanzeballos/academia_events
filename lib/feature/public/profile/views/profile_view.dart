// lib/feature/public/profile/views/profile_view.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:academia_events/core/constants/app_constants.dart';
import 'package:academia_events/core/theme/app_colors.dart';
import 'package:academia_events/core/theme/theme_transition.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';
import 'package:academia_events/core/utils/validators.dart';
import 'package:academia_events/data/models/profile_model.dart';
import 'package:academia_events/providers/auth_provider.dart';
import 'package:academia_events/providers/layout_mode_provider.dart';
import 'package:academia_events/providers/theme_provider.dart';
import 'package:academia_events/shared/widgets/app_button.dart';
import 'package:academia_events/shared/widgets/app_feedback.dart';
import 'package:academia_events/shared/widgets/error_banner.dart';
import 'package:academia_events/shared/widgets/fullscreen_image_viewer.dart';

import 'my_invitations_view.dart';

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key});

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _editing = false;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _initFields(ProfileModel profile) {
    if (_initialized) return;
    _firstNameCtrl.text = profile.firstName;
    _lastNameCtrl.text = profile.lastName;
    _phoneCtrl.text = profile.phoneNumber ?? '';
    _initialized = true;
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

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (image == null) return;

    final bytes = await File(image.path).readAsBytes();
    final ext = image.path.split('.').last;

    final repo = ref.read(authRepositoryProvider);
    final path = await repo.uploadAvatar(bytes, extension: ext);

    await repo.updateProfile(
      firstName: _firstNameCtrl.text,
      lastName: _lastNameCtrl.text,
      phone: _phoneCtrl.text,
      avatarPath: path,
    );
    ref.invalidate(currentProfileProvider);
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cardBg,
        title: Text('Cerrar sesión', style: TextStyle(color: context.textOnBg)),
        content: Text(
          '¿Estás seguro de que quieres salir?',
          style: TextStyle(color: context.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: context.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Salir',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  void _onModeChanged(BuildContext context, WidgetRef ref, AppLayoutMode mode) {
    if (mode == ref.read(effectiveLayoutModeProvider)) return;
    final router = GoRouter.of(context);
    ref.read(layoutModeProvider.notifier).set(mode);
    router.go(
      mode == AppLayoutMode.academy
          ? AppRoutes.academyDashboard
          : AppRoutes.studentHome,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (e, _) => Center(child: AppBanner(message: friendlyError(e))),
          data: (profile) {
            if (profile == null) {
              return Center(
                child: Text(
                  'No se pudo cargar el perfil',
                  style: TextStyle(color: context.textMuted),
                ),
              );
            }
            _initFields(profile);
            return _buildContent(profile);
          },
        ),
      ),
    );
  }

  Widget _buildContent(ProfileModel profile) {
    final avatarUrl = ref.watch(resolvedAvatarUrlProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final mode = ref.watch(effectiveLayoutModeProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    GestureDetector(
                      onTap: avatarUrl == null
                          ? null
                          : () => FullscreenImageViewer.show(
                              context,
                              avatarUrl,
                              tag: 'profile-avatar',
                            ),
                      child: Hero(
                        tag: 'profile-avatar',
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: context.cardBg,
                          backgroundImage: avatarUrl != null
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null
                              ? Text(
                                  profile.firstName.isNotEmpty
                                      ? profile.firstName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: context.textOnBg,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  profile.fullName,
                  style: TextStyle(
                    color: context.textOnBg,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.phoneNumber ?? 'Sin teléfono',
                  style: TextStyle(color: context.textMuted),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
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
                              _firstNameCtrl.text = profile.firstName;
                              _lastNameCtrl.text = profile.lastName;
                              _phoneCtrl.text = profile.phoneNumber ?? '';
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
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Divider(color: context.divider),
                const SizedBox(height: 16),
                Builder(
                  builder: (tileContext) => SwitchListTile(
                    title: Text(
                      'Modo oscuro',
                      style: TextStyle(color: context.textOnBg, fontSize: 15),
                    ),
                    subtitle: Text(
                      isDark ? 'Activado' : 'Desactivado',
                      style: TextStyle(color: context.textMuted, fontSize: 12),
                    ),
                    secondary: Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode,
                      color: AppColors.primary,
                    ),
                    value: isDark,
                    onChanged: (_) {
                      final box = tileContext.findRenderObject() as RenderBox?;
                      final origin = box != null
                          ? box.localToGlobal(
                              Offset(box.size.width - 32, box.size.height / 2),
                            )
                          : MediaQuery.sizeOf(context).center(Offset.zero);
                      animateThemeToggle(context, ref, origin: origin);
                    },
                    activeThumbColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Modo de la app',
                  style: TextStyle(
                    color: context.textOnBg,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cambia entre la vista de estudiante y el panel de tu organización.',
                  style: TextStyle(color: context.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                SegmentedButton<AppLayoutMode>(
                  segments: const [
                    ButtonSegment(
                      value: AppLayoutMode.student,
                      icon: Icon(Icons.person_outline),
                      label: Text('Usuario'),
                    ),
                    ButtonSegment(
                      value: AppLayoutMode.academy,
                      icon: Icon(Icons.storefront_outlined),
                      label: Text('Organización'),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (selection) =>
                      _onModeChanged(context, ref, selection.first),
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    backgroundColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    overlayColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    side: WidgetStateProperty.resolveWith((states) {
                      final isSelected = states.contains(WidgetState.selected);
                      return BorderSide(
                        color: isSelected ? AppColors.primary : context.divider,
                        width: isSelected ? 1.4 : 1,
                      );
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      return states.contains(WidgetState.selected)
                          ? AppColors.primary
                          : context.textMuted;
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Mis Invitaciones',
                  isOutlined: true,
                  icon: Icons.mail_outline,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyInvitationsView(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Cerrar sesión',
                  isOutlined: true,
                  color: AppColors.error,
                  onPressed: _signOut,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
