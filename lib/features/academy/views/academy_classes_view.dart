import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../providers/dance_class_provider.dart';
import '../../../providers/organization_provider.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../classes/views/class_create_view.dart';
import '../../classes/views/class_attendance_view.dart';
import '../../classes/views/class_detail_view.dart';
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
                        MaterialPageRoute(builder: (_) => const ClassCreateView()),
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
              itemBuilder: (context, index) {
                final danceClass = classes[index];
                // Navegación directa al detalle: sin lista intermedia.
                return ClassTile(
                  danceClass: danceClass,
                  canManage: canManage,
                  onTap: () async {
                    ref.read(selectedClassIdProvider.notifier).select(danceClass.id);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ClassDetailView()),
                    );
                    ref.invalidate(orgClassesProvider);
                  },
                  onAttendance: canManage
                      ? () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ClassAttendanceView(
                                classId: danceClass.id,
                                classTitle: danceClass.title,
                              ),
                            ),
                          )
                      : null,
                );
              },
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
