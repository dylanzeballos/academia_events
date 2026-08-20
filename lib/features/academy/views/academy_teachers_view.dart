import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../providers/dance_class_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';

class AcademyTeachersView extends ConsumerWidget {
  const AcademyTeachersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instructorsAsync = ref.watch(orgInstructorsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Instructores'),
      ),
      body: instructorsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (instructors) {
          if (instructors.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  Text(
                    'Sin instructores',
                    style: TextStyle(color: context.textOnBg, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Invita instructores desde la\nsección de miembros.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(orgInstructorsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: instructors.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final instructor = instructors[index];
                final profile = instructor['profiles'] as Map<String, dynamic>?;
                final firstName = profile?['first_name'] as String? ?? '';
                final lastName = profile?['last_name'] as String? ?? '';
                final fullName = '$firstName $lastName'.trim();
                final phone = profile?['phone_number'] as String?;
                final avatarUrl = profile?['profile_image_url'] as String?;

                return Card(
                  color: context.cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
                    side: BorderSide(color: context.divider),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null
                          ? Text(
                              fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    title: Text(
                      fullName.isNotEmpty ? fullName : 'Sin nombre',
                      style: TextStyle(color: context.textOnBg, fontWeight: FontWeight.w500),
                    ),
                    subtitle: phone != null && phone.isNotEmpty
                        ? Text(phone, style: const TextStyle(color: Colors.grey, fontSize: 12))
                        : null,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Instructor',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
