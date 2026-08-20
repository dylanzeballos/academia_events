import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/class_model.dart';
import '../../../providers/dance_class_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import 'class_create_view.dart';
import 'class_detail_view.dart';

class ClassListView extends ConsumerWidget {
  const ClassListView({super.key});

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
              itemBuilder: (context, index) => _ClassTile(
                danceClass: classes[index],
                canManage: canManage,
                onTap: () {
                  ref.read(selectedClassIdProvider.notifier).select(classes[index].id);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ClassDetailView()),
                  );
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClassCreateView()),
              ),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}

class _ClassTile extends StatelessWidget {
  const _ClassTile({
    required this.danceClass,
    required this.canManage,
    required this.onTap,
  });

  final ClassModel danceClass;
  final bool canManage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        side: BorderSide(color: context.divider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusMedium),
        onTap: canManage ? onTap : null,
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
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (danceClass.instructorName != null) ...[
                          Icon(Icons.person_outline, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            danceClass.instructorName!,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (danceClass.capacity != null) ...[
                          Icon(Icons.people_outline, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            '${danceClass.capacity} cupos',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
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
                  if (danceClass.price > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${danceClass.price} ${danceClass.currency}',
                      style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
