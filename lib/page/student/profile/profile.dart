import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_service.dart';
import '../auth/auth_validators.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final IAuthService _authService = AuthService.instance;
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _imagePicker = ImagePicker();

  bool _isLoading = true;
  bool _isSigningOut = false;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  bool _isAccountActive = true;
  String? _error;
  String? _success;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _success = null;
    });

    try {
      await _authService.ensureAuthenticated();
      final profile = await _authService.fetchCurrentProfile();
        final user = _authService.currentUser;
        final firstName = (profile?['first_name'] as String?)?.trim();
        final lastName = (profile?['last_name'] as String?)?.trim();
        final resolvedFirstName =
          (firstName != null && firstName.isNotEmpty)
            ? firstName
            : '';

        final resolvedLastName =
          (lastName != null && lastName.isNotEmpty)
            ? lastName
            : '';

        final avatarPath = profile?['profile_image_url'] as String?;
        final signedAvatarUrl =
          (avatarPath != null && avatarPath.isNotEmpty)
            ? await _authService.createAvatarSignedUrl(avatarPath)
            : null;

      if (!mounted) return;
      setState(() {
        _firstNameController.text = resolvedFirstName;
        _lastNameController.text = resolvedLastName;
        _phoneController.text = (profile?['phone_number'] as String?) ?? '';
        _emailController.text = user?.email ?? '';
        _isAccountActive = (profile?['is_active'] as bool?) ?? true;
        _avatarUrl = signedAvatarUrl;
        
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        final code = e.code ?? '';
        final message = e.message.toLowerCase();

        if (code == '42P01' || message.contains('relation') && message.contains('profiles')) {
          _error = 'No existe la tabla profiles. Ejecuta las migraciones de Supabase en tu proyecto.';
        } else if (code == '42501' || message.contains('permission denied')) {
          _error = 'Sin permisos para leer profiles. Revisa RLS y policies.';
        } else {
          _error = 'Error DB: ${e.message}';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el perfil.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    setState(() {
      _isSigningOut = true;
      _error = null;
    });

    try {
      await _authService.signOut();
    } on AuthException catch (e) {
      setState(() {
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _error = 'No se pudo cerrar sesion.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    setState(() {
      _error = null;
      _success = null;
      _isUploadingAvatar = true;
    });

    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (file == null) {
        return;
      }

      final bytes = await file.readAsBytes();
      final name = file.name.toLowerCase();
      final extension = name.endsWith('.png') ? 'png' : 'jpg';
      final avatarPath = await _authService.uploadAvatar(
        bytes,
        extension: extension,
      );

      await _authService.updateMyProfile(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        phone: _phoneController.text,
        isActive: _isAccountActive,
        avatarPath: avatarPath,
      );

      final signedAvatarUrl = await _authService.createAvatarSignedUrl(avatarPath);

      if (!mounted) return;
      setState(() {
        _avatarUrl = signedAvatarUrl;
        _success = 'Foto de perfil actualizada.';
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo subir la imagen.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
      _success = null;
    });

    try {
      await _authService.updateMyProfile(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        phone: _phoneController.text,
        isActive: _isAccountActive,
      );

      final currentEmail = _authService.currentUser?.email ?? '';
      final newEmail = _emailController.text.trim();
      if (newEmail.isNotEmpty && newEmail != currentEmail) {
        await _authService.updateEmail(newEmail);
      }

      await _loadProfile();
      if (!mounted) return;
      setState(() {
        _success = 'Perfil actualizado correctamente.';
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo guardar el perfil.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final email = user?.email;

    Widget content;
    if (_isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      content = _StatusBox(
        icon: Icons.error_outline,
        title: 'Error',
        subtitle: _error!,
      );
    } else if (user == null) {
      content = const _StatusBox(
        icon: Icons.lock_outline,
        title: 'Sin sesion',
        subtitle: 'Inicia sesion para ver tu perfil.',
      );
    } else {
      content = SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  _Notice(message: _error!, color: Colors.redAccent),
                if (_success != null)
                  _Notice(message: _success!, color: Colors.green),
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: const Color(0xFF1B1B2F),
                        backgroundImage:
                            (_avatarUrl != null) ? NetworkImage(_avatarUrl!) : null,
                        child: (_avatarUrl == null)
                            ? const Icon(Icons.person, size: 48, color: Colors.white)
                            : null,
                      ),
                      IconButton.filled(
                        onPressed: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                        icon: _isUploadingAvatar
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.camera_alt),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _firstNameController,
                  validator: AuthValidators.validateName,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastNameController,
                  validator: AuthValidators.validateLastName,
                  decoration: const InputDecoration(
                    labelText: 'Apellido',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  validator: AuthValidators.validatePhone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefono (phone_number)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  validator: AuthValidators.validateEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _isAccountActive,
                  onChanged: (value) {
                    setState(() {
                      _isAccountActive = value;
                    });
                  },
                  title: const Text('Cuenta activa'),
                  subtitle: Text(
                    _isAccountActive
                        ? 'Tu cuenta esta habilitada.'
                        : 'Tu cuenta quedara desactivada en la plataforma.',
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar cambios'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sesion: ${email ?? 'Sin correo disponible'}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: const Color(0xFF1B1B2F),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isSigningOut ? null : _logout,
            child: _isSigningOut
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Logout',
                    style: TextStyle(color: Colors.white),
                  ),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: content,
        ),
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  const _StatusBox({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 64, color: const Color(0xFFC000FF)),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(message, style: TextStyle(color: color)),
    );
  }
}