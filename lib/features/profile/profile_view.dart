import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/profile_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/layout_mode_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/error_banner.dart';
import '../organization/views/my_invitations_view.dart';

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

    final repo = ref.read(authRepositoryProvider);
    await repo.updateProfile(
      firstName: _firstNameCtrl.text,
      lastName: _lastNameCtrl.text,
      phone: _phoneCtrl.text,
    );

    ref.invalidate(currentProfileProvider);
    if (mounted) {
      setState(() => _editing = false);
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
    // Guardar el PATH del bucket en BD, nunca una URL firmada: las URLs
    // firmadas expiran (1 h) y rompen la imagen. La URL mostrable se
    // resuelve en resolvedAvatarUrlProvider.
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
        title: Text('Cerrar sesión',
            style: TextStyle(color: context.textOnBg)),
        content: const Text('¿Estás seguro de que quieres salir?',
            style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir',
                style: TextStyle(color: AppColors.error)),
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

    // Capturar el router ANTES de cambiar el estado: si el redirect del
    // router navega primero, este contexto se desmonta y usarlo lanzaría
    // un GoException. Con la referencia directa al GoRouter es seguro
    // navegar explícitamente y la UI se actualiza al instante.
    final router = GoRouter.of(context);
    ref.read(layoutModeProvider.notifier).set(mode);
    router.go(mode == AppLayoutMode.academy
        ? AppRoutes.academyDashboard
        : AppRoutes.studentHome);
  }

  Widget _buildCreateOrgCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Tienes una academia u organizas eventos?',
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Crea tu organización y conviértete en su propietario para '
            'administrar clases, eventos, profesores y entradas.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Crear mi organización',
            icon: Icons.add_business_outlined,
            onPressed: () => context.push(AppRoutes.organizationsCreate),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationsButton(BuildContext context, int pendingCount) {
    return AppButton(
      label: pendingCount > 0
          ? 'Invitaciones ($pendingCount pendientes)'
          : 'Mis Invitaciones',
      isOutlined: true,
      icon: Icons.mail_outline,
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const MyInvitationsView(),
        ),
      ),
    );
  }

  Widget _buildModeSection(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(effectiveLayoutModeProvider);
    final orgsAsync = ref.watch(myOrganizationsProvider);
    final invitationsAsync = ref.watch(myInvitationsProvider);

    final pendingCount =
        invitationsAsync.whenOrNull(data: (invites) => invites.length) ?? 0;
    final orgs = orgsAsync.whenOrNull(data: (orgs) => orgs);
    final hasOrgs = orgs != null && orgs.isNotEmpty;

    // ── Sin organizaciones: no mostrar el switch de modo ──────────
    // Solo el CTA para crear su organización e invitaciones.
    if (!hasOrgs) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Organización',
            style: TextStyle(
              color: context.textOnBg,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildCreateOrgCard(context),
          const SizedBox(height: 12),
          _buildInvitationsButton(context, pendingCount),
        ],
      );
    }

    // ── Con organizaciones: switch Usuario / Organización ─────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
            // Sin relleno: fondo transparente en claro y oscuro.
            backgroundColor:
                const WidgetStatePropertyAll(Colors.transparent),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
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
            textStyle: WidgetStateProperty.resolveWith((states) {
              return TextStyle(
                fontSize: 14,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w600
                    : FontWeight.w500,
              );
            }),
          ),
        ),
        const SizedBox(height: 12),
        _buildInvitationsButton(context, pendingCount),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(
            child: AppBanner(message: 'Error: $e'),
          ),
          data: (profile) {
            if (profile == null) {
              return const Center(
                child: Text('No se pudo cargar el perfil',
                    style: TextStyle(color: Colors.grey)),
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
                    CircleAvatar(
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
                  style: const TextStyle(color: Colors.grey),
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
                      isLoading: false,
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
                SwitchListTile(
                  title: Text('Modo oscuro',
                      style: TextStyle(color: context.textOnBg, fontSize: 15)),
                  subtitle: Text(
                    ref.watch(themeModeProvider) == ThemeMode.dark
                        ? 'Activado'
                        : 'Desactivado',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  secondary: Icon(
                    ref.watch(themeModeProvider) == ThemeMode.dark
                        ? Icons.dark_mode
                        : Icons.light_mode,
                    color: AppColors.primary,
                  ),
                  value: ref.watch(themeModeProvider) == ThemeMode.dark,
                  onChanged: (_) =>
                      ref.read(themeModeProvider.notifier).toggle(),
                  activeThumbColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                _buildModeSection(context, ref),
                const SizedBox(height: 12),
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
