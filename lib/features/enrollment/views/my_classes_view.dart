// lib/features/enrollment/views/my_classes_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../data/models/class_access.dart';
import '../../../providers/checkin_provider.dart';
import '../../../providers/class_enrollment_provider.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/schedule/schedule_grid_body.dart';
import '../widgets/class_access_sheet.dart';
import 'explore_classes_view.dart';

/// "Mis clases" como horario semanal: solo las clases a las que el alumno está
/// inscripto, con una marca del tipo de acceso (VIP, mensual o pase de N
/// sesiones) en cada clase.
///
/// Al tocar una clase se abre el modal de acceso con el QR de la próxima
/// sesión (las entradas de clases ya no viven en la pestaña de tickets).
class MyClassesView extends ConsumerWidget {
  const MyClassesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(myClassesOverviewProvider);
    final enrollmentsAsync = ref.watch(myEnrollmentsProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.cardBg,
        elevation: 0,
        title: Text(
          'Mis clases',
          style: TextStyle(
            color: context.textOnBg,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: Icon(Icons.refresh_rounded, color: context.textMuted),
            onPressed: () {
              ref.invalidate(myEnrollmentsProvider);
              ref.invalidate(myClassPassesProvider);
              ref.invalidate(myClassesOverviewProvider);
            },
          ),
        ],
      ),
      body: overviewAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => AppErrorState(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(myClassesOverviewProvider),
        ),
        data: (overview) {
          if (overview.isEmpty) {
            final hasEnrollments = (enrollmentsAsync.value ?? const []).any(
              (e) => e.status != 'rejected',
            );
            return _EmptyState(
              hasEnrollments: hasEnrollments,
              onExplore: () => _openExplore(context),
            );
          }

          return SafeArea(
            top: false,
            child: ScheduleGridBody(
              entries: overview.entries,
              showOrganization: true,
              accessFor: (classId) => overview.accessByClass[classId],
              onOpenClass: (classId) {
                final enrollmentId = overview.enrollmentByClass[classId];
                final danceClass = overview.entries
                    .where((e) => e.danceClass.id == classId)
                    .firstOrNull
                    ?.danceClass;
                if (enrollmentId == null || danceClass == null) return;
                ClassAccessSheet.show(
                  context,
                  danceClass: danceClass,
                  access:
                      overview.accessByClass[classId] ??
                      const ClassAccess(kind: ClassAccessKind.none),
                  enrollmentId: enrollmentId,
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Explorar clases',
        onPressed: () => _openExplore(context),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.explore_outlined),
        label: const Text('Explorar'),
      ),
    );
  }

  void _openExplore(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ExploreClassesView()));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onExplore, this.hasEnrollments = false});

  final VoidCallback onExplore;
  final bool hasEnrollments;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.school_rounded,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasEnrollments
                  ? 'No tenés clases próximas'
                  : 'Todavía no estás inscrito a ninguna clase',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.textOnBg,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                hasEnrollments
                    ? 'Tus clases sin sesiones futuras no se muestran en el horario.'
                    : 'Explorá una academia, mirá su horario semanal y anotate en la clase que quieras.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size(0, AppSizes.buttonHeight),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              onPressed: onExplore,
              icon: const Icon(Icons.explore_outlined, size: 18),
              label: const Text('Explorar clases'),
            ),
          ],
        ),
      ),
    );
  }
}