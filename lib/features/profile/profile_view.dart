// lib/features/profile/profile_view.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/profile_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/layout_mode_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_section_card.dart';
import '../../../shared/widgets/error_banner.dart';
import '../../../shared/widgets/fullscreen_image_viewer.dart';
import '../organization/views/my_invitations_view.dart';

/// Perfil del usuario (pestaña).
///
/// Cabecera compacta + secciones agrupadas (Cuenta, Preferencias,
/// Organización, Sesión). La edición vive en un modal, así el perfil se lee
/// rápido y no parece un formulario permanente.
class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key});

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  Future<void> _pickAvatar(ProfileModel profile) async {
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

    try {
      final path = await repo.uploadAvatar(bytes, extension: ext);
      await repo.updateProfile(
        firstName: profile.firstName,
        lastName: profile.lastName,
        phone: profile.phoneNumber ?? '',
        avatarPath: path,
      );
      ref.invalidate(currentProfileProvider);
      if (mounted) AppFeedback.success(context, 'Foto actualizada.');
    } catch (e) {
      if (mounted) AppFeedback.error(context, friendlyError(e));
    }
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
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(authControllerProvider.notifier).signOut();
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

  Future<void> _openEditSheet(ProfileModel profile) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.cardBg,
      builder: (_) => _EditProfileSheet(profile: profile),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        elevation: 0,
        title: Text(
          'Perfil',
          style: TextStyle(
            color: context.textOnBg,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
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
            return _buildContent(profile);
          },
        ),
      ),
    );
  }

  Widget _buildContent(ProfileModel profile) {
    final avatarUrl = ref.watch(resolvedAvatarUrlProvider);
    final email = ref.read(authRepositoryProvider).currentUser?.email;
    final isAcademy =
        ref.watch(effectiveLayoutModeProvider) == AppLayoutMode.academy;
    final hasOrgs =
        (ref.watch(myOrganizationsProvider).value ?? const []).isNotEmpty;
    final pendingInvitations =
        ref.watch(myInvitationsProvider).value?.length ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        _ProfileHeader(
          profile: profile,
          avatarUrl: avatarUrl,
          isAcademy: isAcademy,
          onEdit: () => _openEditSheet(profile),
          onPickAvatar: () => _pickAvatar(profile),
        ),
        const SizedBox(height: 16),
        AppSectionCard(
          title: 'Cuenta',
          icon: Icons.badge_outlined,
          trailing: TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: () => _openEditSheet(profile),
            child: const Text('Editar', style: TextStyle(fontSize: 12)),
          ),
          children: [
            _FieldRow(label: 'Nombre', value: profile.fullName),
            _FieldRow(
              label: 'Teléfono',
              value: profile.phoneNumber?.trim().isNotEmpty == true
                  ? profile.phoneNumber!
                  : 'Sin teléfono',
            ),
            _FieldRow(label: 'Email', value: email ?? 'Sin email'),
          ],
        ),
        const SizedBox(height: 12),
        AppSectionCard(
          title: 'Preferencias',
          icon: Icons.tune_rounded,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.palette_outlined, color: AppColors.primary),
              title: Text(
                'Tema',
                style: TextStyle(color: context.textOnBg, fontSize: 14),
              ),
              subtitle: Text(
                themeModeLabel(ref.watch(themeModeProvider)),
                style: TextStyle(color: context.textMuted, fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Cambiar',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: context.textMuted,
                  ),
                ],
              ),
              onTap: () => _openThemeSheet(context, ref),
            ),
            if (hasOrgs) ...[
              Divider(height: 20, color: context.divider),
              _buildModeTile(context, ref, isAcademy),
            ],
          ],
        ),
        const SizedBox(height: 12),
        AppSectionCard(
          title: 'Organización',
          icon: Icons.storefront_outlined,
          children: [
            if (!hasOrgs) ...[
              _buildCreateOrgCard(context),
              const SizedBox(height: 12),
            ],
            _buildInvitationsButton(context, pendingInvitations),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _signOut,
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text('Cerrar sesión'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
            minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          ),
        ),
      ],
    );
  }

  Future<void> _openThemeSheet(BuildContext context, WidgetRef ref) async {
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.cardBg,
      builder: (_) => _ThemeSheet(current: ref.read(themeModeProvider)),
    );
    if (selected == null) return;
    ref.read(themeModeProvider.notifier).set(selected);
  }

  Widget _buildModeTile(BuildContext context, WidgetRef ref, bool isAcademy) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
      title: Text(
        'Modo de la app',
        style: TextStyle(color: context.textOnBg, fontSize: 14),
      ),
      subtitle: Text(
        isAcademy ? 'Estás en modo academia' : 'Estás en modo estudiante',
        style: TextStyle(color: context.textMuted, fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Cambiar',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 2),
          Icon(Icons.chevron_right_rounded, size: 20, color: context.textMuted),
        ],
      ),
      onTap: () => _openModeSheet(context, ref),
    );
  }

  Future<void> _openModeSheet(BuildContext context, WidgetRef ref) async {
    final selected = await showModalBottomSheet<AppLayoutMode>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.cardBg,
      builder: (_) =>
          _ModeSheet(current: ref.read(effectiveLayoutModeProvider)),
    );
    if (selected == null || !context.mounted) return;
    _onModeChanged(context, ref, selected);
  }

  Widget _buildCreateOrgCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Tenés una academia u organizás eventos?',
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Creá tu organización para administrar clases, eventos, '
            'profesores y entradas.',
            style: TextStyle(
              color: context.textMuted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.add_business_outlined, size: 18),
              label: const Text('Crear mi organización'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
              onPressed: () => context.push(AppRoutes.organizationsCreate),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationsButton(BuildContext context, int pendingCount) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.mail_outline_rounded, color: AppColors.primary),
      title: Text(
        'Mis invitaciones',
        style: TextStyle(color: context.textOnBg, fontSize: 14),
      ),
      subtitle: Text(
        pendingCount > 0
            ? '$pendingCount pendiente${pendingCount == 1 ? '' : 's'}'
            : 'Invitaciones a organizaciones',
        style: TextStyle(color: context.textMuted, fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pendingCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$pendingCount',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 20, color: context.textMuted),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyInvitationsView()),
      ),
    );
  }
}

