import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/class_model.dart';
import '../../../providers/dance_class_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../classes/views/class_list_view.dart';

class AcademyClassesView extends ConsumerWidget {
  const AcademyClassesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(orgClassesProvider);
    final myRole = ref.watch(myOrgRoleProvider);
    final canManage = myRole?.canManageClasses ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clases'),
      ),
      body: classesAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (classes) {
          if (classes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school_outlined, size: 64, color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  Text(
                    'Sin clases',
                    style: TextStyle(color: context.textOnBg, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Crea tu primera clase recurrente.',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  if (canManage) ...[
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ClassListView()),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Crear clase'),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    ),
                  ],
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(orgClassesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: classes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _ClassCard(
                danceClass: classes[index],
                canManage: canManage,
              ),
            ),
          );
        },
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClassListView()),
              ),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}

class _ClassCard extends ConsumerWidget {
  const _ClassCard({required this.danceClass, required this.canManage});

  final ClassModel danceClass;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: context.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        onTap: canManage ? () {
          ref.read(selectedClassIdProvider.notifier).select(danceClass.id);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ClassListView()),
          );
        } : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  danceClass.title.isNotEmpty ? danceClass.title[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      danceClass.title,
                      style: TextStyle(color: context.textOnBg, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    if (danceClass.instructorName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        danceClass.instructorName!,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: danceClass.isPublished
                      ? AppColors.success.withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  danceClass.isPublished ? 'Publicada' : 'Borrador',
                  style: TextStyle(
                    color: danceClass.isPublished ? AppColors.success : Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
