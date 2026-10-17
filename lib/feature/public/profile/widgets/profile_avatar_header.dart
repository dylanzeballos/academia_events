import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:academia_events/core/theme/app_colors.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';
import 'package:academia_events/data/models/profile_model.dart';
import 'package:academia_events/providers/auth_provider.dart';
import 'package:academia_events/shared/widgets/fullscreen_image_viewer.dart';

class ProfileAvatarHeader extends ConsumerWidget {
  const ProfileAvatarHeader({
    super.key,
    required this.profile,
  });

  final ProfileModel profile;

  Future<void> _pickAvatar(BuildContext context, WidgetRef ref) async {
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
      firstName: profile.firstName,
      lastName: profile.lastName,
      phone: profile.phoneNumber ?? '',
      avatarPath: path,
    );
    ref.invalidate(currentProfileProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarUrl = ref.watch(resolvedAvatarUrlProvider);

    return Column(
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
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
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
              onTap: () => _pickAvatar(context, ref),
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
    );
  }
}