/// Cabecera del perfil: avatar, nombre, email y rol.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.avatarUrl,
    required this.isAcademy,
    required this.onEdit,
    required this.onPickAvatar,
  });

  final ProfileModel profile;
  final String? avatarUrl;
  final bool isAcademy;
  final VoidCallback onEdit;
  final VoidCallback onPickAvatar;

  @override
  Widget build(BuildContext context) {
    final initial = profile.firstName.isNotEmpty
        ? profile.firstName[0].toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(color: context.divider),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              GestureDetector(
                onTap: avatarUrl == null
                    ? null
                    : () => FullscreenImageViewer.show(
                        context,
                        avatarUrl!,
                        tag: 'profile-avatar',
                      ),
                child: Hero(
                  tag: 'profile-avatar',
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl!)
                        : null,
                    child: avatarUrl == null
                        ? Text(
                            initial,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onPickAvatar,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.cardBg, width: 2),
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    size: 11,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textOnBg,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    isAcademy ? 'Modo academia' : 'Modo estudiante',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar perfil',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.edit_outlined, color: context.textMuted, size: 20),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.textOnBg, fontSize: 14.5),
          ),
        ],
      ),
    );
  }
}

/// Hoja para elegir el tema: sistema, claro u oscuro.
class _ThemeSheet extends StatelessWidget {
  const _ThemeSheet({required this.current});

  final ThemeMode current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tema',
              style: TextStyle(
                color: context.textOnBg,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Con "Según el sistema" la app sigue el modo claro u oscuro del '
              'teléfono.',
              style: TextStyle(
                color: context.textMuted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            _ThemeOption(
              mode: ThemeMode.system,
              icon: Icons.brightness_auto_rounded,
              title: 'Según el sistema',
              description: 'Cambia automáticamente con el teléfono.',
              selected: current == ThemeMode.system,
            ),
            const SizedBox(height: 10),
            _ThemeOption(
              mode: ThemeMode.light,
              icon: Icons.light_mode_rounded,
              title: 'Claro',
              description: 'Siempre con fondo claro.',
              selected: current == ThemeMode.light,
            ),
            const SizedBox(height: 10),
            _ThemeOption(
              mode: ThemeMode.dark,
              icon: Icons.dark_mode_rounded,
              title: 'Oscuro',
              description: 'Siempre con fondo oscuro.',
              selected: current == ThemeMode.dark,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
  });

  final ThemeMode mode;
  final IconData icon;
  final String title;
  final String description;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : context.divider;

    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.08)
          : context.cardBg,
      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        onTap: () => Navigator.pop(context, mode),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            border: Border.all(color: color, width: selected ? 1.4 : 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.textOnBg,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        color: context.textMuted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Hoja para cambiar entre modo estudiante y academia.
class _ModeSheet extends StatelessWidget {
  const _ModeSheet({required this.current});

  final AppLayoutMode current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cambiar modo',
              style: TextStyle(
                color: context.textOnBg,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Elegí cómo querés usar la app. Podés cambiarlo cuando quieras.',
              style: TextStyle(
                color: context.textMuted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            _ModeOption(
              mode: AppLayoutMode.student,
              icon: Icons.person_outline_rounded,
              title: 'Estudiante',
              description:
                  'Explorá clases y horarios, inscribite y comprá acceso.',
              selected: current == AppLayoutMode.student,
            ),
            const SizedBox(height: 10),
            _ModeOption(
              mode: AppLayoutMode.academy,
              icon: Icons.storefront_outlined,
              title: 'Academia',
              description: 'Gestioná tus clases, eventos, miembros y cobros.',
              selected: current == AppLayoutMode.academy,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.mode,
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
  });

  final AppLayoutMode mode;
  final IconData icon;
  final String title;
  final String description;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : context.divider;

    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.08)
          : context.cardBg,
      borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        onTap: () => Navigator.pop(context, mode),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            border: Border.all(color: color, width: selected ? 1.4 : 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.textOnBg,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        color: context.textMuted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Formulario de edición en modal.
class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.profile});

  final ProfileModel profile;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _phoneCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController(text: widget.profile.firstName);
    _lastNameCtrl = TextEditingController(text: widget.profile.lastName);
    _phoneCtrl = TextEditingController(text: widget.profile.phoneNumber ?? '');
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

    setState(() => _saving = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .updateProfile(
            firstName: _firstNameCtrl.text.trim(),
            lastName: _lastNameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
          );
      ref.invalidate(currentProfileProvider);
      if (!mounted) return;
      AppFeedback.success(context, 'Perfil actualizado.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) AppFeedback.error(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Editar perfil',
                style: TextStyle(
                  color: context.textOnBg,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _firstNameCtrl,
                style: TextStyle(color: context.textOnBg),
                validator: AppValidators.firstName,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lastNameCtrl,
                style: TextStyle(color: context.textOnBg),
                validator: AppValidators.lastName,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Apellido',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                style: TextStyle(color: context.textOnBg),
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : const Text('Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
