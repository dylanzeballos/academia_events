import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/class_model.dart';
import '../../../data/models/class_enrollment_model.dart';
import '../../../providers/class_enrollment_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';

/// Detalle de una clase publicada para que el estudiante se inscriba.
class ClassEnrollDetailView extends ConsumerWidget {
  const ClassEnrollDetailView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classAsync = ref.watch(selectedEnrollClassProvider);
    final enrollmentsAsync = ref.watch(myEnrollmentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de clase')),
      body: classAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (danceClass) {
          if (danceClass == null) {
            return const Center(child: Text('Clase no encontrada.'));
          }
          final enrolled = enrollmentsAsync.value ?? const <ClassEnrollmentModel>[];
          final isEnrolled = alreadyEnrolled(enrolled, danceClass.id);

          return _ClassInfo(danceClass: danceClass, isEnrolled: isEnrolled);
        },
      ),
    );
  }
}

class _ClassInfo extends ConsumerWidget {
  const _ClassInfo({required this.danceClass, required this.isEnrolled});

  final ClassModel danceClass;
  final bool isEnrolled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionState = ref.watch(enrollmentActionProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Encabezado
        CircleAvatar(
          radius: 36,
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          child: Text(
            danceClass.title.isNotEmpty ? danceClass.title[0].toUpperCase() : '?',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          danceClass.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.textOnBg,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (danceClass.instructorName != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_outline, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text(
                danceClass.instructorName!,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ],
        if (danceClass.description != null &&
            danceClass.description!.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            danceClass.description!,
            style: TextStyle(color: context.textMuted, fontSize: 14, height: 1.4),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Precio: ${danceClass.price} ${danceClass.currency}',
          style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w600),
        ),

        const SizedBox(height: 24),

        if (actionState.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (!isEnrolled)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => _enroll(context, ref, danceClass.id),
            child: const Text('Inscribirme'),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 20),
                SizedBox(width: 8),
                Text(
                  'Ya estás inscrito',
                  style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        if (actionState.error != null) ...[
          const SizedBox(height: 12),
          Text(
            actionState.error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.error, fontSize: 13),
          ),
        ],
      ],
    );
  }

  Future<void> _enroll(BuildContext context, WidgetRef ref, String classId) async {
    final success =
        await ref.read(enrollmentActionProvider.notifier).enroll(classId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(success ? 'Te inscribiste correctamente.' : 'No se pudo inscribir.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    if (success) {
      ref
          .read(selectedEnrollClassIdProvider.notifier)
          .clear();
      Navigator.of(context).pop();
    }
  }
}